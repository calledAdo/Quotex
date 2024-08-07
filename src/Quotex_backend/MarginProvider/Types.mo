import Principal "mo:base/Principal";

module {

    public type PositionDetails = {
        owner : Principal;
        debt : Nat;
        order_size : Nat;
        interest_rate : Nat;
        time : Int;
    };

    public type OpenPositionParams = {
        collateral : Nat;
        debt : Nat;

    };

    public type ClosePositionParams = {

    };

};
