/* the priceFeed actor that utlises the XRC interface to fetch accurate market price data to utilise for trades
   Important features

      Deviation :Once the asset price falls through by certain amount such that
      deviates from the last traded price by up to  after a spcific time */

import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Cycles "mo:base/ExperimentalCycles";
import Time "mo:base/Time";
import Int "mo:base/Int";
import Text "mo:base/Text";
import Error "mo:base/Error";
import Nat64 "mo:base/Nat64";
import Nat8 "mo:base/Nat8";
import Nat "mo:base/Nat";
import XRC "Interface/XRC";

actor class PriceFeed(xrc : Principal) = {

    type GetExchangeRateResult = XRC.GetExchangeRateResult;

    type Factors = {
        deviation : Nat64;
        heartbeat : Int;
        last_updated_time : Time.Time;
    };

    let approved = HashMap.HashMap<Principal, Bool>(1, Principal.equal, Principal.hash);

    let LAST_TRADED_RATE = HashMap.HashMap<Text, GetExchangeRateResult>(1, Text.equal, Text.hash);

    let ASSET_FACTORS = HashMap.HashMap<Text, Factors>(1, Text.equal, Text.hash);

    //gets the y percent of x where y is the intended percentage *  100_000 ,
    private func _percent<X>(x : Nat64, y : Nat64) : Nat64 {
        // product must be divided by 100_000 since y is multiple of 100_000
        return (x * y) / 100_000;
    };

    private func isAllowed(user : Principal) : Bool {
        let allowed : Bool = switch (approved.get(user)) {
            case (?res) { res };
            case (_) { false };
        };
    };

    private func getRate(args : XRC.GetExchangeRateRequest) : async GetExchangeRateResult {
        let xrc_canister : XRC.XRC = actor (Principal.toText(xrc));
        Cycles.add(10_000_000_000);
        return await xrc_canister.get_exchange_rate(args);
    };
    //checks if token's price should be fetched based on if the heartbeat duration has passed since the last call
    private func isElapsed(tokenSymbol : Text) : Bool {
        let current_time = Time.now();
        let token_factor = switch (ASSET_FACTORS.get(tokenSymbol)) {
            case (?res) { res };
            case (_) { return true };
        };

        return (token_factor.last_updated_time + token_factor.heartbeat <= current_time);
    };

    //checks if the deviation threshold has been exceeded by checking both upper bounds and lower bounds

    /*  private func isDeviated(_oldRate : Nat64, _deviation : Nat64, _newRate : Nat64) : Bool {
        let percent_increase = _oldRate + _percent(_oldRate, _deviation);
        let _percent_decrease = _oldRate - _percent(_oldRate, _deviation);
        return (_percent_decrease >= _newRate or percent_increase <= _newRate);
    };*/

    private func getNewFactors(_oldRate : Nat64, _newRate : Nat64) : () {

    };

    public shared ({ caller }) func get_exchange_rate(args : XRC.GetExchangeRateRequest) : async XRC.ExchangeRate {
        assert (isAllowed(caller));

        let previous_rate = switch (LAST_TRADED_RATE.get(args.base_asset.symbol)) {
            case (? #Ok(res)) { res };
            case (_) { throw Error.reject("") };
        };

        if (isElapsed(args.base_asset.symbol) == false) {
            return previous_rate;
        };

        let last_factor : Factors = switch (ASSET_FACTORS.get(args.base_asset.symbol)) {
            case (?res) { res };
            case (null) {
                {
                    deviation = 50_000;
                    heartbeat = 3600;
                    last_updated_time = Time.now();
                };
            };
        };
        let new_rate = switch (await getRate(args)) {
            case (#Ok(res)) { res };
            case (#Err(err)) { throw Error.reject("") };
        };
        ASSET_FACTORS.put(args.base_asset.symbol, { deviation = last_factor.deviation; heartbeat = last_factor.heartbeat; last_updated_time = Time.now() });
        LAST_TRADED_RATE.put(args.base_asset.symbol, #Ok(new_rate));
        return new_rate;
    };
};
