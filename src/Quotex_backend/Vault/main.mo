import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Nat "mo:base/Nat";
import ICRC "../Interface/ICRC";
import Types "Types"

shared ({ caller }) actor class Vault(provider : Principal) = this {

    type PositionDetails = Types.PositionDetails;

    type UsersPositionMap = HashMap.HashMap<Principal, PositionDetails>;
    type AssetDetails = Types.AssetDetails;

    let m_assets_details = HashMap.HashMap<Principal, AssetDetails>(1, Principal.equal, Principal.hash);

    let m_markets_positions = HashMap.HashMap<Principal, UsersPositionMap>(1, Principal.equal, Principal.hash);

    let approved = HashMap.HashMap<Principal, Bool>(1, Principal.equal, Principal.hash);

    stable let admin : Principal = caller;

    stable let margin_provider : Principal = provider;

    public query func tokenDetails(asset : Principal) : async AssetDetails {
        //adjust token details accordingly
        switch (m_assets_details.get(asset)) {
            case (?details) {
                details;
            };
            case (_) {
                return {
                    debt = 0;
                    free_liquidity = 0;
                    lifetime_earnings = 0;
                };
            };
        };
    };
    /// userHasPosition function
    /// query function that checks user has any new_position in that particular token
    /// returns true if so or false otherwise

    public query func userHasPosition(user : Principal, market : Principal) : async Bool {
        switch (m_markets_positions.get(market)) {
            case (?res) {
                switch (res.get(user)) {
                    case (?res) { return true };
                    case (_) { return false };
                };
            };
            case (_) {
                return false;
            };
        };
    };

    /// positionExist function
    // Checks if a particular users has  a position with position_details in the specific market

    public query func positionExist(user : Principal, market : Principal, position_details : PositionDetails) : async Bool {
        switch (m_markets_positions.get(market)) {
            case (?res) {
                switch (res.get(user)) {
                    case (?res) {
                        if (res == position_details) {
                            return true;
                        };
                        return false;
                    };
                    case (_) { return false };
                };

            };
            case (_) { return false };
        };
    };

    /// updatePosition function

    public shared ({ caller }) func updatePosition(
        user : Principal,
        market : Principal,
        token : Principal,
        new_position : ?PositionDetails,
        amount_received : Nat,
        interest_received : Nat,
    ) : async () {
        assert (_approved(caller));
        // get all positions for that particular market
        let m_users_position : UsersPositionMap = switch (m_markets_positions.get(market)) {
            case (?res) { res };
            case (_) {
                HashMap.HashMap<Principal, PositionDetails>(1, Principal.equal, Principal.hash);
            };
        };

        // checks if position is being put in or removed
        switch (new_position) {
            case (?new_position) {

                //adjust token details accordingly
                switch (m_assets_details.get(token)) {
                    case (?details) {
                        let new_token_details : AssetDetails = {
                            debt = details.debt + new_position.debt - amount_received;
                            free_liquidity = details.free_liquidity + amount_received - new_position.debt;
                            lifetime_earnings = details.lifetime_earnings;
                        };
                        m_assets_details.put(token, new_token_details);

                    };
                    case (_) { return () };
                };
                //puts the psosition
                m_users_position.put(user, new_position);

            };
            case (_) {

                switch (m_assets_details.get(token)) {
                    case (?details) {
                        let new_token_details : AssetDetails = {
                            debt = details.debt - amount_received;
                            free_liquidity = details.free_liquidity + amount_received + interest_received;
                            lifetime_earnings = details.lifetime_earnings + interest_received;
                        };
                        m_assets_details.put(token, new_token_details);
                    };
                    case (_) {};
                };
                //if null its deleting
                m_users_position.delete(user);
            };
        };
        m_markets_positions.put(market, m_users_position);
    };

    ///_move_asset function
    /// @dev moves asset from one account to another  and await the result
    ///returns true if transaction was successful or false otherwise .

    public shared ({ caller }) func move_asset(asset_principal : Principal, amount : Nat, from_sub : ?Blob, account : ICRC.Account) : async Bool {
        assert (_approved(caller) or from_sub == ?Principal.toBlob(caller));
        if (amount == 0) {
            return true;
        };

        // only updates asset_details when
        // assets is being deposited
        // debt is being removed
        // case (1)subaccount is margin provider in the case of a withdrawal
        // case (2)account subaccount is margin proovider in the case of a deposit
        if (

            from_sub == ?Principal.toBlob(margin_provider) or
            account.subaccount == ?Principal.toBlob(margin_provider)

        ) {
            let out = from_sub == ?Principal.toBlob(margin_provider);
            switch (_provider_move_asset(amount, asset_principal, out)) {
                case (false) { return false };
                case (true) {};
            };
        };

        let asset : ICRC.Actor = actor (Principal.toText(asset_principal));

        let transferArgs : ICRC.TransferArg = {
            from_subaccount = from_sub;
            to = account;
            amount = amount;
            fee = null;
            memo = null;
            created_at_time = null;
        };

        switch (await asset.icrc1_transfer(transferArgs)) {
            case (#Ok(_)) { return true };
            case (#Err(_)) { return false };
        };

    };

    ///////////

    public shared ({ caller }) func unchecked_move_asset(asset_principal : Principal, amount : Nat, from_sub : ?Blob, account : ICRC.Account) : async () {
        assert (_approved(caller) or from_sub == ?Principal.toBlob(caller));
        if (amount == 0) {
            return ();
        };

        // only updates asset_details when
        // assets is being deposited
        // asset is being withdrawn
        // case (1)subaccount is margin provider in the case of a withdrawal
        // case (2)account subaccount is margin proovider in the case of a deposit
        if (
            from_sub == ?Principal.toBlob(margin_provider) or
            account.subaccount == ?Principal.toBlob(margin_provider)
        ) {
            let out = from_sub == ?Principal.toBlob(margin_provider);
            switch (_provider_move_asset(amount, asset_principal, out)) {
                case (false) { return () };
                case (true) {};
            };
        };

        let asset : ICRC.Actor = actor (Principal.toText(asset_principal));

        let transferArgs : ICRC.TransferArg = {
            from_subaccount = from_sub;
            to = account;
            amount = amount;
            fee = null;
            memo = null;
            created_at_time = null;
        };

        ignore asset.icrc1_transfer(transferArgs);

    };

    //========== Admin functions ==========

    public shared ({ caller }) func approvePrincipal(principal : Principal) : async () {
        assert (caller == admin);
        approved.put(principal, true);
    };

    // ============  Private functions ===========

    private func _provider_move_asset(amount : Nat, asset : Principal, out : Bool) : Bool {
        let token_details : AssetDetails = switch (m_assets_details.get(asset)) {
            case (?res) { res };
            case (_) { return false };
        };
        if (amount > token_details.free_liquidity) {
            return false;
        };

        let free_liquidity : Nat = if (out) {
            token_details.free_liquidity - amount;
        } else {
            token_details.free_liquidity + amount;
        };
        let new_token_details : AssetDetails = {
            debt = token_details.debt;
            free_liquidity = free_liquidity;
            lifetime_earnings = token_details.lifetime_earnings;
        };
        m_assets_details.put(asset, new_token_details);
        return true;
    };

    private func _approved(identifier : Principal) : Bool {
        if (identifier == admin or identifier == margin_provider) {
            return true;
        };
        switch (approved.get(identifier)) {
            case (?_) { true };
            case (_) { false };
        };
    };
};