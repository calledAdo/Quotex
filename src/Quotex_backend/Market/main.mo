import Nat "mo:base/Nat";
import Principal "mo:base/Principal";

import HashMap "mo:base/HashMap";
import Buffer "mo:base/Buffer";
import Time "mo:base/Time";
import Types "../Interface/Types";
import SwapLib "../Lib/SwapLib";
import OrderLib "../Lib/OrderLib";
import Calc "../Lib/Calculations";
import Vault "../Vault/main";

/*

  Name :Market Actor
  Author :CalledDao


*/

shared ({ caller }) actor class Market(details : Types.MarketDetails, vaultID : Principal, initTick : Nat) = this {

    type TickDetails = Types.TickDetails;
    type SwapParams = Types.SwapParams;
    type OpenOrderParams = Types.OpenOrderParams;
    type OrderDetails = Types.OrderDetails;
    type StateDetails = Types.StateDetails;

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

    let admin = caller;

    let approved_liquidators = HashMap.HashMap<Principal, Bool>(1, Principal.equal, Principal.hash);

    stable let market_details = details;

    stable let vault : Vault.Vault = actor (Principal.toText(vaultID));

    stable var state_details : StateDetails = {
        min_units_token1 = 0;
        min_units_token0 = 0;
        interest_rate = 0;
        token0_spam_fee = 0;
        token1_spam_fee = 0;
        max_leverageX10 = 500;
    };

    var current_tick : Nat = initTick;

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

    public query func tickDetails(reference_tick : Nat) : async Types.TickDetails {
        let ref_tick_details = switch (m_ticks_details.get(reference_tick)) {
            case (?res) { res };
            case (_) {
                {
                    liquidity_token0 = 0;
                    liquidity_token1 = 0;
                    total_shares = 0;
                };
            };
        };
        return ref_tick_details;
    };

    /// Query calls that returns the best offers for both buys and sells
    /// serves as an ideal getter function for an orderbook display

    /// see OrderLib.getsBestOffers for clarification;
    public query func getBestOffers() : async (best_buys : [(Nat, TickDetails)]) {

        let best_buys = OrderLib._getBestOffers(
            true,
            2,
            current_tick,
            m_multipliers_bitmaps,
            m_ticks_details,
            market_details.tick_spacing,
        );
        // let best_sells = OrderLib._getBestOffers(
        //     false,
        //     2,
        //     current_tick,
        //     m_multipliers_bitmaps,
        //     m_ticks_details,
        //     market_details.tick_spacing,
        // );

        return (best_buys);
    };

    // =========== Admin functions ===========

    public shared ({ caller }) func updateState(new_state_details : ?StateDetails, current_tick : ?Nat) : async () {
        assert (caller == admin);
        switch (new_state_details) {
            case (?res) { state_details := res };
            case (_) {};
        };

    };

    public shared ({ caller }) func changeLiquidatorStatus(id : Principal, status : Bool) : async Bool {
        if (status) {
            approved_liquidators.put(id, true);
            return true;
        } else {
            approved_liquidators.delete(id);
            return false;
        };

    };

    // ====== Public functions ======

    /// Swap function for executing swaps on the Market orderbook

    ///  Params

    ///   amount_in :Amount of token to swap
    ///   m_tick :The maximum tick acts as the tick of maximum  executing price (if null the default max tick is used)
    ///   in1out0 :true if sending in Quote token for Base Token
    ///

    public shared ({ caller }) func swap(amount_in : Nat, m_tick : ?Nat, in1out0 : Bool) : async {
        #Ok : (amount_out : Nat, amount_remaining : Nat);
        #Err : Text;
    } {

        let max_tick : Nat = switch (m_tick) {
            case (?res) { res };
            case (_) { Calc.defMaxTick(current_tick, in1out0) };
        };

        // max_tick should be between the default minimum tick for a sell order and the default  maximum tick for a buy order
        let not_exceeded = max_tick <= Calc.defMaxTick(current_tick, true) and max_tick >= Calc.defMaxTick(current_tick, false);

        assert (not_exceeded);

        let { token0; token0_fee; token1; token1_fee } = market_details;

        let (asset_in : Principal, asset_in_fee : Nat, asset_out : Principal, asset_out_fee : Nat, min_amount : Nat) = if (in1out0) {
            (token1, token1_fee, token0, token0_fee, state_details.min_units_token1);
        } else {
            (token0, token0_fee, token1, token1_fee, state_details.min_units_token0);
        };

        if (min_amount > amount_in) {
            return #Err("amount in smaller than min _amount");
        };

        assert (await _send_asset_in(caller, asset_in, amount_in, asset_in_fee));

        let (amount_out, amount_remaining) = _swap(amount_in, max_tick, in1out0);
        ignore (
            unchecked_send_asset_out(caller, asset_out, amount_out, asset_out_fee),
            unchecked_send_asset_out(caller, asset_in, amount_remaining, asset_in_fee),
        );

        return #Ok(amount_out, amount_remaining);

    };

    /// placeOrder function for creating Limit Orders and providing Liquidity
    ///    Params

    ///          amount_in : amount of asset to send in
    ///          reference_tick : the reference_tick corresponding to the set price for the Order

    ///    NOTE: amount_in should be gretaer than min_trading amount for the respective token ;
    ///

    public shared ({ caller }) func placeOrder(amount_in : Nat, reference_tick : Nat) : async {
        #Ok : Types.OrderDetails;
        #Err : Text;
    } {
        //orders can not be placed at current_tick
        assert (reference_tick != current_tick);

        let { token0; token0_fee; token1; token1_fee } = market_details;

        // gets the min _tradable amount ,the asset sent in and the asset_fee
        let (min_amount : Nat, asset_in : Principal, asset_in_fee : Nat) = if (reference_tick > current_tick) {
            (state_details.min_units_token0, token0, token0_fee);
        } else {
            (state_details.min_units_token1, token1, token1_fee);
        };

        if (min_amount > amount_in) {
            return #Err("amount in smaller than min amount");
        };

        assert (await _send_asset_in(caller, asset_in, amount_in, asset_in_fee));

        let order_details : OrderDetails = _placeOrder(reference_tick, amount_in);

        let user_orders = switch (m_users_orders.get(caller)) {
            case (?res) { res };
            case (_) { Buffer.Buffer<Types.OrderDetails>(1) };
        };

        user_orders.add(order_details);
        m_users_orders.put(caller, user_orders);

        return #Ok(order_details);
    };

    /// removeOrder function for cancelling order and withdrawing liquidity for Liquidity Providers

    /// Params
    ///      order_id: ID of that particular user order (corresponds to the index of orfer in User Orders Buffer)
    ///

    public shared ({ caller }) func removeOrder(order_id : Nat) : async {
        #Err : Text;
        #Ok : (amount_token0 : Nat, amount_token1 : Nat);
    } {
        let user_orders = switch (m_users_orders.get(caller)) {
            case (?res) { res };
            case (_) { return #Err("") };
        };
        let order_details : Types.OrderDetails = user_orders.get(order_id);

        let (amount_token0, amount_token1) = switch (_removeOrder(order_details)) {
            case (?res) { res };
            case (_) { return #Err("") };
        };
        let { token0; token0_fee; token1; token1_fee } = market_details;
        ignore (
            user_orders.remove(order_id),
            unchecked_send_asset_out(caller, token0, amount_token0, token0_fee),
            unchecked_send_asset_out(caller, token1, amount_token1, token1_fee),
        );
        m_users_orders.put(caller, user_orders);
        return #Ok(amount_token0, amount_token1)

    };

    /// openPosition function for opening margined_positions at an interest_rate;
    ///
    ///  collateral = amount of tokens set for collateral;
    ///  debt = amount of tokens being borrowed
    ///  is1in0out = true if borrowing quote tokenand false otherwise
    ///  m_tick :The maximum tick acts as the tick of maximum  executing price (if null the default max tick is used)
    ///

    public shared ({ caller }) func openPosition(collateral : Nat, leverageX10 : Nat, is1in0out : Bool, m_tick : ?Nat) : async {
        #Ok;
        #Err : Text;
    } {

        assert (leverageX10 < state_details.max_leverageX10);

        var order_value = (collateral * leverageX10) / 10;

        let debt : Nat = order_value - collateral;
        //assert max _leverage is not exceeded

        let max_tick : Nat = switch (m_tick) {
            case (?res) { res };
            case (_) { Calc.defMaxTick(current_tick, is1in0out) };
        };

        // max_tick should be between the default boundaries to limit loop time
        let within_boundaries = max_tick <= Calc.defMaxTick(current_tick, true) and max_tick >= Calc.defMaxTick(current_tick, false);

        assert (within_boundaries);
        //as
        let { token0; token0_fee; token1; token1_fee } = market_details;

        let (asset_in : Principal, asset_in_fee : Nat, asset_out : Principal, asset_out_fee : Nat, min_amount : Nat) = if (is1in0out) {
            (token1, token1_fee, token0, token0_fee, state_details.min_units_token1);
        } else {
            (token0, token0_fee, token1, token1_fee, state_details.min_units_token0);
        };
        if (min_amount > collateral) {
            return #Err("collateral is too small");
        };

        switch (await vault.userMarketPosition(caller, Principal.fromActor(this))) {
            case (?_) { return #Err("User already has a position") };
            case (_) {};
        };

        assert ((await _send_asset_in(caller, asset_in, collateral, asset_in_fee)));

        if (not (await vault.enoughLiquidity(asset_in, debt))) {

            ignore unchecked_send_asset_out(caller, asset_in, collateral, asset_in_fee);
            return #Err("Not enough liqudity");
        };

        let (order_size, amount_remaining) = await _openPosition(caller, collateral, debt, max_tick, is1in0out);
        // collateral was not used up during swap
        if (amount_remaining >= debt) {
            //refund all
            ignore (
                // send the asset_out to user
                unchecked_send_asset_out(caller, asset_out, order_size, asset_out_fee),
                // send back unutilised collateral
                unchecked_send_asset_out(caller, asset_in, amount_remaining, asset_in_fee),
            );
            return #Err("Debt not utilised");
        };
        // order was filled either with entire debt or partially but collateral and some debt was used up

        return #Ok;
    };

    /// Close Position function
    ///params
    /// position_details  = The details of the position in reference

    ///NOTE :position_details should be gotten directly from users_positions in margin_provider actor for accuracy
    ///

    public shared ({ caller }) func closePosition(user : Principal) : async {
        #Ok : Text;
        #Err : Text;
    } {
        let position_details = switch (await vault.userMarketPosition(user, Principal.fromActor(this))) {
            case (?res) { res };
            case (_) { return #Err("Position not found") };
        };
        assert (caller == user or _isApprovedLiqudator(caller));

        // if closing a long position ,it's a sell swap
        let in1out0 = not position_details.is1in0out;

        let { token0; token0_fee; token1; token1_fee } = market_details;

        let (asset_in : Principal, asset_in_fee : Nat, asset_out : Principal, asset_out_fee : Nat) = if (in1out0) {
            (token1, token1_fee, token0, token0_fee);
        } else {
            (token0, token0_fee, token1, token1_fee);
        };

        let (total_fee, amount_out, amount_remaining) = await _closePosition(position_details);
        // if amount is just sufficient enough  to pay debt ,position is closed
        if (amount_out >= total_fee) {
            ignore (
                unchecked_send_asset_out(position_details.owner, asset_out, amount_out - total_fee, asset_out_fee),
                unchecked_send_asset_out(position_details.owner, asset_in, amount_remaining, asset_in_fee),
            );
            return #Ok("Position Closed");
        };
        return #Ok("Position Updated");
    };

    // ==============  Private functions ================

    /// returns

    ///  amount_out = the amount of token received from the swap
    ///  amount_remaining = amount of token in (token being swapped) remaining after swapping

    ///

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
    ///     OrderDetails comprising of .
    ///        reference_tick = tick corresponding to the order price .
    ///        tick_shares - measure of liquidity provided by order at that particular tick .
    ///
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
    ///
    /// _removeOrder function.
    ///      Returns.
    ///           amount_token0 : amount of base token received for  order tick shares.
    ///           amount_token1: amount of quote token received for order tick shares.
    ///    NOTE:if both amount_token0 and amount_token1 is not  equal to zero this corresponds to partially filled order .
    ///
    ///    returns null if Order references an uninitialised tick ( see _removeOrder in OrderLib) .
    ///
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
    ///
    ///  @dev Position token is the token being longed (token out) while Debt token is the token being shorted (token in)
    ///
    ///    returns.
    ///
    ///    order_size = the amount of Position token  received for the leveraged swap .
    ///
    ///    amount_remaining = the amount of Debt token borrowed that is actually  utilised  (debt reduces by amount_remaining)
    ///
    ///    returns null if.
    ///        user already has a position.
    ///
    ///        if amount_remaining after swap is equal or exceeds debt.
    ///

    private func _openPosition(
        user : Principal,
        collateral : Nat,
        debt : Nat,
        max_tick : Nat,
        is1in0out : Bool,
    ) : async (Nat, Nat) {

        let debt_token = if (is1in0out) {
            market_details.token1;
        } else {
            market_details.token0;
        };

        var order_value = collateral + debt;

        let (amount_out, amount_remaining) = _swap(order_value, max_tick, is1in0out);

        // should fail if debt was not utilised
        if (amount_remaining >= debt) {
            return (amount_out, amount_remaining);
        };

        let position_details : Types.PositionDetails = {
            debt_token = debt_token;
            owner = user;
            is1in0out = is1in0out;
            debt = debt - amount_remaining;
            order_size = amount_out;
            interest_rate = state_details.interest_rate;
            time = Time.now();
        };

        ignore vault.updatePosition(user, Principal.fromActor(this), debt_token, ?position_details, 0, 0);
        return (position_details.order_size, amount_remaining);

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

            let fee_collected : Nat = if (amount_out > position_details.debt) {
                amount_out - position_details.debt;
            } else {
                0;
            };

            ignore vault.updatePosition(
                position_details.owner,
                Principal.fromActor(this),
                position_details.debt_token,
                ?new_position_details,
                amount_out,
                fee_collected,
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

    private func _isApprovedLiqudator(id : Principal) : Bool {
        switch (approved_liquidators.get(id)) {
            case (?_) { return true };
            case (_) { false };
        };
    };

    // ===== asset management_functions ============

    ///NOTE: user account is identified as an ICRC Account with owner as Vault actor and subaccount
    /// made from converting user principal to Blob
    /// eg
    //   let account = {
    //     owner = Principal.fromActor(this);
    //     subaccount = ?Principal.toBlob(user);
    // };

    //_send_asset_in_function
    // @dev moves asset from user account into main or null account and await the result
    //returns true if transaction was successful or false otherwise .

    private func _send_asset_in(user : Principal, assetID : Principal, amount : Nat, fee : Nat) : async Bool {
        if (amount == 0) {
            return true;
        };

        let account = {
            owner = Principal.fromActor(vault);
            subaccount = null;
        };
        return await vault.move_asset(assetID, amount + fee, ?Principal.toLedgerAccount(user, null), account);

    };

    //_send_asset_out_function
    // @dev moves asset from   main or null account to user account and await the result
    //returns true if transaction was successful or false otherwise .

    private func _send_asset_out(user : Principal, assetID : Principal, amount : Nat, fee : Nat) : async Bool {
        if (amount == 0) {
            return true;
        };
        if (fee >= amount) {
            return false;
        };
        let account = {
            owner = Principal.fromActor(vault);
            subaccount = ?Principal.toLedgerAccount(user, null);
        };

        return await vault.move_asset(assetID, amount - fee, null, account);

    };

    //unchecked_send_asset_out function
    // @dev moves asset from main or null account to user account  but does not await the result
    // reduces transaction time

    public func unchecked_send_asset_out(user : Principal, assetID : Principal, amount : Nat, fee : Nat) : async () {
        if (amount == 0) {
            return ();
        };
        if (fee >= amount) {
            return ();
        };
        let account = {
            owner = Principal.fromActor(vault);
            subaccount = ?Principal.toBlob(user);
        };
        ignore vault.unchecked_move_asset(assetID, amount - fee, null, account);

    };

};
