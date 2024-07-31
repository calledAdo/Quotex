import Nat "mo:base/Nat";
import HashMap "mo:base/HashMap";
import Nat64 "mo:base/Nat64";
import Hash "mo:base/Hash";
import Text "mo:base/Text";
module {

    public func natHash(x : Nat) : Hash.Hash {
        let text = Nat.toText(x);
        return Text.hash(text);
    };

    public type TickDetails = {
        liquidity_base : Nat;
        liquidity_quote : Nat;
        total_shares : Nat;
    };

    public type OrderDetails = {
        reference_tick : Nat64;
        tick_shares : Nat;
    };

    public type OpenOrderParams = {
        reference_tick : Nat64;
        current_tick : Nat64;
        amount_in : Nat;
        min_flipping_amount : Nat;
        snapshot_price : Nat64;
        multiplier_bitmaps : HashMap.HashMap<Nat, Nat>;
        ticks_details : HashMap.HashMap<Nat, TickDetails>;
    };

    public type OpenOrderResult = {
        order_details : OrderDetails;
        tick_flipped : Bool;
        new_multiplier_bitmaps : HashMap.HashMap<Nat, Nat>;
        new_ticks_details : HashMap.HashMap<Nat, TickDetails>;
    };

    public type CloseOrderParams = {
        order_details : OrderDetails;
        multiplier_bitmaps : HashMap.HashMap<Nat, Nat>;
        ticks_details : HashMap.HashMap<Nat, TickDetails>;
    };

    public type CloseOrderResult = {
        amount_base : Nat;
        amount_quote : Nat;
        multiplier_bitmaps : HashMap.HashMap<Nat, Nat>;
        ticks_details : HashMap.HashMap<Nat, TickDetails>;
    };

    public type SwapParams = {
        to_buy : Bool;
        amount_in : Nat;
        init_tick : Nat64;
        max_tick : Nat64;
        snapshot_price : Nat64;
        multiplier_bitmaps : HashMap.HashMap<Nat, Nat>;
        ticks_details : HashMap.HashMap<Nat, TickDetails>;
    };

    public type SwapAtTickResult = {
        amount_out : Nat;
        amount_remaining : Nat;
        new_ticks_details : HashMap.HashMap<Nat, TickDetails>;
    };

    public type SwapResult = {
        current_tick : Nat64;
        amount_out : Nat;
        amount_remaining : Nat;
        new_ticks_details : HashMap.HashMap<Nat, TickDetails>;
    };

};
