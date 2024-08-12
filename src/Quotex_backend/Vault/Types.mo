module {
    public type AssetDetails = {
        debt : Nat;
        free_liquidity : Nat;
        lifetime_earnings : Nat;
    };

    public type PositionDetails = {
        owner : Principal;
        is1in0out : Bool;
        debt : Nat;
        order_size : Nat;
        interest_rate : Nat;
        time : Int;
    };

};
