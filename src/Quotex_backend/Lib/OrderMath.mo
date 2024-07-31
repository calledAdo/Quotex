import Nat64 "mo:base/Nat64";
import HashMap "mo:base/HashMap";
import Buffer "mo:base/Buffer";
import Types "../Types/Types";
import BitMap "BitMap";

module {

    type TD = HashMap.HashMap<Nat, Types.TickDetails>; // Ticks Details
    type MB = HashMap.HashMap<Nat, Nat>; // Multipliers Bitmpas

    private func one_percent() : Nat64 {
        return 1_000;
    };

    private func calcShares(amount_in : Nat, total_shares : Nat, init_liquidity : Nat) : Nat {
        if (init_liquidity == 0) {
            return amount_in;
        };
        return (amount_in * total_shares) / init_liquidity;
    };

    private func calcSharesValue(shares : Nat, total_shares : Nat, init_liquidity : Nat) : Nat {
        return (shares * init_liquidity) / total_shares;
    };
    ///
    ///
    ///
    ///

    public func _placeOrder(params : Types.OpenOrderParams) : Types.OpenOrderResult {

        let multiplier = params.reference_tick / one_percent();
        let bit_position = (params.reference_tick % one_percent()) / 10;

        let ticks_details = params.ticks_details;

        let ref_tick_details = switch (ticks_details.get(Nat64.toNat(params.reference_tick))) {
            case (?res) { res };
            case (_) {
                {
                    liquidity_base = 0;
                    liquidity_quote = 0;
                    total_shares = 0;
                };
            };
        };

        var user_tick_shares = 0;

        let new_tick_details = switch (params.reference_tick > params.current_tick) {
            case (true) {
                user_tick_shares := calcShares(params.amount_in, ref_tick_details.total_shares, ref_tick_details.liquidity_base);

                {
                    liquidity_base = params.amount_in + ref_tick_details.liquidity_base;
                    liquidity_quote = 0;

                    total_shares = ref_tick_details.total_shares + user_tick_shares;

                };
            };
            case (false) {
                user_tick_shares := calcShares(params.amount_in, ref_tick_details.total_shares, ref_tick_details.liquidity_quote);

                {
                    liquidity_base = 0;
                    liquidity_quote = params.amount_in + ref_tick_details.liquidity_quote;
                    total_shares = ref_tick_details.total_shares + user_tick_shares;
                };
            };
        };

        ticks_details.put(Nat64.toNat(params.reference_tick), new_tick_details);

        let multiplier_bitmaps = params.multiplier_bitmaps;

        var ref_bitmap : Nat = switch (multiplier_bitmaps.get(Nat64.toNat(multiplier))) {
            case (?res) { res };
            case (_) { 0 };
        };

        //if liquidity is not equal to zero  means tick was already set i.e no flipping needed

        let tick_flipped = ref_tick_details.liquidity_base == 0 and ref_tick_details.liquidity_quote == 0;
        let new_ref_bitmap = switch (tick_flipped) {
            case (true) { BitMap.flipBit(ref_bitmap, bit_position) };
            case (false) { ref_bitmap };
        };
        multiplier_bitmaps.put(Nat64.toNat(multiplier), new_ref_bitmap);

        return {
            order_details = {
                reference_tick = params.reference_tick;
                tick_shares = user_tick_shares;
            };
            tick_flipped = tick_flipped;
            new_multiplier_bitmaps = multiplier_bitmaps;
            new_ticks_details = ticks_details

        };

    };

    ///
    ///
    ///
    ///

    public func _removeOrder(params : Types.CloseOrderParams) : ?Types.CloseOrderResult {

        let order_details = params.order_details;

        let reference_tick = order_details.reference_tick;

        let multiplier = reference_tick / one_percent();
        let bit_position = (reference_tick % one_percent()) / 10;

        let ticks_details = params.ticks_details;

        // get the tick details ;

        let ref_tick_details = switch (ticks_details.get(Nat64.toNat(reference_tick))) {
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

        var ref_bitmap = switch (multiplier_bitmaps.get(Nat64.toNat(multiplier))) {
            case (?res) { res };
            case (_) { return null };
        };
        //if shares equals total shares ,entire liquidity is being removed ;
        if (order_details.tick_shares == ref_tick_details.total_shares) {
            ref_bitmap := BitMap.flipBit(ref_bitmap, bit_position);
            ticks_details.delete(Nat64.toNat(reference_tick));

        } else {
            ticks_details.put(
                Nat64.toNat(
                    reference_tick
                ),
                {
                    liquidity_base = ref_tick_details.liquidity_base - amount_base;
                    liquidity_quote = ref_tick_details.liquidity_quote - amount_quote;
                    total_shares = order_details.tick_shares;
                },
            )

        };
        // get the new_tick details

        // checks if the resukting amount of both base and quite token is zero
        //and if soo flips the bit

        return ?{
            amount_base = amount_base;
            amount_quote = amount_quote;
            multiplier_bitmaps = multiplier_bitmaps;
            ticks_details = ticks_details;
        };
    };

    public func _getBestOffers(buy : Bool, num_of_offers : Nat, current_state_tick : Nat64, bitmaps : MB, ticks_details : TD) : [(tick : Nat64, tick_details : Types.TickDetails)] {

        let best_offers = Buffer.Buffer<(Nat64, Types.TickDetails)>(num_of_offers);

        var current_tick = current_state_tick;
        let max_tick = current_state_tick + (10 * one_percent());

        label looping while (best_offers.size() <= num_of_offers) {
            // tick multipier
            let multiplier = current_tick / one_percent();
            //  let current_bit_position = (current_tick % one_percent()) / 10;
            switch (bitmaps.get(Nat64.toNat(multiplier))) {
                // gets the bitmap of the current multiplier
                case (?bitmap) {
                    // gets the net tick
                    let next_tick = BitMap.next_initialized_tick(bitmap, current_tick, buy);

                    //checks next tick details
                    switch (ticks_details.get(Nat64.toNat(next_tick))) {
                        case (?tick_details) {
                            // if liquidity exists ,add tick and tick_details to
                            if (tick_details.liquidity_base > 0 or tick_details.liquidity_quote > 0) {
                                best_offers.add((next_tick, tick_details));
                            };
                            if (next_tick < max_tick) {
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
