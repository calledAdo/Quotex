import Types "../Types/Types";
import BitMap "BitMap";
import PriceMath "PriceMath";
import Nat64 "mo:base/Nat64";

module {

    private func one_percent() : Nat64 {
        return 1_000;
    };

    public func swap(params : Types.SwapParams) : Types.SwapResult {

        var ticks_details = params.ticks_details;

        //
        var current_state_tick = params.init_tick;

        var amount_out = 0;
        var amount_remaining = params.amount_in;

        label swaploop while (current_state_tick < params.max_tick) {

            //
            let swap_result = swap_at_tick(params);

            ticks_details := swap_result.new_ticks_details;

            // multiplier_bitmaps := swap_result.new_bitmaps;

            //
            amount_out += swap_result.amount_out;

            amount_remaining := swap_result.amount_remaining;

            //break loop
            if (amount_remaining == 0) {
                break swaploop;
            };

            //
            let current_multiplier = current_state_tick / one_percent();

            //multiplier_bitmaps for current multiplier ;
            let current_bitmap : Nat = switch (params.multiplier_bitmaps.get(Nat64.toNat(current_multiplier))) {
                case (?res) { res };
                case (_) {
                    0; //Recheck logic
                };
            };

            current_state_tick := BitMap.next_initialized_tick(current_bitmap, current_state_tick, params.to_buy);

        };

        return {
            current_tick = current_state_tick;
            amount_out = amount_out;
            amount_remaining = amount_remaining;
            new_ticks_details = ticks_details;
        };
    };

    private func swap_at_tick(params : Types.SwapParams) : Types.SwapAtTickResult {

        let multiplier = params.init_tick / one_percent();
        let bit_position = (params.init_tick % one_percent()) / 10;

        //var amount out = set to zero
        var amount_out = 0;

        var amount_remaining = 0;

        var ticks_details = params.ticks_details;

        //calculate the current price
        let tick_price = PriceMath.tick_to_price(multiplier, bit_position, params.snapshot_price);

        let current_tick_details = switch (ticks_details.get(Nat64.toNat(params.init_tick))) {
            case (?res) { res };
            case (_) {
                return {
                    amount_remaining = params.amount_in;
                    amount_out = 0;
                    new_ticks_details = ticks_details;
                };
            };
        };

        //Init_tick liquidity = get the amount of liquidity in base token or quote token in the current tick
        let init_tick_liquidity = switch (params.to_buy) {
            case (true) { current_tick_details.liquidity_base };
            case (false) { current_tick_details.liquidity_quote };
        };
        // get the equivalent amount of token equivalent to liquidity (base or quote token ,depending on buy or sell trade)
        let init_liquidity_equivalent = PriceMath._equivalent(init_tick_liquidity, tick_price, not params.to_buy);

        if (init_liquidity_equivalent <= params.amount_in) {
            // set amount out += init liquidity
            amount_out := init_tick_liquidity;

            //set amount_remaining = amount_in - Init liquidity
            amount_remaining := params.amount_in - init_liquidity_equivalent;

            let new_tick = switch (params.to_buy) {
                case (true) {
                    {
                        liquidity_base = 0;
                        liquidity_quote = current_tick_details.liquidity_quote + init_liquidity_equivalent;
                        total_shares = current_tick_details.total_shares;
                    };
                };
                case (false) {
                    {
                        liquidity_base = current_tick_details.liquidity_base + init_liquidity_equivalent;
                        liquidity_quote = 0;
                        total_shares = current_tick_details.total_shares;
                    };
                };
            };

            ticks_details.put(Nat64.toNat(params.init_tick), new_tick)

        } else {

            // return equivalent
            amount_out := PriceMath._equivalent(params.amount_in, tick_price, params.to_buy);

            let new_tick = switch (params.to_buy) {
                case (true) {
                    {
                        liquidity_base : Nat = init_tick_liquidity - amount_out;
                        liquidity_quote = current_tick_details.liquidity_quote + params.amount_in;
                        total_shares = current_tick_details.total_shares;
                    };
                };
                case (false) {
                    {
                        liquidity_base = current_tick_details.liquidity_base + params.amount_in;
                        liquidity_quote : Nat = init_tick_liquidity - amount_out;
                        total_shares = current_tick_details.total_shares;
                    };
                };
            };
            ticks_details.put(
                Nat64.toNat(params.init_tick),
                new_tick,
            );

        };
        return {
            amount_out = amount_out;
            amount_remaining = amount_remaining;
            new_ticks_details = ticks_details;
        };

    };

};
