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
        base_token : Principal;
        base_token_decimal : Nat;
        flipping_amount_base : Nat;
        quote_token : Principal;
        quote_token_decimal : Nat;
        flipping_amount_quote : Nat;
        margin_provider : Principal;
        interest_rate : Nat;
        spam_penalty_fee : Nat;
        max_leverage : Nat;
    };

    public type TickDetails = {
        liquidity_base : Nat;
        liquidity_quote : Nat;
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
        min_flipping_amount : Nat;
        multiplier_bitmaps : HashMap.HashMap<Nat, Nat>;
        ticks_details : HashMap.HashMap<Nat, TickDetails>;
    };

    public type RemoveOrderParams = {
        order_details : OrderDetails;
        multiplier_bitmaps : HashMap.HashMap<Nat, Nat>;
        ticks_details : HashMap.HashMap<Nat, TickDetails>;
    };

    public type RemoveOrderResult = {
        amount_base : Nat;
        amount_quote : Nat;
    };

    public type SwapParams = {
        to_buy : Bool;
        amount_in : Nat;
        init_tick : Nat;
        stopping_tick : Nat;
        snapshot_price : Nat;
        multiplier_bitmaps : HashMap.HashMap<Nat, Nat>;
        ticks_details : HashMap.HashMap<Nat, TickDetails>;
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
        owner : Principal;
        isLong : Bool;
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
