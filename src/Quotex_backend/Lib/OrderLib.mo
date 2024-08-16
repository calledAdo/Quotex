import HashMap "mo:base/HashMap";
import Buffer "mo:base/Buffer";
import Types "../Interface/Types";
import BitMap "BitMap";
import C "Constants";
import Calc "Calculations";

/*

  Name :Order library
  Author :CalledDao


*/

/// Overview
///
/// Order library is utilised in creating limit orders and providing liquidity by liquidity providers,
/// orders are placed at specific ticks corresponding to specific prices
///
/// The current tick position
/// determines the liquidity in that region and hence the token that should be sent in
///
///        liquidity in  the region above the current tick(all ticks above) is all in  token0 (base token)
///        liquidity in  the region below the current tick(all ticks below) is all in token1 (quote token)

module {

    type TDS = HashMap.HashMap<Nat, Types.TickDetails>; // Ticks Details
    type MBS = HashMap.HashMap<Nat, Nat>; // Multipliers Bitmpas
    let exceeded = Calc.exceeded;

    ///
    ///_placeOrder function
    /// utilised for creating limit orders
    /// params
    ///  params consisting of .
    ///
    ///  reference_tick :the reference tick corresponding to price to place the  order
    ///
    ///   current_tick : the current tick corresponding to current price
    ///
    ///   amount_in :the amount of liquidity being added
    ///
    ///    m_multipliers_bitmaps : mapping of ticks multipliers to their corresponding  bitmaps
    ///
    ///     m_ticks_details :mapping of each tick to the tick's detail
    ///
    ///
    /// returns
    ///
    ///   order details consisting of
    ///      reference_tick : the  reference tick
    ///   tick_shares : the measure of liquidity provided at that tick
    ///

    public func _placeOrder(params : Types.OpenOrderParams, ticks_spacing : Nat) : Types.OrderDetails {

        let reference_tick = params.reference_tick;

        let (multiplier, bit_position) = Calc.mulAndBit(reference_tick, ticks_spacing);

        let ref_tick_details = switch (params.m_ticks_details.get(params.reference_tick)) {
            case (?res) { res };
            case (_) {
                {
                    liquidity_token0 = 0;
                    liquidity_token1 = 0;
                    total_shares = 0;
                };
            };
        };

        //if both base liquidity and quote liquidity is zero  means tick is  uninitialised .
        let tick_flipped : Bool = ref_tick_details.liquidity_token0 == 0 and ref_tick_details.liquidity_token1 == 0;

        var ref_bitmap : Nat = switch (params.m_multipliers_bitmaps.get(multiplier)) {
            case (?res) { res };
            case (_) { 0 };
        };

        let new_ref_bitmap : Nat = if (tick_flipped) {
            BitMap.flipBit(ref_bitmap, bit_position);
        } else { ref_bitmap };

        params.m_multipliers_bitmaps.put(multiplier, new_ref_bitmap);

        var user_tick_shares = 0;

        // above the current tick all liquidity is in token0
        let new_tick_details = switch (reference_tick > params.current_tick) {
            case (true) {
                user_tick_shares := Calc.calcShares(
                    params.amount_in,
                    ref_tick_details.total_shares,
                    ref_tick_details.liquidity_token0,
                );

                {
                    liquidity_token0 = ref_tick_details.liquidity_token0 + params.amount_in;
                    liquidity_token1 = 0;

                    total_shares = ref_tick_details.total_shares + user_tick_shares;

                };
            };
            case (false) {
                user_tick_shares := Calc.calcShares(
                    params.amount_in,
                    ref_tick_details.total_shares,
                    ref_tick_details.liquidity_token1,
                );

                {
                    liquidity_token0 = 0;
                    liquidity_token1 = ref_tick_details.liquidity_token1 + params.amount_in;
                    total_shares = ref_tick_details.total_shares + user_tick_shares;
                };
            };
        };

        params.m_ticks_details.put(reference_tick, new_tick_details);

        return {
            reference_tick = reference_tick;
            tick_shares = user_tick_shares;
        };

    };

    ///_removeOrder function
    /// utilised for removing limit orders or liquidity provided(by liquidity providers)
    ///
    /// params
    ///
    ///  params consisting of
    ///
    ///     order_details : the reference order details
    ///
    ///    m_multipliers_bitmaps : mapping of ticks multipliers to their corresponding  bitmaps
    ///
    ///    m_ticks_details :mapping of each tick to the tick's detail
    ///
    ///tick_spacing : the value between adjacent bits in a multiplier bitmap( default as 1 basis point)
    ///
    /// returns
    ///
    ///   amount0 :amount of token0 to send out
    ///
    /// amount1 : amount of token1 to send out

    public func _removeOrder(params : Types.RemoveOrderParams, ticks_spacing : Nat) : ?Types.RemoveOrderResult {

        let order_details = params.order_details;

        let reference_tick = order_details.reference_tick;

        let (multiplier, bit_position) = Calc.mulAndBit(reference_tick, ticks_spacing);

        let ref_tick_details : Types.TickDetails = switch (params.m_ticks_details.get(reference_tick)) {
            case (?res) { res };
            case (_) { return null };
        };

        //calculate the amount of the asset that the user gets with the amount of shares going in
        //calculates the amount of quote token to get for that shares amount
        //calculates the amount of base token to get for that shares amount

        let amount_token0 = Calc.calcSharesValue(
            order_details.tick_shares,
            ref_tick_details.total_shares,
            ref_tick_details.liquidity_token0,
        );

        let amount_token1 = Calc.calcSharesValue(
            order_details.tick_shares,
            ref_tick_details.total_shares,
            ref_tick_details.liquidity_token1,
        );

        let m_multipliers_bitmaps = params.m_multipliers_bitmaps;

        var ref_bitmap : Nat = switch (m_multipliers_bitmaps.get(multiplier)) {
            case (?res) { res };
            case (_) { return null };
        };
        //if shares equals total shares ,entire liquidity is being removed ;
        if (order_details.tick_shares == ref_tick_details.total_shares) {

            // flip bitmap
            ref_bitmap := BitMap.flipBit(ref_bitmap, bit_position);
            //update multiplier bitmaps
            m_multipliers_bitmaps.put(multiplier, ref_bitmap);

            // delete ticks details
            params.m_ticks_details.delete(reference_tick);

        } else {
            params.m_ticks_details.put(
                reference_tick,
                {
                    liquidity_token0 = ref_tick_details.liquidity_token0 - amount_token0;
                    liquidity_token1 = ref_tick_details.liquidity_token1 - amount_token1;
                    total_shares = ref_tick_details.total_shares - order_details.tick_shares;
                },
            )

        };

        return ?{
            amount_token0 = amount_token0;
            amount_token1 = amount_token1;
        };
    };

    /// getBestOffers function
    /// utilised to get the next best available offer for either a buy or a sell

    /// params
    /*
        in1out0 :true if buying false otherwise
        num_of_offers : number of possible offers to get (from the best downward or upward)
        current_state_tick :the current state tick
        m_ticks_details :
        ticks_spacing :
      */

    public func _getBestOffers(
        in1out0 : Bool,
        num_of_offers : Nat,
        current_state_tick : Nat,
        m_multipliers_bitmaps : MBS,
        m_ticks_details : TDS,
        ticks_spacing : Nat,
    ) : [(tick : Nat, tick_details : Types.TickDetails)] {

        let best_offers = Buffer.Buffer<(Nat, Types.TickDetails)>(num_of_offers);

        var current_tick = current_state_tick;

        let max_tick : Nat = if (in1out0) {
            current_tick + (50 * C.HUNDRED_PERCENT);
        } else {
            current_tick - (50 * C.HUNDRED_PERCENT);
        };

        while (not exceeded(max_tick, current_tick, in1out0)) {
            let (multiplier, _) = Calc.mulAndBit(current_tick, ticks_spacing);

            switch (m_ticks_details.get(current_tick)) {
                case (?res) {
                    // if it contains any liqudiity add it
                    if (res.liquidity_token0 > 0 or res.liquidity_token1 > 0) {
                        best_offers.add(current_tick, res);
                    };
                };
                case (_) {};
            };
            let current_bitmap : Nat = switch (m_multipliers_bitmaps.get(multiplier)) {
                case (?res) { res };
                case (_) {
                    0;
                };
            };
            current_tick := BitMap.next_initialized_tick(current_bitmap, current_tick, in1out0, ticks_spacing);
        };

        return Buffer.toArray(best_offers);

    };

};
