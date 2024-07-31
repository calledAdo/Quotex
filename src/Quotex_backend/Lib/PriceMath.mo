import Nat64 "mo:base/Nat64";
module {

    public func _equivalent(amount : Nat, price : Nat, buy : Bool) : Nat {
        let percent = 100_000;
        if (buy) {
            return (amount * percent) / price;
        } else {
            return (amount * price) / percent;
        };

    };

    public func tick_to_price(multiplier : Nat64, bit_position : Nat64, snapshot_price : Nat64) : Nat {
        let one_percent : Nat64 = 1_000;
        let percentile = (bit_position * one_percent) / 650;
        let percentage = (multiplier * one_percent) + percentile;
        return Nat64.toNat((percentage * snapshot_price));
    };
};
