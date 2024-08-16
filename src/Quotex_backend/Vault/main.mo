import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Nat "mo:base/Nat";
import ICRC "../Interface/ICRC";
import Types "../Interface/Types"

/*
  Name :Vault Actor
  Author :CalledDAO


*/

shared ({ caller }) actor class Vault(provider : Principal) = this {

    type PositionDetails = Types.PositionDetails;

    type UsersPositionMap = HashMap.HashMap<Principal, PositionDetails>;
    type AssetDetails = Types.AssetDetails;

    let m_assets_details = HashMap.HashMap<Principal, AssetDetails>(1, Principal.equal, Principal.hash);

    let m_markets_positions = HashMap.HashMap<Principal, UsersPositionMap>(1, Principal.equal, Principal.hash);

    let approved = HashMap.HashMap<Principal, Bool>(1, Principal.equal, Principal.hash);

    stable let admin : Principal = caller;

    var update = 0;

    stable let margin_provider : Principal = provider;

    // ============= Query functions =========

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

    public query func userMarketPosition(user : Principal, market : Principal) : async ?PositionDetails {
        switch (m_markets_positions.get(market)) {
            case (?res) {

                return res.get(user);
            };
            case (_) { return null };
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

                //adjust token details accordingly //
                switch (m_assets_details.get(token)) {
                    case (?details) {
                        let new_token_details : AssetDetails = {
                            debt = details.debt + new_position.debt - amount_received;
                            free_liquidity = details.free_liquidity + amount_received - new_position.debt;
                            lifetime_earnings = details.lifetime_earnings + interest_received;
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

    ///
    public shared ({ caller }) func enoughLiquidity(assetID : Principal, amount : Nat) : async Bool {
        update += 1;
        switch (m_assets_details.get(assetID)) {
            case (?details) {
                if (details.free_liquidity >= amount) {
                    return true;
                };
                return false;
            };
            case (_) { return false };
        };
    };

    ///_move_asset function
    ///
    /// @dev moves asset from one account to another  and await the result .
    ///
    ///returns true if transaction was successful or false otherwise .

    public shared ({ caller }) func move_asset(asset_principal : Principal, amount : Nat, from_sub : ?Blob, account : ICRC.Account) : async Bool {
        assert (_approved(caller) or from_sub == ?Principal.toLedgerAccount(caller, null));
        if (amount == 0) {
            return true;
        };

        // only updates asset_details when caller is marginProvider and
        // case (1)subaccount is margin provider in the case of a withdrawal
        // case (2)account subaccount is margin proovider in the case of a deposit
        if (
            caller == margin_provider and (
                from_sub == null or
                account.subaccount == null
            )

        ) {
            let out = from_sub == null;
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
            case (#Err(_)) {
                return false;
            };
        };

    };

    ///_move_asset function
    ///
    /// @dev moves asset from one account to another  and await the result .
    ///
    ///returns true if transaction was successful or false otherwise .

    public shared ({ caller }) func unchecked_move_asset(asset_principal : Principal, amount : Nat, from_sub : ?Blob, account : ICRC.Account) : async () {
        assert (_approved(caller) or from_sub == ?Principal.toLedgerAccount(caller, null));
        if (amount == 0) {
            return ();
        };

        // only updates asset_details caller is margiin provider and
        // case (1)subaccount is margin provider in the case of a withdrawal
        // case (2)account subaccount is margin proovider in the case of a deposit

        if (
            caller == margin_provider and (
                from_sub == ?Principal.toLedgerAccount(margin_provider, null) or
                account.subaccount == ?Principal.toLedgerAccount(margin_provider, null)
            )
        ) {
            let out = from_sub == ?Principal.toLedgerAccount(margin_provider, null);
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
            case (_) {
                {
                    debt = 0;
                    free_liquidity = 0;
                    lifetime_earnings = 0;
                };
            };
        };
        if (out and amount > token_details.free_liquidity) {
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
