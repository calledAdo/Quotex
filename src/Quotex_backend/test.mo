import Principal "mo:base/Principal";
import Blob "mo:base/Blob";

actor {

    public shared ({ caller }) func whoami() : async Principal {
        return caller;
    };

    public shared ({ caller }) func sub() : async ?Blob {
        ?Principal.toLedgerAccount(caller, null);
    };
    // //let MINIMUM_BASIS_POINT = 10;

    // type OrderDetails = Types.OrderDetails;

    // var current_tick = 199900_000;

    // //  let users_orders = HashMap.HashMap<Principal, Buffer.Buffer<OrderDetails>>(1, Principal.equal, Principal.hash); // initial capcity of two

    // let m_multipliers_bitmaps = HashMap.HashMap<Nat, Nat>(
    //     1,
    //     Nat.equal,
    //     Types.natHash,
    // );

    // //each tick mapped to the amount of token0 or amount of token 1
    // let m_ticks_details = HashMap.HashMap<Nat, Types.TickDetails>(
    //     1,
    //     Nat.equal,
    //     Types.natHash,

    // );

    // public query func _tickDetails(reference_tick : Nat) : async Types.TickDetails {
    //     let ref_tick_details = switch (m_ticks_details.get(reference_tick)) {
    //         case (?res) { res };
    //         case (_) {
    //             {
    //                 liquidity_token0 = 0;
    //                 liquidity_token1 = 0;
    //                 total_shares = 0;
    //             };
    //         };
    //     };
    //     return ref_tick_details;
    // };

    // public func _swap(amount_in : Nat, in1out0 : Bool) : async (amount_out : Nat, amount_remaining : Nat, current_tick : Nat) {

    //     let params = {
    //         in1out0 = in1out0;
    //         amount_in = amount_in;
    //         init_tick = current_tick;
    //         stopping_tick = F.defMaxTick(current_tick, in1out0);
    //         m_multipliers_bitmaps = m_multipliers_bitmaps;
    //         m_ticks_details = m_ticks_details;
    //     };

    //     let swap_constants = {
    //         token0_decimal = 8;
    //         token1_decimal = 6;
    //         base_price_multiplier = 10000;
    //         tick_spacing = 10;
    //     };
    //     let swap_result = SwapLib.swap(params, swap_constants);

    //     current_tick := swap_result.current_tick;

    //     return (swap_result.amount_out, swap_result.amount_remaining, current_tick);
    // };

    // public func _placeOrder(reference_tick : Nat, amount_in : Nat) : async Types.OrderDetails {
    //     let min_flipping_amount = 0; //assuming a decimal of 10**9
    //     let params : Types.OpenOrderParams = {
    //         reference_tick = reference_tick;
    //         current_tick = current_tick;
    //         amount_in = amount_in;
    //         min_flipping_amount = min_flipping_amount;
    //         m_multipliers_bitmaps = m_multipliers_bitmaps;
    //         m_ticks_details = m_ticks_details;
    //     };

    //     return OrderLib._placeOrder(params, 10)

    // };

    // public func _removeOrder(order_details : Types.OrderDetails) : async ?Types.RemoveOrderResult {

    //     let params = {
    //         order_details = order_details;
    //         m_multipliers_bitmaps = m_multipliers_bitmaps;
    //         m_ticks_details = m_ticks_details;
    //     };

    //     return OrderLib._removeOrder(params, 10);
    // };
};
