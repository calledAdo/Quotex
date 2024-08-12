import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Buffer "mo:base/Buffer";
import Time "mo:base/Time";
import Types "Types";
import ICRC "../Interface/ICRC";
import SwapLib "../Lib/SwapLib";
import OrderLib "../Lib/OrderLib";
import Calc "../Lib/Calculations";

import Vault "../Vault/main";

/// Market actor class

/// important constants

shared ({ caller }) actor class Market(details : Types.MarketDetails, vaultID : Principal, initTick : Nat) = this {

    type TickDetails = Types.TickDetails;
    type SwapParams = Types.SwapParams;
    type OpenOrderParams = Types.OpenOrderParams;
    type OrderDetails = Types.OrderDetails;

    let m_users_orders = HashMap.HashMap<Principal, Buffer.Buffer<OrderDetails>>(1, Principal.equal, Principal.hash);

    var m_multipliers_bitmaps = HashMap.HashMap<Nat, Nat>(
        1,
        Nat.equal,
        Types.natHash,
    );

    // a mapping of each tick mapped to its liquidity ;
    var m_ticks_details = HashMap.HashMap<Nat, Types.TickDetails>(
        1,
        Nat.equal,
        Types.natHash,
    );

    stable let market_details = details;

    stable let vault : Vault.Vault = actor (Principal.toText(vaultID));

    stable var state_details : Types.StateDetails = {
        min_units_token1 = 0;
        min_units_token0 = 0;
        interest_rate = 0;
        token0_spam_fee = 0;
        token1_spam_fee = 0;
        max_leverage = 0;
    };

    stable var current_tick : Nat = initTick;

    // ======== Query Functions ==========

    /// Gets all orders by a paticular user

    public query func getUserOrders(user : Principal) : async [OrderDetails] {
        switch (m_users_orders.get(user)) {
            case (?res) { return Buffer.toArray<OrderDetails>(res) };
            case (_) { return [] };
        };
    };

    /// Query Call returning the estimated result of a swap at the particular time
    // returns the amount out of token to be received and the amount remaining  of the token being swapped

    public query func swapResult(amount : Nat, in1out0 : Bool) : async (amount_out : Nat, amount_remaining : Nat) {

        let params = {
            in1out0 = in1out0;
            amount_in = amount;
            init_tick = current_tick;
            stopping_tick = Calc.defMaxTick(current_tick, in1out0);
            m_multipliers_bitmaps = m_multipliers_bitmaps;
            m_ticks_details = m_ticks_details;
        };

        let swap_constants : Types.SwapConstants = {
            token0_decimal = market_details.token0_decimal;
            token1_decimal = market_details.token1_decimal;
            base_price_multiplier = market_details.base_price_multiplier;
            tick_spacing = market_details.tick_spacing;
        };

        let swap_result = SwapLib.swap(params, swap_constants);

        return (swap_result.amount_out, swap_result.amount_remaining);

    };

    /// Query calls that returns the best offers for both buys and sells
    /// serves as an ideal getter function for an orderbook display

    /// see OrderLib.getsBestOffers for clarification;
    public query func getBestOffers() : async (best_buys : [(Nat, TickDetails)], best_sells : [(Nat, TickDetails)]) {

        let best_buys = OrderLib._getBestOffers(
            true,
            10,
            current_tick,
            m_multipliers_bitmaps,
            m_ticks_details,
            market_details.tick_spacing,
        );
        let best_sells = OrderLib._getBestOffers(
            false,
            10,
            current_tick,
            m_multipliers_bitmaps,
            m_ticks_details,
            market_details.tick_spacing,
        );

        return (best_buys, best_sells);
    };

    // ====== Public functions ======

    /// Swap function for executing swaps on the Market orderbook

    ///  Params

    ///   amount_in :Amount of token to swap
    ///   m_tick :The maximum tick acts as the tick of maximum  executing price (if null the default max tick is used)
    ///   in1out0 :true if sending in Quote token for Base Token
    ///

    public shared ({ caller }) func swap(amount_in : Nat, m_tick : ?Nat, in1out0 : Bool) : async (amount_out : Nat, amount_remaining : Nat) {

        let max_tick : Nat = switch (m_tick) {
            case (?res) { res };
            case (_) { Calc.defMaxTick(current_tick, in1out0) };
        };

        // max_tick should be between the default minimum tick for a sell order and the default  maximum tick for a in1out0
        let not_exceeded = max_tick <= Calc.defMaxTick(current_tick, true) and max_tick >= Calc.defMaxTick(current_tick, false);

        // double asserts use seperately to avoid possible contradictions
        assert (not_exceeded);

        let (asset_in, asset_out, min_amount) = if (in1out0) {
            (market_details.token1, market_details.token0, state_details.min_units_token1);
        } else {
            (market_details.token0, market_details.token1, state_details.min_units_token0);
        };

        assert (amount_in >= min_amount);

        assert (await _send_asset_in(caller, asset_in, amount_in));

        let (amount_out, amount_remaining) = _swap(amount_in, max_tick, in1out0);
        ignore (
            unchecked_send_asset_out(caller, asset_out, amount_out),
            unchecked_send_asset_out(caller, asset_in, amount_remaining),
        );

        return (amount_out, amount_remaining);

    };

    /// placeOrder function for creating Limit Orders and providing Liquidity
    ///    Params

    ///          amount_in : amount of asset to send in
    ///          reference_tick : the reference_tick corresponding to the set price for the Order

    ///    NOTE: amount_in should be gretaer than min_trading amount for the respective token ;
    ///

    public shared ({ caller }) func placeOrder(amount_in : Nat, reference_tick : Nat) : async Types.OrderDetails {
        //orders can not be placed at current_tick
        assert (reference_tick != current_tick);

        // gets the min tradeable
        let (min_amount : Nat, asset_in : Principal) = if (reference_tick > current_tick) {
            (state_details.min_units_token0, market_details.token0);
        } else {
            (state_details.min_units_token1, market_details.token1);
        };

        assert (amount_in >= min_amount);

        assert (await _send_asset_in(caller, asset_in, amount_in));

        let order_details : OrderDetails = _placeOrder(reference_tick, amount_in);

        let user_orders = switch (m_users_orders.get(caller)) {
            case (?res) { res };
            case (_) { Buffer.Buffer<Types.OrderDetails>(1) };
        };

        user_orders.add(order_details);
        m_users_orders.put(caller, user_orders);

        return order_details;
    };

    /// removeOrder function for cancelling order and withdrawing liquidity for Liquidity Providers

    /// Params
    ///      order_id: ID of that particular user order (corresponds to the index of orfer in User Orders Buffer)
    ///

    public shared ({ caller }) func removeOrder(order_id : Nat) : async () {
        let user_orders = switch (m_users_orders.get(caller)) {
            case (?res) { res };
            case (_) { return () };
        };
        let order_details : Types.OrderDetails = user_orders.get(order_id);

        let (amount_token0, amount_token1) = switch (_removeOrder(order_details)) {
            case (?res) { res };
            case (_) { return () };
        };
        ignore (
            user_orders.remove(order_id),
            unchecked_send_asset_out(caller, market_details.token0, amount_token0),
            unchecked_send_asset_out(caller, market_details.token1, amount_token1),
        );

    };

    /// openPosition function for opening margined_positions at an interest_rate;
    ///
    ///  collateral = amount of tokens set for collateral;
    ///  debt = amount of tokens being borrowed
    ///  is1in0out = true if borrowing quote tokenand false otherwise
    ///  m_tick :The maximum tick acts as the tick of maximum  executing price (if null the default max tick is used)
    ///

    public shared ({ caller }) func openPosition(collateral : Nat, debt : Nat, is1in0out : Bool, m_tick : ?Nat) : async () {

        var order_value = collateral + debt;
        //assert max _leverage is not exceeded
        assert ((order_value / collateral) < state_details.max_leverage);

        let max_tick : Nat = switch (m_tick) {
            case (?res) { res };
            case (_) { Calc.defMaxTick(current_tick, is1in0out) };
        };

        // max_tick should be between the default boundaries to limit loop time
        let within_boundaries = max_tick <= Calc.defMaxTick(current_tick, true) and max_tick >= Calc.defMaxTick(current_tick, false);

        assert (within_boundaries);
        //as
        let (asset_in, asset_out, min_amount) = if (is1in0out) {
            //if longing
            (market_details.token1, market_details.token0, state_details.min_units_token1);
        } else {
            (market_details.token0, market_details.token1, state_details.min_units_token0);
        };

        assert (min_amount >= collateral);

        var from_subaccount = ?Principal.toBlob(caller);

        var to_account : ICRC.Account = {
            owner = Principal.fromActor(vault);
            subaccount = null;
        };

        assert (await vault.move_asset(asset_in, collateral, from_subaccount, to_account));

        if (not (await _send_asset_in(market_details.margin_provider, asset_in, debt))) {
            // refund caller if margin_provider lacks enough liquidity ;
            from_subaccount := null;
            to_account := {
                owner = Principal.fromActor(vault);
                subaccount = ?Principal.toBlob(caller);
            };
            ignore vault.unchecked_move_asset(asset_in, collateral, from_subaccount, to_account);
            return ();
        };

        switch (await _openPosition(caller, collateral, debt, max_tick, is1in0out)) {
            case (?(order_size, resulting_debt)) {
                // order was filled partially with some collatreal being unutilised
                if (resulting_debt >= debt) {
                    ignore (
                        //send back debt
                        unchecked_send_asset_out(market_details.margin_provider, asset_in, debt),
                        // send the asset_out to user
                        unchecked_send_asset_out(caller, asset_out, order_size),
                        // send back unutilised collateral
                        unchecked_send_asset_out(caller, asset_in, resulting_debt - debt),
                    );
                    return ();
                };
                // order was filled either with entire debt or partially
                ignore (
                    unchecked_send_asset_out(market_details.margin_provider, asset_in, debt - resulting_debt),
                    unchecked_send_asset_out(market_details.margin_provider, asset_out, order_size),
                );
                return ()

            };
            case (_) {
                // user already has a position
                ignore (
                    unchecked_send_asset_out(market_details.margin_provider, asset_in, debt),

                    unchecked_send_asset_out(caller, asset_in, collateral),
                );
                return ();
            };
        };

    };

    /// Close Position function
    /*params
        position_details  = The details of the position in reference

     NOTE :position_details should be gotten directly from users_positions in margin_provider actor for accuracy
    */

    public shared ({ caller }) func closePosition(position_details : Types.PositionDetails) : async () {
        assert (caller == position_details.owner or caller == market_details.margin_provider);

        //Checks if user already has a position owns a position with position_details
        let valid = await vault.positionExist(position_details.owner, Principal.fromActor(this), position_details);
        if (not valid) {
            return ();
        };

        // if closing a long position ,it's a sell swap
        let in1out0 = not position_details.is1in0out;

        let (asset_in, asset_out) = if (in1out0) {
            (market_details.token1, market_details.token0);
        } else {
            (market_details.token0, market_details.token1);
        };

        assert (await _send_asset_in(market_details.margin_provider, asset_in, position_details.order_size));

        let (total_fee, amount_out, amount_remaining) = await _closePosition(position_details);
        // if amount is just sufficient enough  to pay debt ,position is closed
        if (amount_out >= total_fee) {
            ignore (
                unchecked_send_asset_out(market_details.margin_provider, asset_out, total_fee),
                unchecked_send_asset_out(position_details.owner, asset_out, amount_out - total_fee),
                unchecked_send_asset_out(position_details.owner, asset_in, amount_remaining)

            );
            return ()

        } else {
            ignore unchecked_send_asset_out(market_details.margin_provider, asset_out, amount_out);
        };

        ignore (
            unchecked_send_asset_out(market_details.margin_provider, asset_in, amount_remaining)
        );
    };

    // ==============  Private functions ================

    /*returns

    amount_out = the amount of token received from the swap
    amount_remaining = amount of token in (token being swapped) remaining after swapping

    */

    private func _swap(amount_in : Nat, max_tick : Nat, in1out0 : Bool) : (amount_out : Nat, amount_remaining : Nat) {

        let params = {
            in1out0 = in1out0;
            amount_in = amount_in;
            init_tick = current_tick;
            stopping_tick = max_tick;
            m_multipliers_bitmaps = m_multipliers_bitmaps;
            m_ticks_details = m_ticks_details;
        };

        let swap_constants : Types.SwapConstants = {
            token0_decimal = market_details.token0_decimal;
            token1_decimal = market_details.token1_decimal;
            base_price_multiplier = market_details.base_price_multiplier;
            tick_spacing = market_details.tick_spacing;
        };

        let swap_result = SwapLib.swap(params, swap_constants);

        current_tick := swap_result.current_tick;

        return (swap_result.amount_out, swap_result.amount_remaining);
    };

    ///_placeOrder function
    /// returns
    ///     OrderDetails comprising of
    ///        reference_tick = tick corresponding to the order price
    ///        tick_shares - measure of liquidity provided by order at that particular tick

    ///   returns null if tick is initilaised(flipped)
    ///

    private func _placeOrder(reference_tick : Nat, amount_in : Nat) : Types.OrderDetails {

        let params : Types.OpenOrderParams = {
            reference_tick = reference_tick;
            current_tick = current_tick;
            amount_in = amount_in;
            m_multipliers_bitmaps = m_multipliers_bitmaps;
            m_ticks_details = m_ticks_details;
        };
        // returns null if reference tick is flipped and amount in is less than minimum flipping amount ;
        return OrderLib._placeOrder(params, market_details.tick_spacing);
    };

    /// _removeOrder function

    /// _removeOrder function
    ///      Returns
    ///           amount_token0 : amount of base token received for  order tick shares
    ///           amount_token1: amount of quote token received for order tick shares
    ///    NOTE:if both amount_token0 and amount_token1 is not  equal to zero this corresponds to partially filled order

    ///    returns null if Order references an uninitialised tick ( see _removeOrder in OrderLib)

    ///

    private func _removeOrder(order_details : Types.OrderDetails) : ?(amount_token0 : Nat, amount_token1 : Nat) {

        let params = {
            order_details = order_details;
            m_multipliers_bitmaps = m_multipliers_bitmaps;
            m_ticks_details = m_ticks_details;
        };

        let remove_order_result = switch (OrderLib._removeOrder(params, market_details.tick_spacing)) {
            case (?res) { res };
            case (_) { return null };
        };

        return ?(remove_order_result.amount_token0, remove_order_result.amount_token1);

    };

    ///  _openPosition function

    // @dev Position token is the token being longed (token out) while Debt token is the token being shorted (token in)

    ///    returns

    ///    order_size = the amount of Position token  received for the leveraged swap
    ///     resulting_debt = the amount of Debt token borrowed that is actually  utilised  (debt reduces by amount_remaining)

    ///    returns null if
    ///        user already has a position
    ///        if amount_remaining after swap is equal or exceeds debt
    ///

    private func _openPosition(user : Principal, collateral : Nat, debt : Nat, max_tick : Nat, is1in0out : Bool) : async ?(order_size : Nat, resulting_debt : Nat) {

        let debt_token = if (is1in0out) {
            market_details.token1;
        } else {
            market_details.token0;
        };

        if (await vault.userHasPosition(caller, Principal.fromActor(this))) {
            return null;
        };
        var order_value = collateral + debt;

        let (amount_out, amount_remaining) = _swap(order_value, max_tick, is1in0out);

        // should fail if debt was not utilised
        if (amount_remaining >= debt) {
            return ?(amount_out, amount_remaining);
        };

        let position_details : Types.PositionDetails = {
            debt_token = debt_token;
            owner = caller;
            is1in0out = is1in0out;
            debt = debt - amount_remaining;
            order_size = amount_out;
            interest_rate = state_details.interest_rate;
            time = Time.now();
        };

        ignore vault.updatePosition(user, Principal.fromActor(this), debt_token, ?position_details, 0, 0);
        return ?(position_details.order_size, position_details.debt);

    };

    /// _closePosition function

    // Position token is the token being bought (token out) while Debt token is the token being shorted (token in)

    /// returns
    ///       total_fee : position debt +  accumulated interest hourly in Debt tokens
    ///       amount_out : the amount of Debt token gotten from closing the position ( could be partially filled )
    ///       amount_remaining : the smount of Position token remaining due to low liquidity

    /// NOTE : if amount remaining is not equal to zero ,position is partially closed and  updated
    private func _closePosition(position_details : Types.PositionDetails) : async (total_fee : Nat, amount_out : Nat, amount_remaining : Nat) {

        let in1out0 = not position_details.is1in0out;
        let (amount_out, amount_remaining) = _swap(position_details.order_size, Calc.defMaxTick(current_tick, in1out0), in1out0);
        let interest_fee = Calc.calcInterest(position_details.debt, position_details.interest_rate, position_details.time);

        let total_fee = interest_fee + position_details.debt;
        if (amount_remaining != 0 and amount_out < total_fee) {

            // updates user position
            let new_position_details : Types.PositionDetails = {

                debt_token = position_details.debt_token;
                owner = position_details.owner;
                is1in0out = position_details.is1in0out;

                // debt is total fee to be paid - the actual amount being paid
                debt = total_fee - amount_out;
                order_size = amount_remaining;
                interest_rate = position_details.interest_rate;
                time = Time.now();
            };

            ignore vault.updatePosition(
                position_details.owner,
                Principal.fromActor(this),
                position_details.debt_token,
                ?new_position_details,
                amount_out,
                0,
            );
        } else {
            // if amount_out is just sufficient enough to cover total debt debt ;
            //position should be closed with debt paid in Debt token and all other assets
            //sent to position owner
            ignore vault.updatePosition(
                position_details.owner,
                Principal.fromActor(this),
                position_details.debt_token,
                null,
                position_details.debt,
                interest_fee,
            );
        };
        return (total_fee, amount_out, amount_remaining);

    };

    // ===== asset management_functions ============

    ///NOTE: user account is identified as an ICRC Account with owner as Market actor and subaccount
    /// made from converting user principal to Blob
    /// eg
    //   let account = {
    //     owner = Principal.fromActor(this);
    //     subaccount = ?Principal.toBlob(user);
    // };

    //_send_asset_in_function
    // @dev moves asset from user account into main or null account and await the result
    //returns true if transaction was successful or false otherwise .

    private func _send_asset_in(user : Principal, asset_principal : Principal, amount : Nat) : async Bool {
        if (amount == 0) {
            return true;
        };
        let account = {
            owner = Principal.fromActor(vault);
            subaccount = null;
        };
        return await vault.move_asset(asset_principal, amount, ?Principal.toBlob(user), account);

    };

    //_send_asset_out_function
    // @dev moves asset from   main or null account to user account and await the result
    //returns true if transaction was successful or false otherwise .

    private func _send_asset_out(user : Principal, asset_principal : Principal, amount : Nat) : async Bool {
        if (amount == 0) {
            return true;
        };
        let account = {
            owner = Principal.fromActor(vault);
            subaccount = ?Principal.toBlob(user);
        };
        return await vault.move_asset(asset_principal, amount, null, account);

    };

    //unchecked_send_asset_out function
    // @dev moves asset from main or null account to user account  but does not await the result
    // reduces trnsaction time

    public func unchecked_send_asset_out(user : Principal, asset_principal : Principal, amount : Nat) : async () {
        if (amount == 0) {
            return ();
        };
        let account = {
            owner = Principal.fromActor(vault);
            subaccount = ?Principal.toBlob(user);
        };
        ignore vault.unchecked_move_asset(asset_principal, amount, null, account);

    };

};
