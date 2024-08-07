import Nat64 "mo:base/Nat64";

///counting from left to right i.e 1....64
module {

    public func most_significant_bit_position(num : Nat64, sub : Nat) : Nat {
        if (num == 0) {
            return 0;
        };

        let leading_zeroes = Nat64.bitcountLeadingZero(num);

        return (1 + Nat64.toNat(leading_zeroes) - sub);
    };

    public func least_significant_bit_position(num : Nat64, sub : Nat) : Nat {
        if (num == 0) {
            return 0;
        };

        let trailing_zeroes = Nat64.bitcountTrailingZero(num);
        return (64 - Nat64.toNat(trailing_zeroes) - sub);
    };
};
