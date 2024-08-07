import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Types "./Types";

shared ({ caller }) actor class Provider(market : Principal) = this {

    let users_positions = HashMap.HashMap<Principal, Types.PositionDetails>(1, Principal.equal, Principal.hash);

    public query func userHasPosition(user : Principal) : async Bool {
        switch (users_positions.get(user)) {
            case (?_res) {
                return true;
            };
            case (_) {
                return false;
            };
        };
    };

    public query func positionExist(user : Principal, position_details : Types.PositionDetails) : async Bool {
        switch (users_positions.get(user)) {
            case (?res) {
                if (res == position_details) {

                    return true;
                } else { return false };
            };
            case (_) { return false };
        };
    };

    public shared ({ caller }) func removePosition(user : Principal) : async () {
        assert (caller == market);
        users_positions.delete(user);
    };

    public shared ({ caller }) func putPosition(user : Principal, position_details : Types.PositionDetails) : async () {
        assert (caller == market);
        // if (await userHasPosition(user)) {
        //     return ();
        // };

        users_positions.put(user, position_details)

    };

};
