import Hash "mo:base/Hash";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Array "mo:base/Array";

module isEqual {

    type AssetClass = { #Dip20; #ICRC };
    type Asset = {
        id : Principal;
        class_ : AssetClass;
    };
    type TokenPair = {
        asset_in : Asset;
        asset_out : Asset;
    };

    public func pairEqual(_pair1 : TokenPair, _pair2 : TokenPair) : Bool {
        let equalAssetIn = _pair1.asset_in.id == _pair2.asset_in.id;
        let equalAssetOut = _pair1.asset_out.id == _pair2.asset_out.id;
        return (equalAssetIn and equalAssetOut);
    };

    public func pairHash(_pair : TokenPair) : Hash.Hash {
        let text = Principal.toText(_pair.asset_in.id) # Principal.toText(_pair.asset_out.id);
        return Text.hash(text);
    };
};
