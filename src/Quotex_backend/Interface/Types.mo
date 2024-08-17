import Nat "mo:base/Nat";
import HashMap "mo:base/HashMap";
import Hash "mo:base/Hash";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
module {

    public type MarketInspect = {
        arg : Blob;
        caller : Principal;
        msg : {
            #pre_upgrade1 : () -> ();
            #pre_upgrade2 : () -> ();
            #post_upgrade1 : () -> ();
            #post_upgrade2 : () -> ();
            #changeLiquidatorStatus : () -> (Principal, Bool);
            #closePosition : () -> Principal;
            #getBestOffers : () -> ();
            #getUserOrders : () -> Principal;
            #openPosition : () -> (Nat, Nat, Bool, ?Nat);
            #placeOrder : () -> (Nat, Nat);
            #removeOrder : () -> Nat;
            #swap : () -> (Nat, ?Nat, Bool);
            #swapResult : () -> (Nat, Bool);
            #tickDetails : () -> Nat;
            #updateState : () -> (?StateDetails, ?Nat);
        };
    };

    public func natHash(x : Nat) : Hash.Hash {
        let text = Nat.toText(x);
        return Text.hash(text);
    };

    public type MarketDetails = {
        token0 : Principal;
        token0_decimal : Nat;
        token0_fee : Nat;
        token1 : Principal;
        token1_decimal : Nat;
        token1_fee : Nat;
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
        max_leverageX10 : Nat;
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

    public type AssetDetails = {
        debt : Nat;
        free_liquidity : Nat;
        lifetime_earnings : Nat;
    };

    public type AssetStakingDetails = {
        //derivatiev asset
        derivID : Principal;
        var prev_lifetime_earnings : Nat;
        var span0_details : SpanDetails;
        var span2_details : SpanDetails;
        var span6_details : SpanDetails;
        var span12_details : SpanDetails;
    };

    public type StakeSpan = { #None; #Month2; #Month6; #Year };

    public type UserStake = {
        assetID : Principal;
        span : StakeSpan;
        amount : Nat;
        pre_earnings : Nat;
        expiry_time : Int;
    };

    public type SpanDetails = {
        lifetime_earnings : Nat;
        total_locked : Nat;
    };

};
