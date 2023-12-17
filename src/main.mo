import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Hash "mo:base/Hash";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Error "mo:base/Error";
import Buffer "mo:base/Buffer";
import Int "mo:base/Int";
import Pool "Pool";
import LiquidityProvider "LiquidityProvider";
import Types "Types";

actor class Main(_clearingHouse : Principal, admin : Principal, _priceFeed : Principal) = this {
    type LiquidityProvider = LiquidityProvider.LiquidityProvider;
    type Pool = Pool.Pool;

    type Asset = Types.Asset;

    type Quote = Types.Quote;

    let assetsList = Buffer.Buffer<Asset>(3);
    let tokenQuotes = HashMap.HashMap<Principal, Buffer.Buffer<Quote>>(1, Principal.equal, Principal.hash);
    let pools = Buffer.Buffer<Principal>(3);
    let providers = Buffer.Buffer<Principal>(3);

    stable let clearingHouse : Principal = _clearingHouse;
    stable let priceFeed : Principal = _priceFeed;

    private func isAllowed(caller : Principal) : Bool {
        return caller == clearingHouse or caller == admin;
    };

    public query func getAsset(id : Nat) : async Asset {
        return assetsList.get(id);
    };
    public query func getQuote(_token : Principal, id : Nat) : async Quote {
        let _tokenQuotes = switch (tokenQuotes.get(_token)) {
            case (?res) { res };
            case (_) { throw Error.reject("") };
        };
        return _tokenQuotes.get(id);
    };

    public query func getPool(id : Nat) : async Principal {
        return pools.get(id);
    };
    public query func getClearingHousePrincipal() : async Principal {
        return clearingHouse;
    };

    public query func getPriceFeed() : async Principal {
        return priceFeed;
    };
    // createPool function can only be called by admin to restrict bad actord from wasting cycles and ensure on
    //intereted personnels participate
    public shared ({ caller }) func createPool(_admin : Principal) : async Nat {
        assert (isAllowed(caller));
        let newPool : Pool = await Pool.Pool(_admin, clearingHouse);
        pools.add(Principal.fromActor(newPool));
        return pools.size() + 1;
    };

    public shared ({ caller }) func setQuote(_token : Principal, _providerID : Nat, _quote : Quote) : async Nat {
        let providerPrincipal : Principal = _quote.liq_provider_id;
        let liq_Provider : LiquidityProvider = actor (Principal.toText(providerPrincipal));

        assert (caller == (await liq_Provider.getAdmin()));
        let _tokenQuotes = switch (tokenQuotes.get(_token)) {
            case (?res) { res };
            case (_) { throw Error.reject("") };
        };
        _tokenQuotes.add(_quote);
        return _tokenQuotes.size() - 1;

    };

    public shared ({ caller }) func removQuote(_token : Principal, _quoteID : Nat) : async () {
        let _tokenQuotes = switch (tokenQuotes.get(_token)) {
            case (?res) { res };
            case (_) { throw Error.reject("") };
        };
        let _quote : Quote = _tokenQuotes.get(_quoteID);
        let providerPrincipal : Principal = _quote.liq_provider_id;
        let provider : LiquidityProvider = actor (Principal.toText(providerPrincipal));
        assert (caller == (await provider.getAdmin()) or isAllowed(caller));
        let removedQuote : Quote = _tokenQuotes.remove(_quoteID);
    };

};
