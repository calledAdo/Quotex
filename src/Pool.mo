import DIP20 "Interface/DIP20";
import ICRC "Interface/ICRC";
import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Error "mo:base/Error";

actor class Pool(admin : Principal, clearingHouse : Principal) {
    type Token = ICRC.Token;

    type TokenDetails = {
        is_allowed : Bool;
        max_debt : Nat64;
        min_collateral : Nat64;
        margin_fee : Nat64;
    };

    stable let init = false;

    func isAllowed(caller : Principal) : Bool {
        return (caller == admin or caller == clearingHouse);
    };

    let tokendetails = HashMap.HashMap<Principal, TokenDetails>(1, Principal.equal, Principal.hash);
    let isliquidator = HashMap.HashMap<Principal, Bool>(1, Principal.equal, Principal.hash);

    public query func getTokenDetails(_token : Principal) : async TokenDetails {
        let _tokendetails = switch (tokendetails.get(_token)) {
            case (?res) { res };
            case (_) { throw Error.reject("") };
        };
    };

    public shared ({ caller }) func setOperator(operator : Principal, status : Bool) : async () {
        isliquidator.put(operator, status);
    };
    public shared ({ caller }) func isLiquidator(operator : Principal) : async Bool {
        let status = switch (isliquidator.get(operator)) {
            case (?res) { res };
            case (_) { false };
        };
    };
    public shared ({ caller }) func setToken(tokenPrincipal : Principal, status : TokenDetails) : async () {
        tokendetails.put(tokenPrincipal, status);
    };

    public shared ({ caller }) func sendOutDIP20(tokenPrincipal : Principal, to : Principal, amount : Nat) : async Nat {
        assert (isAllowed(caller));
        let token : DIP20.DIP20 = actor (Principal.toText(tokenPrincipal));
        let fee = await token.getTokenFee();
        let tx = await token.transfer(to, amount - fee);
        let isValid = switch (tx) {
            case (#Ok(num)) { true };
            case (#Err(err)) { false };
        };
        assert (isValid);
        return amount -fee;
    };

    public shared ({ caller }) func sendOutICRC(tokenPrincipal : Principal, to : Principal, amount : Nat) : async Nat {
        assert (isAllowed(caller));
        let token : Token = actor (Principal.toText(tokenPrincipal));
        let fee = await token.icrc1_fee();
        let sending_amount : Nat = amount - fee;
        let tx = await token.icrc1_transfer({
            from_subaccount = null;
            to = {
                owner = to;
                subaccount = null;
            };
            amount = sending_amount;
            fee = ?fee;
            memo = null;
            created_at_time = null;

        });

        let isValid = switch (tx) {
            case (#Ok(num)) { true };
            case (#Err(err)) { false };
        };
        assert (isValid);
        return sending_amount;

    };

};
