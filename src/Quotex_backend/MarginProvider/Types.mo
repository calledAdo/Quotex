module {

    public type AssetDetails = {
        debt : Nat;
        free_liquidity : Nat;
        lifetime_fees : Nat;
    };

    public type AssetStakingDetails = {
        liquid_asset : Principal;
        var prev_lifetime_earnings : Nat;
        var span0_details : Details;
        var span2_details : Details;
        var span6_details : Details;
        var span12_details : Details;
    };

    public type StakeSpan = { #None; #Month2; #Month6; #Year };

    public type UserStake = {
        asset : Principal;
        span : StakeSpan;
        amount : Nat;
        pre_earnings : Nat;
        expiry_time : Int;
    };

    public type Details = {
        lifetime_earnings : Nat;
        total_locked : Nat;
    };

};
