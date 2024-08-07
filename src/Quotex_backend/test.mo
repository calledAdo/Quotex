import HashMap "mo:base/HashMap";
import C "Lib/PureFuncs";
import Nat "mo:base/Nat";
import Types "./Types/Types";
import OrderMath "Lib/OrderMath";
import SwapMath "Lib/SwapMath";

actor {

    //let MINIMUM_BASIS_POINT = 10;

    type OrderDetails = Types.OrderDetails;

    let BASE_PRICE = 1 * (10 ** 9);

    var current_tick = 199900;

    var count = 0;

    //  let users_orders = HashMap.HashMap<Principal, Buffer.Buffer<OrderDetails>>(1, Principal.equal, Principal.hash); // initial capcity of two

    let multiplier_bitmaps = HashMap.HashMap<Nat, Nat>(
        1,
        Nat.equal,
        Types.natHash,
    );

    //each tick mapped to the amount of token0 or amount of token 1
    let ticks_details = HashMap.HashMap<Nat, Types.TickDetails>(
        1,
        Nat.equal,
        Types.natHash,

    );

    public query func update() : async Nat {
        count += 1;
        return count;
    };

    public func returnTick() : async Nat {
        let num = await update();
        count += 1;
        return count;
    };

    public func _swap(amount_in : Nat, max_tick : Nat, buy : Bool) : async (amount_out : Nat, amount_remaining : Nat, current_tick : Nat) {

        let params = {
            to_buy = buy;
            amount_in = amount_in;
            init_tick = current_tick;
            max_tick = max_tick;
            stopping_tick = C.defMaxTick(current_tick, buy);
            snapshot_price = BASE_PRICE;
            multiplier_bitmaps = multiplier_bitmaps;
            ticks_details = ticks_details;
        };
        let swap_result = SwapMath.swap(params);

        current_tick := swap_result.current_tick;

        return (swap_result.amount_out, swap_result.amount_remaining, current_tick);
    };

    public func _placeOrder(reference_tick : Nat, amount_in : Nat) : async ?Types.OrderDetails {
        let min_flipping_amount = 1000; //assuming a decimal of 10**9
        let params : Types.OpenOrderParams = {
            reference_tick = reference_tick;
            current_tick = current_tick;
            amount_in = amount_in;
            min_flipping_amount = min_flipping_amount;
            multiplier_bitmaps = multiplier_bitmaps;
            ticks_details = ticks_details;
        };

        return OrderMath._placeOrder(params)

    };

    public func _removeOrder(order_details : Types.OrderDetails) : async ?Types.RemoveOrderResult {

        let params = {
            order_details = order_details;
            multiplier_bitmaps = multiplier_bitmaps;
            ticks_details = ticks_details;
        };

        return OrderMath._removeOrder(params);
    };

    public query func _tickDetails(reference_tick : Nat) : async Types.TickDetails {
        let ref_tick_details = switch (ticks_details.get(reference_tick)) {
            case (?res) { res };
            case (_) {
                {
                    liquidity_base = 0;
                    liquidity_quote = 0;
                    total_shares = 0;
                };
            };
        };
        return ref_tick_details;
    };
    // public query func most_sig(num : Nat64) : async Nat64 {
    //     return Bit.most_significant_bit_position(num, 29);
    // };

    // public query func least_sig(num : Nat64) : async Nat64 {
    //     return Bit.least_significant_bit_position(num, 29);
    // };

    // public query func next_tick(bitmap : Nat, tick : Nat64, buy : Bool) : async Nat64 {
    //     return BitMap.next_initialized_tick(bitmap, tick, buy);
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
