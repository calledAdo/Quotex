import HashMap "mo:base/HashMap";
import F "Lib/Calculations";
import Nat "mo:base/Nat";
import Types "./Market/Types";
import OrderLib "Lib/OrderLib";
import SwapLib "Lib/SwapLib";
import C "Lib/Constants";

actor {

    //let MINIMUM_BASIS_POINT = 10;

    type OrderDetails = Types.OrderDetails;

    var current_tick = 199900_000;

    //  let users_orders = HashMap.HashMap<Principal, Buffer.Buffer<OrderDetails>>(1, Principal.equal, Principal.hash); // initial capcity of two

    let m_multipliers_bitmaps = HashMap.HashMap<Nat, Nat>(
        1,
        Nat.equal,
        Types.natHash,
    );

    //each tick mapped to the amount of token0 or amount of token 1
    let m_ticks_details = HashMap.HashMap<Nat, Types.TickDetails>(
        1,
        Nat.equal,
        Types.natHash,

    );

    public func _swap(amount_in : Nat, in1out0 : Bool) : async (amount_out : Nat, amount_remaining : Nat, current_tick : Nat) {

        let params = {
            in1out0 = in1out0;
            amount_in = amount_in;
            init_tick = current_tick;
            stopping_tick = F.defMaxTick(current_tick, in1out0);
            m_multipliers_bitmaps = m_multipliers_bitmaps;
            m_ticks_details = m_ticks_details;
        };

        let swap_constants = {
            token0_decimal = 8;
            token1_decimal = 6;
            base_price_multiplier = 10000;
            tick_spacing = 10;
        };
        let swap_result = SwapLib.swap(params, swap_constants);

        current_tick := swap_result.current_tick;

        return (swap_result.amount_out, swap_result.amount_remaining, current_tick);
    };

    public func _placeOrder(reference_tick : Nat, amount_in : Nat) : async Types.OrderDetails {
        let min_flipping_amount = 0; //assuming a decimal of 10**9
        let params : Types.OpenOrderParams = {
            reference_tick = reference_tick;
            current_tick = current_tick;
            amount_in = amount_in;
            min_flipping_amount = min_flipping_amount;
            m_multipliers_bitmaps = m_multipliers_bitmaps;
            m_ticks_details = m_ticks_details;
        };

        return OrderLib._placeOrder(params, 10)

    };

    public func _removeOrder(order_details : Types.OrderDetails) : async ?Types.RemoveOrderResult {

        let params = {
            order_details = order_details;
            m_multipliers_bitmaps = m_multipliers_bitmaps;
            m_ticks_details = m_ticks_details;
        };

        return OrderLib._removeOrder(params, 10);
    };

    public query func _tickDetails(reference_tick : Nat) : async Types.TickDetails {
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

    public query func defMaxTick(current_tick : Nat, in1out0 : Bool) : async Nat {
        if (in1out0) {
            current_tick + (50 * C.HUNDRED_PERCENT);
        } else {
            current_tick - (50 * C.HUNDRED_PERCENT);
        };
    };

    // public query func most_sig(num : Nat64) : async Nat64 {
    //     return Bit.most_significant_bit_position(num, 29);
    // };

    // public query func least_sig(num : Nat64) : async Nat64 {
    //     return Bit.least_significant_bit_position(num, 29);
    // };

    // public query func next_tick(bitmap : Nat, tick : Nat64, in1out0 : Bool) : async Nat64 {
    //     return BitMap.next_initialized_tick(bitmap, tick, in1out0);
    // };

    // public query func flipBit(bitmap : Nat, bit_position : Nat64) : async Nat {
    //     return BitMap.flipBit(bitmap, bit_position);
    // };

    // public query func tick_to_price(tick : Nat) : async Nat {

    //     let multiplier = tick / one_percent();
    //     let current_bit_position : Nat = (tick % one_percent()) / 10;

    //     // let percentile = (bit_position * one_percent()) / 100;
    //     // let percentage = (multiplier * one_percent()) + percentile;

    //     // return Nat64.toNat(percentage);

    //     return PriceMath.tick_to_price(multiplier, current_bit_position, BASE_PRICE);
    // };

};
