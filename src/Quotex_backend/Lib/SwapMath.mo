import Types "../Types/Types";
import BitMap "BitMap";
import PriceMath "PriceMath";

import F "Calculations";

module {

    /// swap function

    public func swap(params : Types.SwapParams, constants : Types.SwapConstants) : Types.SwapResult {

        let ticks_details = params.ticks_details;

        var current_tick = params.init_tick;

        var amount_out = 0;
        var amount_remaining = params.amount_in;

        label swaploop while (not F.exceeded(params.stopping_tick, current_tick, params.to_buy)) {

            // create  new swap parameters  for every new iteration of the loop
            let new_params = {
                to_buy = params.to_buy;
                amount_in = amount_remaining;
                init_tick = current_tick;
                stopping_tick = params.stopping_tick;
                multiplier_bitmaps = params.multiplier_bitmaps;
                ticks_details = ticks_details;
            };

            //
            let swap_result = swap_at_tick(new_params, constants);

            // multiplier_bitmaps := swap_result.new_bitmaps;

            //
            amount_out += swap_result.amount_out;

            amount_remaining := swap_result.amount_remaining;

            //break loop
            if (amount_remaining == 0) {
                break swaploop;
            };

            //
            let (current_multiplier, _) = F.mulAndBit(current_tick, constants.tick_spacing);
            //multiplier_bitmaps for current multiplier ;
            let current_bitmap : Nat = switch (params.multiplier_bitmaps.get(current_multiplier)) {
                case (?res) { res };
                case (_) {
                    0;
                };
            };

            current_tick := BitMap.next_initialized_tick(current_bitmap, current_tick, params.to_buy, constants.tick_spacing);

        };

        return {
            current_tick = current_tick;
            amount_out = amount_out;
            amount_remaining = amount_remaining;
        };
    };

    private func swap_at_tick(params : Types.SwapParams, constants : Types.SwapConstants) : Types.SwapAtTickResult {

        //var amount out = set to zero
        var amount_out = 0;

        var amount_remaining = params.amount_in;

        let ticks_details = params.ticks_details;

        //calculate the current price
        let tick_price = PriceMath.tick_to_price(params.init_tick, constants.base_price_multiplier);

        let current_tick_details = switch (ticks_details.get(params.init_tick)) {
            case (?res) { res };
            case (_) {
                // if current ticks details can not be found return default
                return {
                    amount_remaining = amount_remaining;
                    amount_out = amount_out; // 0
                };
            };
        };

        let init_tick_liquidity = switch (params.to_buy) {
            case (true) { current_tick_details.liquidity_base };
            case (false) { current_tick_details.liquidity_quote };
        };
        // get the equivalent amount of token equivalent to liquidity (base or quote token ,depending on buy or sell trade)
        let init_liquidity_equivalent = PriceMath._equivalent(init_tick_liquidity, tick_price, not params.to_buy, constants);

        if (init_liquidity_equivalent <= params.amount_in) {

            amount_out := init_tick_liquidity;

            //set amount_remaining = amount_in - Init liquidity
            amount_remaining -= init_liquidity_equivalent;

            let new_tick_details = switch (params.to_buy) {
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

            ticks_details.put(params.init_tick, new_tick_details)

        } else {

            amount_out := PriceMath._equivalent(params.amount_in, tick_price, params.to_buy, constants);

            amount_remaining := 0;

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
                params.init_tick,
                new_tick,
            );

        };
        return {
            amount_out = amount_out;
            amount_remaining = amount_remaining;
        };

    };

};
