import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Buffer "mo:base/Buffer";
import Types "Types/Types";
import SwapMath "Lib/SwapMath";
import OrderMath "Lib/OrderMath";
import ICRC "Types/ICRC";

shared ({ caller }) actor class Market(base_token : Principal, quote_token : Principal) = this {

    type TickDetails = Types.TickDetails;
    type SwapParams = Types.SwapParams;
    type OpenOrderParams = Types.OpenOrderParams;
    type OrderDetails = Types.OrderDetails;

    let ONE_PERCENT : Nat64 = 1_000;

    let users_orders = HashMap.HashMap<Principal, Buffer.Buffer<OrderDetails>>(1, Principal.equal, Principal.hash); // initial capcity of two

    var multiplier_bitmaps = HashMap.HashMap<Nat, Nat>(
        1,
        Nat.equal,
        Types.natHash,
    );

    //each tick mapped to the amount of token0 or amount of token 1
    var ticks_details = HashMap.HashMap<Nat, Types.TickDetails>(
        1,
        Nat.equal,
        Types.natHash,
    );

    stable var currrent_tick : Nat64 = 0;
    stable var snapshot_price : Nat64 = 0;

    stable let base_principal = base_token;
    stable let quote_principal = quote_token;

    stable var flipping_amount_base : Nat = 0;
    stable var flipping_amount_quote : Nat = 0;

    // ======== Query Functions ==========

    public query func getUserOrders(user : Principal) : async [OrderDetails] {
        switch (users_orders.get(user)) {
            case (?res) { return Buffer.toArray<OrderDetails>(res) };
            case (_) { return [] };
        };
    };

    public query func swapResult(amount : Nat, buy : Bool) : async (amount_out : Nat, amount_remaining : Nat) {

        let max_tick = currrent_tick + (5 * ONE_PERCENT);
        let params = {
            to_buy = buy;
            amount_in = amount;
            init_tick = currrent_tick;
            max_tick = max_tick;
            snapshot_price = snapshot_price;
            multiplier_bitmaps = multiplier_bitmaps;
            ticks_details = ticks_details;
        };

        let swap_result = SwapMath.swap(params);

        return (swap_result.amount_out, swap_result.amount_remaining);

    };

    public query func getBestOffers() : async (best_buys : [(Nat64, TickDetails)], best_sells : [(Nat64, TickDetails)]) {
        let best_buys = OrderMath._getBestOffers(true, 10, currrent_tick, multiplier_bitmaps, ticks_details);
        let best_sells = OrderMath._getBestOffers(false, 10, currrent_tick, multiplier_bitmaps, ticks_details);

        return (best_buys, best_sells);
    };

    // ====== Public functions ======

    public shared ({ caller }) func swap(amount_in : Nat, max_tick : Nat64, buy : Bool) : async () {

        let (asset_in, asset_out) = switch (buy) {
            case (true) { (quote_principal, base_principal) };
            case (false) { (base_principal, quote_principal) };
        };

        assert (
            (await _send_asset_in(caller, asset_in, amount_in)) and max_tick < (currrent_tick + (10 * ONE_PERCENT))
        );

        let params = {
            to_buy = buy;
            amount_in = amount_in;
            init_tick = currrent_tick;
            max_tick = max_tick;
            snapshot_price = snapshot_price;
            multiplier_bitmaps = multiplier_bitmaps;
            ticks_details = ticks_details;
        };

        let (amount_out, amount_remaining) = _swap(params);
        let _ = _send_asset_out(caller, asset_out, amount_out);
        let _ = _send_asset_out(caller, asset_in, amount_remaining);

    };

    public shared ({ caller }) func placeOrder(amount_in : Nat, reference_tick : Nat64) : async ?Types.OrderDetails {

        let (min_flipping_amount : Nat, asset_in : Principal) = if (reference_tick > currrent_tick) {
            (flipping_amount_base, base_principal);
        } else { (flipping_amount_quote, quote_principal) };

        let _ = await _send_asset_in(caller, asset_in, amount_in);

        let params : OpenOrderParams = {
            reference_tick = reference_tick;
            current_tick = currrent_tick;
            amount_in = amount_in;
            min_flipping_amount = min_flipping_amount;
            snapshot_price = snapshot_price;
            multiplier_bitmaps = multiplier_bitmaps;
            ticks_details = ticks_details;
        };

        let order_details = switch (_placeOrder(params)) {
            case (?res) { res };
            case (_) {
                let _ = await _send_asset_out(caller, asset_in, amount_in);
                return null;
            };
        };

        let caller_orders = switch (users_orders.get(caller)) {
            case (?res) { res };
            case (_) { Buffer.Buffer<Types.OrderDetails>(1) };
        };

        caller_orders.add(order_details);
        users_orders.put(caller, caller_orders);

        return ?order_details;

        //let user_order = switch(user)
    };

    public shared ({ caller }) func removeOrder(order_id : Nat) : async () {
        let caller_orders = switch (users_orders.get(caller)) {
            case (?res) { res };
            case (_) { return () };
        };
        let order : Types.OrderDetails = caller_orders.get(order_id);
        let params = {
            order_details = order;
            multiplier_bitmaps = multiplier_bitmaps;
            ticks_details = ticks_details;
        };

        let (amount_base, amount_quote) = switch (_removeOrder(params)) {
            case (?res) { res };
            case (_) { return () };
        };
        let _ = caller_orders.remove(order_id);

        let _ = _send_asset_out(caller, base_principal, amount_base);
        let _ = _send_asset_out(caller, quote_principal, amount_quote);

    };

    // ------- Admin Functions ----------

    private func _swap(params : Types.SwapParams) : (amount_out : Nat, amount_remaining : Nat) {

        let swap_result = SwapMath.swap(params);

        ticks_details := swap_result.new_ticks_details;

        currrent_tick := swap_result.current_tick;

        return (swap_result.amount_out, swap_result.amount_remaining);
    };

    private func _placeOrder(params : OpenOrderParams) : ?Types.OrderDetails {

        let order_result : Types.OpenOrderResult = OrderMath._placeOrder(params);
        if (order_result.tick_flipped and (params.amount_in < params.min_flipping_amount)) {
            return null;
        };

        multiplier_bitmaps := order_result.new_multiplier_bitmaps;
        ticks_details := order_result.new_ticks_details;

        return ?order_result.order_details;
    };

    private func _removeOrder(params : Types.CloseOrderParams) : ?(amount_base : Nat, amount_quote : Nat) {
        let close_order_result = switch (OrderMath._removeOrder(params)) {
            case (?res) { res };
            case (_) { return null };
        };

        multiplier_bitmaps := close_order_result.multiplier_bitmaps;
        ticks_details := close_order_result.ticks_details;

        return ?(close_order_result.amount_base, close_order_result.amount_quote);

    };

    private func _send_asset_in(user : Principal, asset_principal : Principal, amount : Nat) : async Bool {

        if (amount == 0) {
            return true;
        };

        let asset : ICRC.Actor = actor (Principal.toText(asset_principal));
        let account = {
            owner = Principal.fromActor(this);
            subaccount = null;
        };
        let transferArgs : ICRC.TransferArg = {
            from_subaccount = ?Principal.toBlob(user);
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

    private func _send_asset_out(user : Principal, asset_principal : Principal, amount : Nat) : async Bool {

        if (amount == 0) {
            return true;
        };
        let asset : ICRC.Actor = actor (Principal.toText(asset_principal));
        let account = {
            owner = Principal.fromActor(this);
            subaccount = ?Principal.toBlob(user);
        };

        let transferArgs : ICRC.TransferArg = {
            from_subaccount = null;
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

};
