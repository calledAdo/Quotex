import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";
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

    stable var upgrade_asset_details : [(Principal, AssetDetails)] = [];

    var m_assets_details = HashMap.HashMap<Principal, AssetDetails>(1, Principal.equal, Principal.hash);

    stable var upgraded_approvals : [(Principal, Bool)] = [];

    var m_approval = HashMap.HashMap<Principal, Bool>(1, Principal.equal, Principal.hash);

    stable let admin : Principal = caller;

    stable var not_paused = true;

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

    /// updatedPosition function

    public shared ({ caller }) func updatedPosition(
        token : Principal,
        new_debt : ?Nat,
        amount_received : Nat,
        interest_received : Nat,
    ) : async () {
        assert (_approved(caller) and not_paused);

        // checks if position is being put in or removed
        switch (new_debt) {
            case (?new_debt) {

                //adjust token details accordingly //
                switch (m_assets_details.get(token)) {
                    case (?details) {
                        let new_token_details : AssetDetails = {
                            debt = details.debt + new_debt - amount_received;
                            free_liquidity = details.free_liquidity + amount_received - new_debt;
                            lifetime_earnings = details.lifetime_earnings + interest_received;
                        };
                        m_assets_details.put(token, new_token_details);

                    };
                    case (_) { return () };
                };

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
            };
        };

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
        assert (not_paused);
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
                account == {
                    owner = Principal.fromActor(this);
                    subaccount = null;
                }
            )

        ) {
            let out = from_sub == null;
            switch (_update_asset_details(amount, asset_principal, out)) {
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

    //========== Admin functions ==========

    public shared ({ caller }) func approvePrincipal(principal : Principal, status : Bool) : async () {
        assert (caller == admin and not_paused);
        m_approval.put(principal, status);
    };
    // ========== Updating functions ===========

    /// pre upgrade function

    public shared ({ caller }) func pre_upgrade() : () {
        assert (caller == admin);
        upgrade_asset_details := Iter.toArray(m_assets_details.entries());
        upgraded_approvals := Iter.toArray(m_approval.entries());
        not_paused := false;
    };

    /// post upgrade fucntion

    public shared ({ caller }) func post_upgrade() : () {
        assert (caller == admin);
        m_assets_details := HashMap.fromIter<Principal, AssetDetails>(
            upgrade_asset_details.vals(),
            upgrade_asset_details.size(),
            Principal.equal,
            Principal.hash,
        );
        upgrade_asset_details := [];
        m_approval := HashMap.fromIter<Principal, Bool>(
            upgraded_approvals.vals(),
            upgraded_approvals.size(),
            Principal.equal,
            Principal.hash,
        );
        not_paused := true;

    };

    // ============  Private functions ===========

    private func _update_asset_details(amount : Nat, asset : Principal, out : Bool) : Bool {
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
        switch (m_approval.get(identifier)) {
            case (?_) { true };
            case (_) { false };
        };
    };
};
