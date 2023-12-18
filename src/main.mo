import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Hash "mo:base/Hash";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Error "mo:base/Error";
import Buffer "mo:base/Buffer";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Pool "Pool";
import LiquidityProvider "LiquidityProvider";
import Types "Types";

actor class Main(_clearingHouse : Principal, admin : Principal, _priceFeed : Principal) = this {

    type LiquidityProvider = LiquidityProvider.LiquidityProvider;
    type Pool = Pool.Pool;

    type Asset = Types.Asset;

    type Quote = Types.Quote;

    type Position = Types.Position;

    // A position type  buffer to loop through positions
    type PositionBuffer = HashMap.HashMap<Principal, Buffer.Buffer<Position>>;

    let assetsList = Buffer.Buffer<Asset>(3);
    let pools = Buffer.Buffer<Principal>(3);
    let providers = Buffer.Buffer<Principal>(3);

    let user_POSITIONS = HashMap.HashMap<Principal, Buffer.Buffer<Position>>(1, Principal.equal, Principal.hash);

    let token_POSITIONS = HashMap.HashMap<Principal, Buffer.Buffer<Position>>(1, Principal.equal, Principal.hash);

    let token_QUOTES = HashMap.HashMap<Principal, Buffer.Buffer<Quote>>(1, Principal.equal, Principal.hash);

    stable let clearingHouse : Principal = _clearingHouse;
    stable let priceFeed : Principal = _priceFeed;

    private func isAllowed(caller : Principal) : Bool {
        return caller == clearingHouse or caller == admin;
    };

    public query func getAsset(id : Nat) : async Asset {
        return assetsList.get(id);
    };
    public query func getQuote(_token : Principal, id : Nat) : async Quote {
        let _tokenQuotes = switch (token_QUOTES.get(_token)) {
            case (?res) { res };
            case (_) { throw Error.reject("") };
        };
        return _tokenQuotes.get(id);
    };

    public query func getPool(id : Nat) : async Principal {
        return pools.get(id);
    };

    private func _getPositionID(_token : Principal, _position : Position, positonBuffer : PositionBuffer) : {
        #Ok : Nat;
        #Err : Text;
    } {
        let total_positions = switch (positonBuffer.get(_token)) {
            case (?res)(res);
            case (_) { return #Err("not found") };
        };
        var counter = 0;
        label looping for (position in total_positions.vals()) {
            if (position == _position) {
                break looping;
            };
            counter += 1;
        };
        return #Ok(counter)

    };

    public query func getPositionID(_token : Principal, _position : Position) : async Nat {
        let position_id = switch (_getPositionID(_token, _position, token_POSITIONS)) {
            case (#Ok(res)) { res };
            case (#Err(err)) { throw Error.reject("") };
        };
    };

    private func _getPositionByID(_token : Principal, _positionID : Nat) : {
        #Ok : Position;
        #Err : Text;
    } {
        let token_positions = switch (token_POSITIONS.get(_token)) {
            case (?res) { res };
            case (_) { return #Err("Not found") };
        };
        return return #Ok(token_positions.get(_positionID));
    };

    public func getPositionByID(_token : Principal, _positionID : Nat) : async Position {
        let res = switch (_getPositionByID(_token, _positionID)) {
            case (#Ok(res)) { res };
            case (#Err(red))(throw Error.reject(""));
        };
        return res;
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
        let _tokenQuotes = switch (token_QUOTES.get(_token)) {
            case (?res) { res };
            case (_) { throw Error.reject("") };
        };
        _tokenQuotes.add(_quote);
        return _tokenQuotes.size() - 1;

    };

    public shared ({ caller }) func removeQuote(_token : Principal, _quoteID : Nat) : async () {
        let _tokenQuotes = switch (token_QUOTES.get(_token)) {
            case (?res) { res };
            case (_) { throw Error.reject("") };
        };
        let _quote : Quote = _tokenQuotes.get(_quoteID);
        let providerPrincipal : Principal = _quote.liq_provider_id;
        let provider : LiquidityProvider = actor (Principal.toText(providerPrincipal));
        assert (caller == (await provider.getAdmin()) or isAllowed(caller));
        let removedQuote : Quote = _tokenQuotes.remove(_quoteID);
    };

    private func _storePosition(_token : Principal, _position : Position, _user : Principal) : async () {
        let total_pos : Buffer.Buffer<Position> = switch (token_POSITIONS.get(_token)) {
            case (?res) { res };
            case (_) { Buffer.Buffer<Position>(1) };
        };

        let user_positions : Buffer.Buffer<Position> = switch (user_POSITIONS.get(_user)) {
            case (?res) { res };
            case (_) { Buffer.Buffer<Position>(1) };
        };
        total_pos.add(_position);
        user_positions.add(_position);
        token_POSITIONS.put(_token, (total_pos));
        user_POSITIONS.put(_user, user_positions);
    };

    private func _removePosition(_token : Principal, _position : Position, _user : Principal, _positonID : Nat) : async () {
        let total_positions = switch (token_POSITIONS.get(_token)) {
            case (?res) { res };
            case (_) { throw Error.reject("") };
        };

        let user_positions = switch (user_POSITIONS.get(_user)) {
            case (?res) { res };
            case (_) { throw Error.reject("") };
        };

        let user_position_id = switch (_getPositionID(_token, _position, user_POSITIONS)) {
            case (#Ok(res)) { res };
            case (#Err(err)) { throw Error.reject("") };
        };
        ignore {
            let removedPosition = total_positions.remove(_positonID);
            user_positions.remove(user_position_id);
        };
        token_POSITIONS.put(_token, total_positions);
        user_POSITIONS.put(_user, user_positions);

    };

    public shared ({ caller }) func storePosition(_token : Principal, _position : Position, _user : Principal) : async () {
        return await _storePosition(_token, _position, _user);
    };
    public shared ({ caller }) func removePosition(_token : Principal, _position : Position, _user : Principal, _positionID : Nat) : async () {
        return await _removePosition(_token, _position, _user, _positionID);
    };
};
