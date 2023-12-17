import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import ExperimentalCycles "mo:base/ExperimentalCycles";
import Principal "mo:base/Principal";
import Error "mo:base/Error";
import Nat64 "mo:base/Nat64";
import ICRC "Interface/ICRC";
import Main "main";
import Types "Types";
import Pool "Pool";
import DIP20 "Interface/DIP20";
import PriceFeed "PriceFeed";

actor class ClearingHouse(mainPrincipal : Principal, _priceFeed : Principal) = {

    type Asset = Types.Asset;

    type TokenDetails = Types.TokenDetails;

    public type OpenPositionParams = Types.OpenPositionParams;

    stable let main : Main.Main = actor (Principal.toText(mainPrincipal));
    stable let priceFeed : PriceFeed.PriceFeed = actor (Principal.toText(_priceFeed));

    stable let percentage_basis = Nat64.pow(10, 6);
    //gets the y percent of x where y is the intended percentage *  100_000 ,
    private func _percent(x : Nat64, y : Nat64) : Nat64 {
        // product must be divided by 100_000 since y is multiple of 100_000
        return (x * y) / percentage_basis;
    };

    private func inRange(x : Nat64, min : Nat64, max : Nat64) : Bool {
        return (x <= max and x >= min);
    };

    private func sendOut(_tokenPrincipal : Principal, amount : Nat, from : Principal, from_subaccount : ?Blob, to : Principal, to_subaccount : ?Blob) : async Nat {

        let token : ICRC.ICRC = actor (Principal.toText(_tokenPrincipal));
        let fee = await token.icrc1_fee();
        let tx = await token.icrc2_transfer_from({
            from = { owner = from; subaccount = from_subaccount };
            to = { owner = to; subaccount = to_subaccount };
            amount = amount;
            fee = ?fee;
            memo = null;
            created_at_time = null;
        });
        let result = switch (tx) {
            case (#Ok(num)) { return num };
            case (#Err(err)) { throw Error.reject("") };
        };
    };

    private func sendIn(_tokenPrincipal : Principal, amount : Nat, to : Principal, subaccount : ?Blob) : async Nat {
        let token : ICRC.ICRC = actor (Principal.toText(_tokenPrincipal));

        let fee = await token.icrc1_fee();
        let tx = await token.icrc2_transfer_from({
            from = { owner = mainPrincipal; subaccount = null };
            to = { owner = to; subaccount = subaccount };
            amount = amount;
            fee = ?fee;
            memo = null;
            created_at_time = null;
        });
        let result = switch (tx) {
            case (#Ok(num)) { return num };
            case (#Err(err)) { throw Error.reject("") };
        };

    };

    private func paramsValid(params : OpenPositionParams) : async Bool {
        let quote = await main.getQuote(params.base_asset.id, params.quote_id);
        let poolPrincipal = await main.getPool(params.pool_id);
        let pool : Pool.Pool = actor (Principal.toText(poolPrincipal));
        let tokenDetails = await pool.getTokenDetails(params.base_asset.id);

        return (
            tokenDetails.is_allowed and params.debt <= tokenDetails.max_debt and params.collateral_amount >= tokenDetails.min_collateral and inRange(params.debt, quote.range.min, quote.range.max)
        );

    };

    private func openPosition(caller : Principal, params : OpenPositionParams, subaccount : ?Blob) : async () {

        assert (await paramsValid(params));

        let poolID = await main.getPool(params.pool_id);

        let quote = await main.getQuote(params.base_asset.id, params.quote_id);

        let currentRate = await priceFeed.get_exchange_rate({
            base_asset = {
                symbol = params.base_asset.symbol;
                class_ = params.base_asset.class_;
            };
            quote_asset = {
                symbol = quote.quote_asset.symbol;
                class_ = quote.quote_asset.class_;
            };
            timestamp = null;
        });

        //converst the picedecimal to Nat64 for calculation

        let priceDecimal : Nat64 = Nat32.toNat64(currentRate.metadata.decimals);

        let exchangeValue : Nat64 = (params.debt * currentRate.rate) / 10 ** priceDecimal;
        let quoteValue : Nat64 = _percent(exchangeValue, quote.offer);

        // token transactions
        let tx1 = await sendIn(quote.quote_asset.id, Nat64.toNat(params.collateral_amount), caller, subaccount);
        let tx2 = await sendIn(quote.quote_asset.id, Nat64.toNat(quoteValue), caller, null);
        let tx3 = await sendOut(quote.quote_asset.id, Nat64.toNat(params.debt), quote.liq_provider_id, null, poolID, null);
    };

    private func closePosition(caller : Principal, _poolID : Nat) : async () {};
    public shared ({ caller }) func liquidatePosition() : async () {};
};
