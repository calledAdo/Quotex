import DIP20 "Interface/DIP20";
import ICRC "Interface/ICRC";
import Principal "mo:base/Principal";

actor class LiquidityProvider(_admin : Principal, _clearingHouse : Principal) {
    stable let admin = _admin;
    stable let clearingHouse = _clearingHouse;

    func isAllowed(caller : Principal) : Bool {
        return (caller == admin or caller == clearingHouse);
    };

    public shared ({ caller }) func sendOutICRC(tokenPrincipal : Principal, to : Principal, amount : Nat) : async Nat {
        assert (isAllowed(caller));
        let token : ICRC.ICRC = actor (Principal.toText(tokenPrincipal));
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

    public query func getAdmin() : async Principal {
        return admin;
    };

};
