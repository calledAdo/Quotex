import Types "../Interface/Types";
import BitMap "BitMap";
import PriceLib "PriceLib";

import Calc "Calculations";

/*

  Name :Swap library
  Author :CalledDao

*/

/// Overview
///
/// Swap library is utilised for swaps (Market orders);
/// The Market price can change during a swap by exhausting the available liquidity at a particular tick
/// but the amount in still remains
/// This would push the price to the next tick with liquidity and the swap continues there till
/// amount remaining is zero or the max tick is exceeded

module {
    type SwapParams = Types.SwapParams;
    type SwapConstants = Types.SwapConstants;
    type SwapResult = Types.SwapResult;
    type SwapAtTickResult = Types.SwapAtTickResult;

    let (exceeded, mulAndBit) = (Calc.exceeded, Calc.mulAndBit);

    /// swap function
    /// params contains

    public func swap(params : SwapParams, constants : SwapConstants) : SwapResult {

        var current_tick = params.init_tick;

        var amount_out = 0;
        var amount_remaining = params.amount_in;

        label swaploop while (not exceeded(params.stopping_tick, current_tick, params.in1out0)) {

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

            amount_out += swap_result.amount_out;

            amount_remaining := swap_result.amount_remaining;

            //break loop if amount remaining is 0
            if (amount_remaining == 0) {
                break swaploop;
            };

            //
            let (current_multiplier, _) = mulAndBit(current_tick, constants.tick_spacing);
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

    /// swap at tick
    /// returns that amount gotten and amount remaining from swapping at a partiular tick

    private func swap_at_tick(params : SwapParams, constants : SwapConstants) : SwapAtTickResult {

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
        // get the equivalent amount of token equivalent to liquidity (token0 or token1 ,depending on buy or sell trade)
        let init_liquidity_equivalent = PriceLib._equivalent(
            init_tick_liquidity,
            tick_price,
            //if buying init_liquidity equivalent would   be the amount of token1 to get for converting all the liquidity of token0 at that tick to token1 at the current tick price
            not params.in1out0,
            constants.token0_decimal,
            constants.token1_decimal,
        );

        // if liquidity at that particular tick is not enough for to cover the entire amount in
        // change all liquidity at that tick either from token0 to token1 for a buy swap or vice versa

        if (init_liquidity_equivalent <= params.amount_in) {

            amount_out := init_tick_liquidity;

            //reduce amount_remaining  by Init liquidity
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
