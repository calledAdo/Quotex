import Text "mo:base/Text";

module {

    type AssetClass = { #Cryptocurrency; #FiatCurrency };

    public type Asset = {
        id : Principal;
        symbol : Text;
        class_ : AssetClass;
    };

    public type TokenDetails = {
        isAllowed : Bool;
        minLeverage : Nat;
        maxDebt : Nat;
        marginFee : Nat;
    };

    public type Range = {
        min : Nat64;
        max : Nat64;
    };
    public type Quote = {
        offer : Nat64;
        quote_asset : Asset;
        range : Range;
        time_limit : Int;
        liq_provider_id : Principal;

    };

    public type OpenPositionParams = {
        is_long : Bool;
        debt : Nat64;
        quote_id : Nat;
        pool_id : Nat;
        base_asset : Asset;
        collateral_amount : Nat64;
    };

    public type Position = {
        asset_In : Asset;
        asset_out : Asset;
        isLong : Bool;
        amount_in : Nat;
        debt_pool : Principal;
        debt : Nat;
        marginFee : Nat;
        timestamp : Nat;
    };
};
