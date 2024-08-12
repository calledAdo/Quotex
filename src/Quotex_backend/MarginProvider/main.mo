import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Buffer "mo:base/Buffer";
import Nat "mo:base/Nat";
import Time "mo:base/Time";
import Types "Types";
import ICRC "../Interface/ICRC";
import Vault "../Vault/main";
import StakeLib "../Lib/StakeLib";

/*
 *Name :QuotexProvider Actor
 *Author:CalledDAO
 *Github :


*/

// Overview

//   Provider Actor acts as an asset manager in Quotex allowing borrowers deposit funds and
/// allow traders utilise these funds

/// #Concepts

/// Debtors :
///Debtors serve as the margin providers in the Quotex protocol margin trade,by depositing funds into
/// the protocol as borrowers thereby allowing traders to trade with leveraged positions.

/// #Risks associated with Debtors

/// Insufficient liquidity within market to sell back collateral for debt ;
/// Traders defaulting

shared ({ caller }) actor class QuotexProvider(vault_principal : Principal) = this {
    type UserStake = Types.UserStake;
    type AssetStakingDetails = Types.AssetStakingDetails;
    type StakeSpan = Types.StakeSpan;
    type AssetDetails = Types.AssetDetails;

    // stable let admin : Principal = caller;
    stable let vault : Principal = vault_principal;

    var m_assets_staking_details = HashMap.HashMap<Principal, AssetStakingDetails>(1, Principal.equal, Principal.hash);

    var m_users_stakes = HashMap.HashMap<Principal, Buffer.Buffer<UserStake>>(1, Principal.equal, Principal.hash);

    /// func deposit

    //////////
    public shared ({ caller }) func deposit(amount : Nat, asset : Principal) : async () {

        let vault_actor : Vault.Vault = actor (Principal.toText(vault));

        let valid = await vault_actor.move_asset(
            asset,
            amount,
            ?Principal.toBlob(caller),
            {
                owner = vault;
                subaccount = ?Principal.toBlob(Principal.fromActor(this));
            },
        );
        if (not valid) {
            return ();
        };
        let asset_staking_details : AssetStakingDetails = switch (m_assets_staking_details.get(asset)) {
            case (?res) { res };
            case (_) {
                return ();
            };
        };

        let { lifetime_earnings } = await vault_actor.tokenDetails(asset);

        let new_asset_staking_details = StakeLib.createUserStake(caller, m_users_stakes, asset_staking_details, asset, lifetime_earnings, amount, #None);
        m_assets_staking_details.put(asset, new_asset_staking_details);
        ignore mint(asset_staking_details.liquid_asset, caller, amount);

    };

    ///// withdraw function

    public shared ({ caller }) func withdraw(amount : Nat, asset : Principal) : async () {
        let asset_staking_details : AssetStakingDetails = switch (m_assets_staking_details.get(asset)) {
            case (?res) { res };
            case (_) {
                return ();
            };
        };

        ignore burn_send(asset_staking_details.liquid_asset, asset, amount, caller);
    };

    ///// stake function

    public shared ({ caller }) func stake(amount : Nat, asset : Principal, stake_span : StakeSpan) : async () {
        assert (stake_span != #None);
        let asset_staking_details : AssetStakingDetails = switch (m_assets_staking_details.get(asset)) {
            case (?res) { res };
            case (_) {
                return ();
            };
        };

        let vault_actor : Vault.Vault = actor (Principal.toText(vault));
        let valid = await vault_actor.move_asset(
            asset_staking_details.liquid_asset,
            amount,
            ?Principal.toBlob(caller),
            {
                owner = vault;
                subaccount = null;
            },
        );
        if (not valid) {
            return ();
        };
        let { lifetime_earnings } = await vault_actor.tokenDetails(asset);
        let new_asset_staking_details = StakeLib.createUserStake(
            caller,
            m_users_stakes,
            asset_staking_details,
            asset,
            lifetime_earnings,
            amount,
            stake_span,
        );
        m_assets_staking_details.put(asset, new_asset_staking_details);

    };

    public shared ({ caller }) func unStake(stake_id : Nat) : async () {

        let user_stakes_buffer = switch (m_users_stakes.get(caller)) {
            case (?res) { res };
            case (_) { return };
        };

        let user_stake = user_stakes_buffer.get(stake_id);
        assert (Time.now() >= user_stake.expiry_time);

        let asset_staking_details : AssetStakingDetails = switch (m_assets_staking_details.get(user_stake.asset)) {
            case (?res) { res };
            case (_) {
                return ();
            };
        };

        let vault_actor : Vault.Vault = actor (Principal.toText(vault));

        let { lifetime_earnings } = await vault_actor.tokenDetails(user_stake.asset);

        let (user_earnings : Nat, new_asset_staking_details : AssetStakingDetails) = StakeLib.calculateUserEarnings(
            user_stake,
            asset_staking_details,
            lifetime_earnings,
        );
        m_assets_staking_details.put(user_stake.asset, new_asset_staking_details);
        ignore (
            user_stakes_buffer.remove(stake_id),
            mint(asset_staking_details.liquid_asset, caller, user_earnings),
            vault_actor.move_asset(
                asset_staking_details.liquid_asset,
                user_stake.amount,
                null,
                {
                    owner = vault;
                    subaccount = ?Principal.toBlob(caller);
                },
            ),
        )

    };

    private func mint(asset : Principal, user : Principal, amount : Nat) : async () {

        let liquid_token_actor : ICRC.Actor = actor (Principal.toText(asset));
        let transferArgs : ICRC.TransferArg = {
            from_subaccount = null;
            to = {
                owner = vault;
                subaccount = ?Principal.toBlob(user);
            };
            amount = amount;
            fee = null;
            memo = null;
            created_at_time = null;
        };
        ignore liquid_token_actor.icrc1_transfer(transferArgs);
    };

    private func burn_send(asset_burn : Principal, asset_send : Principal, amount : Nat, user : Principal) : async () {

        let vault_actor : Vault.Vault = actor (Principal.toText(vault));

        let { free_liquidity } = await vault_actor.tokenDetails(asset_send);
        assert (amount >= free_liquidity);

        let valid = await vault_actor.move_asset(
            asset_burn,
            amount,
            ?Principal.toBlob(user),
            // to null account
            {
                owner = Principal.fromActor(this);
                subaccount = null;
            },
        );
        assert (valid);

        ignore vault_actor.move_asset(
            asset_send,
            amount,
            ?Principal.toBlob(Principal.fromActor(this)),
            {
                owner = vault;
                subaccount = ?Principal.toBlob(user);
            },
        );

    };

};
