import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Buffer "mo:base/Buffer";
import Nat "mo:base/Nat";
import Time "mo:base/Time";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Types "../Interface/Types";
import ICRC "../Interface/ICRC";
import Vault "../Vault/main";
import StakeLib "../Lib/StakeLib";

/*
 *Name :QuotexProvider Actor
 *Author:CalledDAO
 *Github :


*/

/// Overview
///
///   Provider Actor acts as an assetID manager in Quotex allowing borrowers deposit funds and
/// allow traders utilise these funds
///
/// #Concepts
///
/// Borrowers :
///
/// Borrowers serve as the margin providers in the Quotex protocol margin trade,by depositing funds into
/// the protocol as borrowers thereby allowing traders to trade with leveraged positions.
///
/// Interests gotten by borrowers are auto re-invested therefore compounding the returns made
/// #Risks associated with Debtors
///
/// Insufficient liquidity within market to sell back collateral for debt ;
///
/// Traders defaulting

shared ({ caller }) actor class QuotexProvider(_vaultID : Principal) = this {
    type UserStake = Types.UserStake;
    type AssetStakingDetails = Types.AssetStakingDetails;
    type SpanDetails = Types.SpanDetails;
    type StakeSpan = Types.StakeSpan;
    type AssetDetails = Types.AssetDetails;

    // ===== Upgrade Vaults =========
    stable var uv_asset_staking_details : [(Principal, AssetStakingDetails)] = [];
    stable var uv_users_stakes : [(Principal, [UserStake])] = [];

    var m_assets_staking_details = HashMap.HashMap<Principal, AssetStakingDetails>(1, Principal.equal, Principal.hash);

    var m_users_stakes = HashMap.HashMap<Principal, [UserStake]>(1, Principal.equal, Principal.hash);

    stable let admin : Principal = caller;
    stable let vaultID : Principal = _vaultID;

    stable var not_paused = true;

    // ========== Query Stakes ==========

    public query func userStakes(user : Principal) : async [UserStake] {
        switch (m_users_stakes.get(user)) {
            case (?res) { res };
            case (_) { [] };
        };
    };

    public query func assetStakingDetails(assetID : Principal) : async ?{
        derivID : Principal;
        prev_lifetime_earnings : Nat;
        span0_details : SpanDetails;
        span2_details : SpanDetails;
        span6_details : SpanDetails;
        span12_details : SpanDetails;
    } {
        switch (m_assets_staking_details.get(assetID)) {
            case (?res) {
                return ?{
                    derivID = res.derivID;
                    prev_lifetime_earnings = res.prev_lifetime_earnings;
                    span0_details = res.span0_details;
                    span2_details = res.span2_details;
                    span6_details = res.span6_details;
                    span12_details = res.span12_details;
                };
            };
            case (_) { null };
        };
    };

    // ============Public functions ===================

    public shared ({ caller }) func deposit(amount : Nat, assetID : Principal) : async ?Nat {
        assert (not_paused);
        let asset_staking_details : AssetStakingDetails = switch (m_assets_staking_details.get(assetID)) {
            case (?res) { res };
            case (_) {
                return null;
            };
        };

        let vault_actor : Vault.Vault = actor (Principal.toText(vaultID));

        let valid = await vault_actor.move_asset(
            assetID,
            amount,
            ?Principal.toLedgerAccount(caller, null),
            {
                owner = vaultID;
                subaccount = null;
            },
        );
        assert (valid);

        let { lifetime_earnings } = await vault_actor.tokenDetails(assetID);

        let (new_stake, new_asset_staking_details) = StakeLib.createStake(
            asset_staking_details,
            assetID,
            lifetime_earnings,
            amount,
            #None,
        );

        var user_stakes_updated : [UserStake] = switch (m_users_stakes.get(caller)) {
            case (?res) { Array.append(res, [new_stake]) };
            case (_) { [new_stake] };
        };
        m_users_stakes.put(caller, user_stakes_updated);
        m_assets_staking_details.put(assetID, new_asset_staking_details);
        ignore mint(asset_staking_details.derivID, caller, amount);
        return ?amount;

    };

    /// withdraw function

    public shared ({ caller }) func withdraw(amount : Nat, assetID : Principal) : async () {
        assert (not_paused);
        let { derivID : Principal } = switch (m_assets_staking_details.get(assetID)) {
            case (?res) { res };
            case (_) {
                return ();
            };
        };

        ignore burn_send(derivID, assetID, amount, caller);
    };

    /// stake function

    public shared ({ caller }) func lock(amount : Nat, assetID : Principal, stake_span : StakeSpan) : async {
        #Err;
        #Ok;
    } {
        assert (not_paused);
        // can not stake  on  #None
        assert (stake_span != #None);
        let asset_staking_details : AssetStakingDetails = switch (m_assets_staking_details.get(assetID)) {
            case (?res) { res };
            case (_) {
                return #Err;
            };
        };

        let vault_actor : Vault.Vault = actor (Principal.toText(vaultID));
        let valid = await vault_actor.move_asset(
            asset_staking_details.derivID,
            amount,
            ?Principal.toLedgerAccount(caller, null),
            {
                owner = vaultID;
                subaccount = ?Principal.toLedgerAccount(Principal.fromActor(this), null);
            },
        );
        if (not valid) {
            return #Err;
        };

        let { lifetime_earnings } = await vault_actor.tokenDetails(assetID);
        let (new_stake, new_asset_staking_details) = StakeLib.createStake(
            asset_staking_details,
            assetID,
            lifetime_earnings,
            amount,
            stake_span,
        );
        var user_stakes_updated : [UserStake] = switch (m_users_stakes.get(caller)) {
            case (?res) { Array.append(res, [new_stake]) };
            case (_) { [new_stake] };
        };
        m_users_stakes.put(caller, user_stakes_updated);
        m_assets_staking_details.put(assetID, new_asset_staking_details);
        return #Ok;

    };

    /// unLock functions

    public shared ({ caller }) func unLock(stake_id : Nat) : async {
        #Err : Text;
        #Ok;
    } {
        assert (not_paused);

        let user_stakes : Buffer.Buffer<UserStake> = switch (m_users_stakes.get(caller)) {
            case (?res) { Buffer.fromArray(res) };
            case (_) { return #Err("User has no stake") };
        };

        let stake = user_stakes.get(stake_id);
        assert (Time.now() >= stake.expiry_time);

        let asset_staking_details : AssetStakingDetails = switch (m_assets_staking_details.get(stake.assetID)) {
            case (?res) { res };
            case (_) {
                return #Err("Not found");
            };
        };

        let vault_actor : Vault.Vault = actor (Principal.toText(vaultID));

        let { lifetime_earnings } = await vault_actor.tokenDetails(stake.assetID);

        let (user_earnings : Nat, new_asset_staking_details : AssetStakingDetails) = StakeLib.calculateUserEarnings(
            stake,
            asset_staking_details,
            lifetime_earnings,
        );

        ignore (
            mint(asset_staking_details.derivID, caller, user_earnings),
            vault_actor.move_asset(
                asset_staking_details.derivID,
                stake.amount,
                ?Principal.toLedgerAccount(Principal.fromActor(this), null),
                {
                    owner = vaultID;
                    subaccount = ?Principal.toLedgerAccount(caller, null);
                },
            ),
            user_stakes.remove(stake_id),
        );
        m_users_stakes.put(caller, Buffer.toArray(user_stakes));
        m_assets_staking_details.put(stake.assetID, new_asset_staking_details);
        return #Ok;

    };

    //====== Admin functions =======

    public shared ({ caller }) func addAsset(assetID : Principal, derivID : Principal) : async Bool {
        assert (caller == admin);
        switch (m_assets_staking_details.get(assetID)) {
            case (?_) { return false };
            case (_) {
                let init_span_details = {
                    lifetime_earnings = 0;
                    total_locked = 0;
                };
                let asset_staking_details : AssetStakingDetails = {
                    derivID = derivID;
                    var prev_lifetime_earnings = 0;
                    var span0_details = init_span_details;
                    var span2_details = init_span_details;
                    var span6_details = init_span_details;
                    var span12_details = init_span_details;
                };
                m_assets_staking_details.put(assetID, asset_staking_details);
                return true;
            };
        };

    };

    public shared ({ caller }) func pre_upgrade() : () {
        assert (caller == admin);
        uv_asset_staking_details := Iter.toArray(m_assets_staking_details.entries());
        uv_users_stakes := Iter.toArray(m_users_stakes.entries());
        not_paused := false;
    };

    public shared ({ caller }) func post_upgrade() : () {
        assert (caller == admin);
        m_assets_staking_details := HashMap.fromIter<Principal, AssetStakingDetails>(
            uv_asset_staking_details.vals(),
            uv_asset_staking_details.size(),
            Principal.equal,
            Principal.hash,
        );
        m_users_stakes := HashMap.fromIter<Principal, [UserStake]>(
            uv_users_stakes.vals(),
            uv_users_stakes.size(),
            Principal.equal,
            Principal.hash,
        );
        uv_asset_staking_details := [];
        uv_users_stakes := [];
        not_paused := true;
    };

    //============== Private functions ==============

    private func mint(assetID : Principal, user : Principal, amount : Nat) : async () {

        let liquid_token_actor : ICRC.Actor = actor (Principal.toText(assetID));
        let transferArgs : ICRC.TransferArg = {
            from_subaccount = null;
            to = {
                owner = vaultID;
                subaccount = ?Principal.toLedgerAccount(user, null);
            };
            amount = amount;
            fee = null;
            memo = null;
            created_at_time = null;
        };
        ignore liquid_token_actor.icrc1_transfer(transferArgs);
    };

    private func burn_send(assetBurnID : Principal, assetSendID : Principal, amount : Nat, user : Principal) : async () {

        let vault_actor : Vault.Vault = actor (Principal.toText(vaultID));

        let { free_liquidity } = await vault_actor.tokenDetails(assetSendID);
        assert (amount >= free_liquidity);

        // burn
        let valid = await vault_actor.move_asset(
            assetBurnID,
            amount,
            ?Principal.toLedgerAccount(user, null),
            // to null account
            {
                owner = Principal.fromActor(this);
                subaccount = null;
            },
        );
        assert (valid);

        ignore vault_actor.move_asset(
            assetSendID,
            amount,
            null,
            {
                owner = vaultID;
                subaccount = ?Principal.toLedgerAccount(user, null);
            },
        );

    };

};
