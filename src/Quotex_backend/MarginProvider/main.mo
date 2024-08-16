import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Buffer "mo:base/Buffer";
import Nat "mo:base/Nat";
import Time "mo:base/Time";
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

shared ({ caller }) actor class QuotexProvider(vault_principal : Principal) = this {
    type UserStake = Types.UserStake;
    type AssetStakingDetails = Types.AssetStakingDetails;
    type StakeSpan = Types.StakeSpan;
    type AssetDetails = Types.AssetDetails;

    stable let admin : Principal = caller;
    stable let vault : Principal = vault_principal;

    var m_assets_staking_details = HashMap.HashMap<Principal, AssetStakingDetails>(1, Principal.equal, Principal.hash);

    var m_users_stakes = HashMap.HashMap<Principal, Buffer.Buffer<UserStake>>(1, Principal.equal, Principal.hash);

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

    // ============Public functions ===================

    public shared ({ caller }) func deposit(amount : Nat, assetID : Principal) : async ?Nat {

        let asset_staking_details : AssetStakingDetails = switch (m_assets_staking_details.get(assetID)) {
            case (?res) { res };
            case (_) {
                return null;
            };
        };

        let vault_actor : Vault.Vault = actor (Principal.toText(vault));

        let valid = await vault_actor.move_asset(
            assetID,
            amount,
            ?Principal.toLedgerAccount(caller, null),
            {
                owner = vault;
                subaccount = null;
            },
        );
        assert (valid);

        let { lifetime_earnings } = await vault_actor.tokenDetails(assetID);

        let new_asset_staking_details = StakeLib.createUserStake(
            caller,
            m_users_stakes,
            asset_staking_details,
            assetID,
            lifetime_earnings,
            amount,
            #None,
        );
        m_assets_staking_details.put(assetID, new_asset_staking_details);
        ignore mint(asset_staking_details.derivID, caller, amount);
        return ?amount;

    };

    ///// withdraw function

    public shared ({ caller }) func withdraw(amount : Nat, assetID : Principal) : async () {
        let { derivID : Principal } = switch (m_assets_staking_details.get(assetID)) {
            case (?res) { res };
            case (_) {
                return ();
            };
        };

        ignore burn_send(derivID, assetID, amount, caller);
    };

    ///// stake function

    public shared ({ caller }) func lock(amount : Nat, assetID : Principal, stake_span : StakeSpan) : async {
        #Err;
        #Ok;
    } {

        // can not stake  on  #None
        assert (stake_span != #None);
        let asset_staking_details : AssetStakingDetails = switch (m_assets_staking_details.get(assetID)) {
            case (?res) { res };
            case (_) {
                return #Err;
            };
        };

        let vault_actor : Vault.Vault = actor (Principal.toText(vault));
        let valid = await vault_actor.move_asset(
            asset_staking_details.derivID,
            amount,
            ?Principal.toLedgerAccount(caller, null),
            {
                owner = vault;
                subaccount = ?Principal.toLedgerAccount(Principal.fromActor(this), null);
            },
        );
        if (not valid) {
            return #Err;
        };
        let { lifetime_earnings } = await vault_actor.tokenDetails(assetID);
        let new_asset_staking_details = StakeLib.createUserStake(
            caller,
            m_users_stakes,
            asset_staking_details,
            assetID,
            lifetime_earnings,
            amount,
            stake_span,
        );
        m_assets_staking_details.put(assetID, new_asset_staking_details);
        return #Ok;

    };

    public shared ({ caller }) func unLock(stake_id : Nat) : async {
        #Err : Text;
        #Ok;
    } {

        let user_stakes_buffer = switch (m_users_stakes.get(caller)) {
            case (?res) { res };
            case (_) { return #Err("User has no stake") };
        };

        let user_stake = user_stakes_buffer.get(stake_id);
        assert (Time.now() >= user_stake.expiry_time);

        let asset_staking_details : AssetStakingDetails = switch (m_assets_staking_details.get(user_stake.assetID)) {
            case (?res) { res };
            case (_) {
                return #Err("Not found");
            };
        };

        let vault_actor : Vault.Vault = actor (Principal.toText(vault));

        let { lifetime_earnings } = await vault_actor.tokenDetails(user_stake.assetID);

        let (user_earnings : Nat, new_asset_staking_details : AssetStakingDetails) = StakeLib.calculateUserEarnings(
            user_stake,
            asset_staking_details,
            lifetime_earnings,
        );

        ignore (
            mint(asset_staking_details.derivID, caller, user_earnings),
            vault_actor.move_asset(
                asset_staking_details.derivID,
                user_stake.amount,
                ?Principal.toLedgerAccount(Principal.fromActor(this), null),
                {
                    owner = vault;
                    subaccount = ?Principal.toLedgerAccount(caller, null);
                },
            ),
            user_stakes_buffer.remove(stake_id),
        );
        m_users_stakes.put(caller, user_stakes_buffer);
        m_assets_staking_details.put(user_stake.assetID, new_asset_staking_details);
        return #Ok;

    };

    //============== Private functions ==============

    private func mint(assetID : Principal, user : Principal, amount : Nat) : async () {

        let liquid_token_actor : ICRC.Actor = actor (Principal.toText(assetID));
        let transferArgs : ICRC.TransferArg = {
            from_subaccount = null;
            to = {
                owner = vault;
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

        let vault_actor : Vault.Vault = actor (Principal.toText(vault));

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
                owner = vault;
                subaccount = ?Principal.toLedgerAccount(user, null);
            },
        );

    };

};
