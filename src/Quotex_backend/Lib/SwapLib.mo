import Types "../Market/Types";
import BitMap "BitMap";
import PriceLib "PriceLib";

import F "Calculations";

module {

    /// swap function

    public func swap(params : Types.SwapParams, constants : Types.SwapConstants) : Types.SwapResult {

        var current_tick = params.init_tick;

        var amount_out = 0;
        var amount_remaining = params.amount_in;

        label swaploop while (not F.exceeded(params.stopping_tick, current_tick, params.in1out0)) {

            // create  new swap parameters  for every new iteration of the loop
            let new_params = {
                in1out0 = params.in1out0;
                amount_in = amount_remaining;
                init_tick = current_tick;
                stopping_tick = params.stopping_tick;
                m_multipliers_bitmaps = params.m_multipliers_bitmaps;
                m_ticks_details = params.m_ticks_details;
            };

            //
            let swap_result = swap_at_tick(new_params, constants);

            // m_multipliers_bitmaps := swap_result.new_bitmaps;

            //
            amount_out += swap_result.amount_out;

            amount_remaining := swap_result.amount_remaining;

            //break loop
            if (amount_remaining == 0) {
                break swaploop;
            };

            //
            let (current_multiplier, _) = F.mulAndBit(current_tick, constants.tick_spacing);
            //m_multipliers_bitmaps for current multiplier ;
            let current_bitmap : Nat = switch (params.m_multipliers_bitmaps.get(current_multiplier)) {
                case (?res) { res };
                case (_) {
                    0;
                };
            };

            current_tick := BitMap.next_initialized_tick(
                current_bitmap,
                current_tick,
                params.in1out0,
                constants.tick_spacing,
            );

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

        //calculate the current price
        let tick_price = PriceLib.tick_to_price(params.init_tick, constants.base_price_multiplier);

        let current_tick_details = switch (params.m_ticks_details.get(params.init_tick)) {
            case (?res) { res };
            case (_) {
                // if current ticks details can not be found return default
                return {
                    amount_remaining = amount_remaining;
                    amount_out = amount_out; // 0
                };
            };
        };

        let init_tick_liquidity = switch (params.in1out0) {
            case (true) { current_tick_details.liquidity_token0 };
            case (false) { current_tick_details.liquidity_token1 };
        };
        // get the equivalent amount of token equivalent to liquidity (base or quote token ,depending on buy or sell trade)
        let init_liquidity_equivalent = PriceLib._equivalent(
            init_tick_liquidity,
            tick_price,
            not params.in1out0,
            constants.token0_decimal,
            constants.token1_decimal,
        );

        if (init_liquidity_equivalent <= params.amount_in) {

            amount_out := init_tick_liquidity;

            //set amount_remaining = amount_in - Init liquidity
            amount_remaining -= init_liquidity_equivalent;

            let new_tick_details = switch (params.in1out0) {
                case (true) {
                    {
                        liquidity_token0 = 0;
                        liquidity_token1 = current_tick_details.liquidity_token1 + init_liquidity_equivalent;
                        total_shares = current_tick_details.total_shares;
                    };
                };
                case (false) {
                    {
                        liquidity_token0 = current_tick_details.liquidity_token0 + init_liquidity_equivalent;
                        liquidity_token1 = 0;
                        total_shares = current_tick_details.total_shares;
                    };
                };
            };

            params.m_ticks_details.put(params.init_tick, new_tick_details)

        } else {

            amount_out := PriceLib._equivalent(
                params.amount_in,
                tick_price,
                params.in1out0,
                constants.token0_decimal,
                constants.token1_decimal,
            );

            amount_remaining := 0;

            let new_tick = switch (params.in1out0) {
                case (true) {
                    {
                        liquidity_token0 : Nat = init_tick_liquidity - amount_out;
                        liquidity_token1 = current_tick_details.liquidity_token1 + params.amount_in;
                        total_shares = current_tick_details.total_shares;
                    };
                };
                case (false) {
                    {
                        liquidity_token0 = current_tick_details.liquidity_token0 + params.amount_in;
                        liquidity_token1 : Nat = init_tick_liquidity - amount_out;
                        total_shares = current_tick_details.total_shares;
                    };
                };
            };
            params.m_ticks_details.put(
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
