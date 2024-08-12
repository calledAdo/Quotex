import Nat "mo:base/Nat";
import HashMap "mo:base/HashMap";
import Hash "mo:base/Hash";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
module {

    public func natHash(x : Nat) : Hash.Hash {
        let text = Nat.toText(x);
        return Text.hash(text);
    };

    public type MarketDetails = {
        token0 : Principal;
        token0_decimal : Nat;
        token1 : Principal;
        token1_decimal : Nat;
        tick_spacing : Nat;
        base_price_multiplier : Nat;
        margin_provider : Principal;
    };

    public type StateDetails = {
        min_units_token0 : Nat;
        min_units_token1 : Nat;
        interest_rate : Nat;
        token0_spam_fee : Nat;
        token1_spam_fee : Nat;
        max_leverage : Nat;
    };

    public type TickDetails = {
        liquidity_token0 : Nat;
        liquidity_token1 : Nat;
        total_shares : Nat;
    };

    public type OrderDetails = {
        reference_tick : Nat;
        tick_shares : Nat;
    };

    public type OpenOrderParams = {
        reference_tick : Nat;
        current_tick : Nat;
        amount_in : Nat;
        m_multipliers_bitmaps : HashMap.HashMap<Nat, Nat>;
        m_ticks_details : HashMap.HashMap<Nat, TickDetails>;
    };

    public type RemoveOrderParams = {
        order_details : OrderDetails;
        m_multipliers_bitmaps : HashMap.HashMap<Nat, Nat>;
        m_ticks_details : HashMap.HashMap<Nat, TickDetails>;
    };

    public type RemoveOrderResult = {
        amount_token0 : Nat;
        amount_token1 : Nat;
    };

    public type SwapParams = {
        in1out0 : Bool;
        amount_in : Nat;
        init_tick : Nat;
        stopping_tick : Nat;
        m_multipliers_bitmaps : HashMap.HashMap<Nat, Nat>;
        m_ticks_details : HashMap.HashMap<Nat, TickDetails>;
    };

    public type SwapConstants = {
        token1_decimal : Nat;
        token0_decimal : Nat;
        base_price_multiplier : Nat;
        tick_spacing : Nat;
    };

    public type SwapAtTickResult = {
        amount_out : Nat;
        amount_remaining : Nat;
    };

    public type SwapResult = {
        current_tick : Nat;
        amount_out : Nat;
        amount_remaining : Nat;
    };

    public type PositionDetails = {
        debt_token : Principal;
        owner : Principal;
        is1in0out : Bool;
        debt : Nat;
        order_size : Nat;
        interest_rate : Nat;
        time : Int;
    };

    public type OpenPositionParams = {
        collateral_token : Principal;
        collateral : Nat;
        debt : Nat;
    };

};
