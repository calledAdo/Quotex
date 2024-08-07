import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Buffer "mo:base/Buffer";
import Time "mo:base/Time";
import Types "../Types/Types";
import SwapMath "../Lib/SwapMath";
import OrderMath "../Lib/OrderMath";
import ICRC "../Types/ICRC";
import Provider "../MarginProvider/main";

/// Market actore class

/// important constants

shared ({ caller }) actor class Market(details : Types.MarketDetails, init_tick : Nat) = this {

    type TickDetails = Types.TickDetails;
    type SwapParams = Types.SwapParams;
    type OpenOrderParams = Types.OpenOrderParams;
    type OrderDetails = Types.OrderDetails;

    let HUNDRED_BASIS_POINT : Nat = 1_000;

    let BASE_PRICE : Nat = 10 ** 9;

    let users_orders = HashMap.HashMap<Principal, Buffer.Buffer<OrderDetails>>(1, Principal.equal, Principal.hash); // initial capcity of two

    var multiplier_bitmaps = HashMap.HashMap<Nat, Nat>(
        1,
        Nat.equal,
        Types.natHash,
    );

    // a mapping of each tick mapped to its liquidity ;
    var ticks_details = HashMap.HashMap<Nat, Types.TickDetails>(
        1,
        Nat.equal,
        Types.natHash,
    );

    stable var market_details = details;

    stable var current_tick : Nat = init_tick;

    // ======== Query Functions ==========

    /// Gets all orders by a paticular user

    public query func getUserOrders(user : Principal) : async [OrderDetails] {
        switch (users_orders.get(user)) {
            case (?res) { return Buffer.toArray<OrderDetails>(res) };
            case (_) { return [] };
        };
    };

    /// Query Call returning the estimated result of a swap at the particular time
    // returns the amount out of token to be received and the amount remaining  of the token being swapped

    public query func swapResult(amount : Nat, buy : Bool) : async (amount_out : Nat, amount_remaining : Nat) {

        let params = {
            to_buy = buy;
            amount_in = amount;
            init_tick = current_tick;
            stopping_tick = defMaxTick(current_tick, buy);
            snapshot_price = BASE_PRICE;
            multiplier_bitmaps = multiplier_bitmaps;
            ticks_details = ticks_details;
        };

        let swap_result = SwapMath.swap(params);

        return (swap_result.amount_out, swap_result.amount_remaining);

    };

    /// Query calls that returns the best offers for both buys and sells
    /// serves as an ideal getter function for an orderbook display

    /// see OrderMath.getsBestOffers for clarification;
    public query func getBestOffers() : async (best_buys : [(Nat, TickDetails)], best_sells : [(Nat, TickDetails)]) {
        let best_buys = OrderMath._getBestOffers(true, 10, current_tick, multiplier_bitmaps, ticks_details);
        let best_sells = OrderMath._getBestOffers(false, 10, current_tick, multiplier_bitmaps, ticks_details);

        return (best_buys, best_sells);
    };

    // ====== Public functions ======

    /// Swap function for executing swaps on the Market orderbook

    ///  Params

    ///   amount_in :Amount of token to swap
    ///   m_tick :The maximum tick acts as the tick of maximum  executing price (if null the default max tick is used)
    ///   buy :true if sending in Quote token for Base Token
    ///

    public shared ({ caller }) func swap(amount_in : Nat, m_tick : ?Nat, buy : Bool) : async (amount_out : Nat, amount_remaining : Nat) {

        let max_tick : Nat = switch (m_tick) {
            case (?res) { res };
            case (_) { defMaxTick(current_tick, buy) };
        };

        let (asset_in, asset_out) = if (buy) {
            (market_details.quote_token, market_details.base_token);
        } else {
            (market_details.base_token, market_details.quote_token);
        };

        // max_tick should be between the default minimum tick for a sell order and the default  maximum tick for a buy
        let not_exceeded = max_tick <= defMaxTick(current_tick, true) and max_tick >= defMaxTick(current_tick, false);

        assert (
            (await _send_asset_in(caller, asset_in, amount_in)) and not_exceeded
        );

        let (amount_out, amount_remaining) = _swap(amount_in, max_tick, buy);
        ignore (
            await _send_asset_out(caller, asset_out, amount_out),
            await _send_asset_out(caller, asset_in, amount_remaining),
        );

        return (amount_out, amount_remaining);

    };

    /// placeOrder function for creating Limit Orders and providing Liquidity
    ///    Params

    ///          amount_in : amount of asset to send in
    ///          reference_tick : the reference_tick corresponding to the set price for the Order

    ///    NOTE: amount_in should be gretaer than min_flipping amount for the respective token ;
    ///

    public shared ({ caller }) func placeOrder(amount_in : Nat, reference_tick : Nat) : async ?Types.OrderDetails {
        //orders can not be placed at current_tick
        assert (reference_tick != current_tick);

        // gets min flipping amount
        let (min_flipping_amount : Nat, asset_in : Principal) = if (reference_tick > current_tick) {
            (market_details.flipping_amount_base, market_details.base_token);
        } else {
            (market_details.flipping_amount_quote, market_details.quote_token);
        };

        assert (await _send_asset_in(caller, asset_in, amount_in));

        let order_details = switch (_placeOrder(reference_tick, amount_in, min_flipping_amount)) {
            case (?res) { res };
            case (_) {
                ignore await _send_asset_out(caller, asset_in, amount_in);
                return null;
            };
        };

        let user_orders = switch (users_orders.get(caller)) {
            case (?res) { res };
            case (_) { Buffer.Buffer<Types.OrderDetails>(1) };
        };

        user_orders.add(order_details);
        users_orders.put(caller, user_orders);

        return ?order_details;

    };

    /// removeOrder function for cancelling order and withdrawing liquidity for Liquidity Providers

    /// Params
    ///      order_id: ID of that particular user order (corresponds to the index of orfer in User Orders Buffer)
    ///

    public shared ({ caller }) func removeOrder(order_id : Nat) : async () {
        let caller_orders = switch (users_orders.get(caller)) {
            case (?res) { res };
            case (_) { return () };
        };
        let order : Types.OrderDetails = caller_orders.get(order_id);

        let (amount_base, amount_quote) = switch (_removeOrder(order)) {
            case (?res) { res };
            case (_) { return () };
        };
        ignore (
            caller_orders.remove(order_id),
            await _send_asset_out(caller, market_details.base_token, amount_base),
            await _send_asset_out(caller, market_details.quote_token, amount_quote),
        );

    };

    /// openPosition function for opening margined_positions at an interest_rate;
    ///
    ///  collateral = amount of tokens set for collateral;
    ///  debt = amount of tokens being borrowed
    ///  isLong = true if borrowing quote tokenand false otherwise
    ///  m_tick :The maximum tick acts as the tick of maximum  executing price (if null the default max tick is used)
    ///

    public shared ({ caller }) func openPosition(collateral : Nat, debt : Nat, isLong : Bool, m_tick : ?Nat) : async () {

        var order_value = collateral + debt;
        let max_tick : Nat = switch (m_tick) {
            case (?res) { res };
            case (_) { defMaxTick(current_tick, isLong) };
        };

        //as
        let (asset_in, asset_out) = if (isLong) {
            (market_details.quote_token, market_details.base_token);
        } else {
            (market_details.base_token, market_details.quote_token);
        };

        var from_subaccount = ?Principal.toBlob(caller);

        var to_account = {
            owner = Principal.fromActor(this);
            subaccount = ?Principal.toBlob(market_details.margin_provider);
        };

        let tx1_in = await _move_asset(asset_in, collateral, from_subaccount, to_account);

        //assert max _leverage is not exceeded  and caller  has sufficient asset for position collateral ;
        assert ((order_value / collateral < market_details.max_leverage) and tx1_in);

        if (not (await _send_asset_in(market_details.margin_provider, asset_in, order_value))) {
            // refund caller if margin_provider lacks enough liquidity ;
            from_subaccount := ?Principal.toBlob(market_details.margin_provider);
            to_account := {
                owner = Principal.fromActor(this);
                subaccount = ?Principal.toBlob(caller);
            };
            ignore unchecked_move_asset(asset_in, collateral, from_subaccount, to_account);
        };

        switch (await _openPosition(caller, collateral, debt, max_tick, isLong)) {
            case (?(order_size, resulting_debt)) {
                ignore (
                    unchecked_send_asset_out(market_details.margin_provider, asset_in, debt - resulting_debt),
                    unchecked_send_asset_out(market_details.margin_provider, asset_out, order_size),
                );

            };
            case (_) {
                ignore (
                    unchecked_send_asset_out(market_details.margin_provider, asset_in, debt),
                    unchecked_send_asset_out(caller, asset_in, collateral - market_details.spam_penalty_fee),
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
        assert (caller == position_details.owner);
        let margin_provider_actor : Provider.Provider = actor (Principal.toText(market_details.margin_provider));

        //Checks if user already has a position ,exits function
        let inValid = await margin_provider_actor.userHasPosition(position_details.owner);
        if (inValid) {
            return ();
        };

        let buy = not position_details.isLong;

        let (asset_in, asset_out) = if (buy) {
            (market_details.quote_token, market_details.base_token);
        } else {
            (market_details.base_token, market_details.quote_token);
        };

        if (await _send_asset_in(market_details.margin_provider, asset_in, position_details.order_size)) {

            // Unlikely scenerio
            // sending may fail in case the subnet containing the asset canister is down
            //only remove position if it works
            ignore margin_provider_actor.removePosition(position_details.owner);
        } else {
            return ();
        };

        let (total_fee, amount_out, amount_remaining) = await _closePosition(position_details);
        if (amount_out >= total_fee) {
            ignore (
                unchecked_send_asset_out(market_details.margin_provider, asset_out, total_fee),
                unchecked_send_asset_out(position_details.owner, asset_out, amount_out - total_fee),
            );

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

    private func _swap(amount_in : Nat, max_tick : Nat, buy : Bool) : (amount_out : Nat, amount_remaining : Nat) {

        let params = {
            to_buy = buy;
            amount_in = amount_in;
            init_tick = current_tick;
            stopping_tick = max_tick;
            snapshot_price = BASE_PRICE;
            multiplier_bitmaps = multiplier_bitmaps;
            ticks_details = ticks_details;
        };
        let swap_result = SwapMath.swap(params);

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

    private func _placeOrder(reference_tick : Nat, amount_in : Nat, min_flipping_amount : Nat) : ?Types.OrderDetails {

        let params : Types.OpenOrderParams = {
            reference_tick = reference_tick;
            current_tick = current_tick;
            amount_in = amount_in;
            min_flipping_amount = min_flipping_amount;
            multiplier_bitmaps = multiplier_bitmaps;
            ticks_details = ticks_details;
        };
        // returns null if reference tick is flipped and amount in is less than minimum flipping amount ;
        return OrderMath._placeOrder(params);
    };

    /// _removeOrder function

    /// _removeOrder function
    ///      Returns
    ///           amount_base : amount of base token received for  order tick shares
    ///           amount_quote: amount of quote token received for order tick shares
    ///    NOTE:if both amount_base and amount_quote is not  equal to zero this corresponds to partially filled order

    ///    returns null if Order references an uninitialised tick ( see _removeOrder in OrderMath)

    ///

    private func _removeOrder(order : Types.OrderDetails) : ?(amount_base : Nat, amount_quote : Nat) {

        let params = {
            order_details = order;
            multiplier_bitmaps = multiplier_bitmaps;
            ticks_details = ticks_details;
        };

        let remove_order_result = switch (OrderMath._removeOrder(params)) {
            case (?res) { res };
            case (_) { return null };
        };

        return ?(remove_order_result.amount_base, remove_order_result.amount_quote);

    };

    ///  _openPosition function

    // Position token is the token being bought (token out) while Debt token is the token being shorted (token in)

    ///    returns

    ///    order_size = the amount of Position token  received for the leveraged swap
    ///     resulting_debt = the amount of Debt token borrowed that is actually  utilised  (debt reduces by amount_remaining)

    ///    returns null if
    ///        user already has a position
    ///        if amount_remaining after swap is equal or exceeds debt
    ///

    private func _openPosition(user : Principal, collateral : Nat, debt : Nat, max_tick : Nat, isLong : Bool) : async ?(order_size : Nat, resulting_debt : Nat) {
        let margin_provider_actor : Provider.Provider = actor (Principal.toText(market_details.margin_provider));

        if (await margin_provider_actor.userHasPosition(caller)) {
            return null;
        };
        var order_value = collateral + debt;

        let (amount_out, amount_remaining) = _swap(order_value, max_tick, isLong);

        if (amount_remaining >= debt) {
            return null;
        };

        order_value -= amount_remaining;

        let position_details : Types.PositionDetails = {
            owner = caller;
            isLong = isLong;
            debt = order_value - collateral;
            order_size = amount_out;
            interest_rate = market_details.interest_rate;
            time = Time.now();
        };

        ignore margin_provider_actor.putPosition(user, position_details);
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
        let margin_provider_actor : Provider.Provider = actor (Principal.toText(market_details.margin_provider));

        let buy = not position_details.isLong;
        let (amount_out, amount_remaining) = _swap(position_details.order_size, defMaxTick(current_tick, buy), buy);
        let interest_fee = calcInterest(position_details.debt, position_details.interest_rate, position_details.time);

        let total_fee = interest_fee + position_details.debt;
        if (amount_remaining != 0) {
            // updates user position
            let new_debt : Nat = switch (total_fee > amount_out) {
                case (true) {
                    total_fee - amount_out;
                };
                case (false) {
                    0;
                };
            };
            let new_position_details = {
                owner = position_details.owner;
                isLong = position_details.isLong;
                debt = new_debt;
                order_size = amount_remaining;
                interest_rate = position_details.interest_rate;
                time = Time.now();
            };

            ignore margin_provider_actor.putPosition(new_position_details.owner, new_position_details);
        };
        return (total_fee, amount_out, amount_remaining);

    };

    private func _send_asset_in(user : Principal, asset_principal : Principal, amount : Nat) : async Bool {
        let account = {
            owner = Principal.fromActor(this);
            subaccount = null;
        };
        return await _move_asset(asset_principal, amount, ?Principal.toBlob(user), account);

    };

    private func _send_asset_out(user : Principal, asset_principal : Principal, amount : Nat) : async Bool {
        if (amount == 0) {
            return true;
        };
        let account = {
            owner = Principal.fromActor(this);
            subaccount = ?Principal.toBlob(user);
        };
        return await _move_asset(asset_principal, amount, null, account);

    };

    private func _move_asset(asset_principal : Principal, amount : Nat, from_sub : ?Blob, account : ICRC.Account) : async Bool {
        if (amount == 0) {
            return true;
        };
        let asset : ICRC.Actor = actor (Principal.toText(asset_principal));

        let transferArgs : ICRC.TransferArg = {
            from_subaccount = from_sub;
            to = account;
            amount = amount;
            fee = null;
            memo = null;
            created_at_time = null;
        };

        switch (await asset.icrc1_transfer(transferArgs)) {
            case (#Ok(_)) { return true };
            case (#Err(_)) { return false };
        };

    };

    private func unchecked_send_asset_out(user : Principal, asset_principal : Principal, amount : Nat) : async () {
        if (amount == 0) {
            return ();
        };
        let account = {
            owner = Principal.fromActor(this);
            subaccount = ?Principal.toBlob(user);
        };
        ignore unchecked_move_asset(asset_principal, amount, null, account);

    };

    private func unchecked_move_asset(asset_principal : Principal, amount : Nat, from_sub : ?Blob, account : ICRC.Account) : async () {
        if (amount == 0) {
            return ();
        };
        let asset : ICRC.Actor = actor (Principal.toText(asset_principal));

        let transferArgs : ICRC.TransferArg = {
            from_subaccount = from_sub;
            to = account;
            amount = amount;
            fee = null;
            memo = null;
            created_at_time = null;
        };

        ignore asset.icrc1_transfer(transferArgs);

    };

    private func defMaxTick(current_tick : Nat, buy : Bool) : Nat {
        if (buy) {
            current_tick + (10 * HUNDRED_BASIS_POINT);
        } else {
            current_tick - (10 * HUNDRED_BASIS_POINT);
        };
    };

    private func calcInterest(amount : Nat, interest_rate : Nat, start_time : Int) : Nat {

        var fee = 0;
        let one_hour = 3600 * (10 ** 9);

        var starting_time = start_time;
        let current_time = Time.now();

        while (starting_time < current_time) {
            fee += (interest_rate * amount) / (100 * HUNDRED_BASIS_POINT);
            starting_time += one_hour;
        };

        return fee;
    };

};
