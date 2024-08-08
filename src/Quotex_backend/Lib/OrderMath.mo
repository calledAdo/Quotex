import HashMap "mo:base/HashMap";
import Buffer "mo:base/Buffer";
import Types "../Types/Types";
import BitMap "BitMap";

import C "Constants";
import F "Calculations";

module {

    let TICK_SPACING = C.TICK_SPACING;

    type TDS = HashMap.HashMap<Nat, Types.TickDetails>; // Ticks Details
    type MBS = HashMap.HashMap<Nat, Nat>; // Multipliers Bitmpas

    /// calcShares function
    /// calculates the measure of liquidity provided by a particular order at a tick

    /// params
    /// amount_in : amount of order liquidity (base or quote token)
    /// init_total_shares : the total shares owned by all orders providing liquidity at that tick;
    /// init_liquidity :  the amount of liquidity already within the tick

    private func calcShares(amount_in : Nat, init_total_shares : Nat, init_liquidity : Nat) : Nat {
        if (init_liquidity == 0) {
            return amount_in;
        };
        return (amount_in * init_total_shares) / init_liquidity;
    };

    /// calcSharesValue function
    /// calculates the value of any amount of liquidity shares at a particular tick given the total liquidity at that tick

    ///shares : total shares
    ///init_total_shares : the total_amount of shares of orders at that tick
    /// init_liquidity : the current amount of liquidity
    private func calcSharesValue(shares : Nat, init_total_shares : Nat, init_liquidity : Nat) : Nat {
        return (shares * init_liquidity) / init_total_shares;
    };

    ///
    ///_placeOrder function

    public func _placeOrder(params : Types.OpenOrderParams, ticks_spacing : Nat) : ?Types.OrderDetails {

        let reference_tick = params.reference_tick;

        let (multiplier, bit_position) = F.mulAndBit(reference_tick, ticks_spacing);

        let ticks_details = params.ticks_details;

        let ref_tick_details = switch (ticks_details.get(params.reference_tick)) {
            case (?res) { res };
            case (_) {
                if (params.amount_in < params.min_flipping_amount) {
                    return null;
                };
                {
                    liquidity_base = 0;
                    liquidity_quote = 0;
                    total_shares = 0;
                };
            };
        };

        var user_tick_shares = 0;

        // above the current tick all liquidity is in base token
        let new_tick_details = switch (reference_tick > params.current_tick) {
            case (true) {
                user_tick_shares := calcShares(params.amount_in, ref_tick_details.total_shares, ref_tick_details.liquidity_base);

                {
                    liquidity_base = ref_tick_details.liquidity_base + params.amount_in;
                    liquidity_quote = 0;

                    total_shares = ref_tick_details.total_shares + user_tick_shares;

                };
            };
            case (false) {
                user_tick_shares := calcShares(params.amount_in, ref_tick_details.total_shares, ref_tick_details.liquidity_quote);

                {
                    liquidity_base = 0;
                    liquidity_quote = ref_tick_details.liquidity_quote + params.amount_in;
                    total_shares = ref_tick_details.total_shares + user_tick_shares;
                };
            };
        };

        ticks_details.put(reference_tick, new_tick_details);

        let multiplier_bitmaps = params.multiplier_bitmaps;

        var ref_bitmap : Nat = switch (multiplier_bitmaps.get(multiplier)) {
            case (?res) { res };
            case (_) { 0 };
        };

        //if both base liquidity and quote liquidity is zero  means tick is  uninitialised .
        let tick_flipped : Bool = ref_tick_details.liquidity_base == 0 and ref_tick_details.liquidity_quote == 0;

        let new_ref_bitmap : Nat = if (tick_flipped) {
            BitMap.flipBit(ref_bitmap, bit_position);
        } else { ref_bitmap };

        multiplier_bitmaps.put(multiplier, new_ref_bitmap);

        return ?{
            reference_tick = reference_tick;
            tick_shares = user_tick_shares;
        };

    };

    ///_removeOrder function
    ///
    ///returns null if
    //reference tick of order does not exist or is uninitialised
    ///

    public func _removeOrder(params : Types.RemoveOrderParams, ticks_spacing : Nat) : ?Types.RemoveOrderResult {

        let order_details = params.order_details;

        let reference_tick = order_details.reference_tick;

        let (multiplier, bit_position) = F.mulAndBit(reference_tick, ticks_spacing);

        let ticks_details = params.ticks_details;

        let ref_tick_details : Types.TickDetails = switch (ticks_details.get(reference_tick)) {
            case (?res) { res };
            case (_) { return null };
        };

        let amount_base = calcSharesValue(
            order_details.tick_shares,
            ref_tick_details.total_shares,
            ref_tick_details.liquidity_base,
        );

        let amount_quote = calcSharesValue(
            order_details.tick_shares,
            ref_tick_details.total_shares,
            ref_tick_details.liquidity_quote,
        );
        // calculate the amount of the asset that the user gets with the amount of shares going in ;

        //calculates the amount of quote token to get for that shares amount
        //calculates the amount of base token to get for that shares amount ;;

        let multiplier_bitmaps = params.multiplier_bitmaps;

        var ref_bitmap : Nat = switch (multiplier_bitmaps.get(multiplier)) {
            case (?res) { res };
            case (_) { return null };
        };
        //if shares equals total shares ,entire liquidity is being removed ;
        if (order_details.tick_shares == ref_tick_details.total_shares) {

            // flip bitmap
            ref_bitmap := BitMap.flipBit(ref_bitmap, bit_position);
            //update multiplier bitmaps
            multiplier_bitmaps.put(multiplier, ref_bitmap);

            // delete ticks details
            ticks_details.delete(reference_tick);

        } else {
            ticks_details.put(
                reference_tick,
                {
                    liquidity_base = ref_tick_details.liquidity_base - amount_base;
                    liquidity_quote = ref_tick_details.liquidity_quote - amount_quote;
                    total_shares = ref_tick_details.total_shares - order_details.tick_shares;
                },
            )

        };

        return ?{
            amount_base = amount_base;
            amount_quote = amount_quote;
        };
    };

    public func _getBestOffers(buy : Bool, num_of_offers : Nat, current_state_tick : Nat, bitmaps : MBS, ticks_details : TDS, ticks_spacing : Nat) : [(tick : Nat, tick_details : Types.TickDetails)] {

        let best_offers = Buffer.Buffer<(Nat, Types.TickDetails)>(num_of_offers);

        var current_tick = current_state_tick;

        let max_tick : Nat = if (buy) {
            current_tick + (10 * C.HUNDRED_BASIS_POINT);
        } else {
            current_tick - (10 * C.HUNDRED_BASIS_POINT);
        };

        label looping while (best_offers.size() <= num_of_offers) {
            // tick multipier
            let multiplier = current_tick / (C.HUNDRED_BASIS_POINT * TICK_SPACING);
            //  let current_bit_position = (current_tick % C.HUNDRED_BASIS_POINT) / 10;
            switch (bitmaps.get(multiplier)) {
                // gets the bitmap of the current multiplier
                case (?bitmap) {
                    // gets the net tick
                    let next_tick = BitMap.next_initialized_tick(bitmap, current_tick, buy, ticks_spacing);

                    //checks next tick details
                    switch (ticks_details.get(next_tick)) {
                        case (?tick_details) {
                            // if liquidity exists ,add tick and tick_details to
                            if (tick_details.liquidity_base > 0 or tick_details.liquidity_quote > 0) {
                                best_offers.add((next_tick, tick_details));
                            };
                            if (F.exceeded(max_tick, current_tick, buy)) {
                                break looping;
                            };

                            current_tick := next_tick;
                        };
                        case (_) {};
                    };
                };
                case (_) {};
            };
        };

        return Buffer.toArray(best_offers);

    };

};
