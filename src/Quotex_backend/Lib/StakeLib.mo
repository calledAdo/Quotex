import Types "../MarginProvider/Types";
import C "Calculations";
import Constants "Constants";
import HashMap "mo:base/HashMap";
import Buffer "mo:base/Buffer";
import Time "mo:base/Time";

module {
    let YEAR = 31_536_000_000_000_000; //(10 ** 9) * 60 * 60 * 24 * 365;
    let MONTH = 2_628_000_000_000_000;

    type UserStake = Types.UserStake;
    type AssetStakingDetails = Types.AssetStakingDetails;
    type StakeSpan = Types.StakeSpan;
    type AssetDetails = Types.AssetDetails;

    let BASE_UNITS = Constants.BASE_UNITS;

    public func calculateUserEarnings(
        user_stake : UserStake,
        asset_staking_details : AssetStakingDetails,
        lifetime_earnings : Nat,
    ) : (user_earnings : Nat, new_asset_staking_details : AssetStakingDetails) {

        let current_earnings : Nat = lifetime_earnings - asset_staking_details.prev_lifetime_earnings;

        let (stake_lifetime_earnings : Nat, _, _, new_asset_staking_details : AssetStakingDetails) = _updateAssetStake(
            asset_staking_details,
            user_stake.span,
            current_earnings,
            user_stake.amount,
            false,
        );

        let user_earnings : Nat = (user_stake.amount * (stake_lifetime_earnings - user_stake.pre_earnings)) / BASE_UNITS;

        return (user_earnings, new_asset_staking_details);
    };

    public func createUserStake(
        user : Principal,
        m_users_stakes : HashMap.HashMap<Principal, Buffer.Buffer<UserStake>>,
        asset_staking_details : AssetStakingDetails,
        asset : Principal,
        lifetime_earnings : Nat,
        amount : Nat,
        span : StakeSpan,
    ) : (new_asset_stake_details : AssetStakingDetails) {

        let user_stakes = switch (m_users_stakes.get(user)) {
            case (?res) { res };
            case (_) { Buffer.Buffer<UserStake>(2) };
        };

        let current_earnings : Nat = lifetime_earnings - asset_staking_details.prev_lifetime_earnings;

        ////
        let (span_lifetime_earnings : Nat, expiry_time, init_total_locked : Nat, new_asset_stake_details : AssetStakingDetails) = _updateAssetStake(
            asset_staking_details,
            span,
            current_earnings,
            amount,
            true,
        );

        let pre_earnings = if (init_total_locked == 0) { 0 } else {
            span_lifetime_earnings;
        };
        let new_user_stake : UserStake = {
            asset = asset;
            span = span;
            amount = amount;
            pre_earnings = pre_earnings;
            expiry_time = expiry_time;
        };
        user_stakes.add(new_user_stake);
        m_users_stakes.put(user, user_stakes);
        return new_asset_stake_details;
    };

    private func _updateAssetStake(
        asset_staking_details : AssetStakingDetails,
        specific_span : StakeSpan,
        current_earnings : Nat,
        amount : Nat,
        lock : Bool,
    ) : (
        span_lifetime_earnings : Nat,
        span_expiry_time : Time.Time,
        init_total_locked : Nat,
        new_stake_details : AssetStakingDetails,
    ) {

        let new_stake_details = asset_staking_details;
        new_stake_details.prev_lifetime_earnings += current_earnings;

        switch (specific_span) {
            case (#None) {
                let span0_details = asset_staking_details.span0_details;
                let new_span_details : Types.Details = updateSpecificSpan(
                    span0_details,
                    amount,
                    null,
                    current_earnings,
                    lock,
                );
                new_stake_details.span0_details := new_span_details;
                return (
                    new_span_details.lifetime_earnings,
                    0, //adjust
                    span0_details.total_locked,
                    new_stake_details,
                ) // locked_amount;
            };

            /// second case for 2 month slock
            case (#Month2) {
                let span2_details = asset_staking_details.span2_details;
                let new_span_details : Types.Details = updateSpecificSpan(
                    span2_details,
                    amount,
                    ?2,
                    current_earnings,
                    lock,
                );
                new_stake_details.span2_details := new_span_details;
                return (
                    new_span_details.lifetime_earnings,
                    Time.now() + (2 * MONTH),
                    span2_details.total_locked,
                    new_stake_details,
                ) // locked_amount;
            };
            case (#Month6) {
                let span6_details = asset_staking_details.span6_details;
                let new_span_details : Types.Details = updateSpecificSpan(
                    span6_details,
                    amount,
                    ?6,
                    current_earnings,
                    lock,
                );
                new_stake_details.span6_details := new_span_details;
                return (
                    new_span_details.lifetime_earnings,
                    Time.now() + (6 * MONTH),
                    span6_details.total_locked,
                    new_stake_details,
                ) // locked_amount;
            };
            case (#Year) {
                let span12_details = asset_staking_details.span12_details;
                let new_span_details : Types.Details = updateSpecificSpan(
                    span12_details,
                    amount,
                    ?12,
                    current_earnings,
                    lock,
                );
                new_stake_details.span12_details := new_span_details;
                return (
                    new_span_details.lifetime_earnings,
                    Time.now() + YEAR,
                    span12_details.total_locked,
                    new_stake_details,
                ) // locked_amount;
            };
        };

    };

    /// update Specific span

    private func updateSpecificSpan(
        specific_SpanDetails : Types.Details,
        amount : Nat,
        span_share : ?Nat,
        current_earnings : Nat,
        lock : Bool,
    ) : Types.Details {

        let (percentage : Nat, share : Nat, div : Nat) = switch (span_share) {
            case (?res) { (25000, res, 20) };
            case (_) { (75000, 1, 1) };
        };

        let init_total_locked = if (specific_SpanDetails.total_locked == 0) {
            1;
        } else {
            specific_SpanDetails.total_locked;
        };
        ///
        let earnings = C.percentage(percentage, current_earnings);
        // span earnings  per token based on amount locked in specific span
        let span_earnings = (earnings * share * BASE_UNITS) / (div * init_total_locked);

        // update total locked based on either locking or unlocking
        let new_total_locked : Nat = if (lock) {
            specific_SpanDetails.total_locked + amount;
        } else { specific_SpanDetails.total_locked - amount };

        // new details with updated lifetime
        let new_span_details = {
            lifetime_earnings = specific_SpanDetails.lifetime_earnings + span_earnings;
            total_locked = new_total_locked;
        };
        return (new_span_details);
    };
};
