import Nat64 "mo:base/Nat64";

///counting from left to right i.e 1....64
module {

    public func most_significant_bit_position(num : Nat64, sub : Nat64) : Nat64 {
        if (num == 0) {
            return 0;
        };

        return (1 + Nat64.bitcountLeadingZero(num) - sub);
    };

    public func least_significant_bit_position(num : Nat64, sub : Nat64) : Nat64 {
        if (num == 0) {
            return 0;
        };
        return (64 - Nat64.bitcountTrailingZero(num) - sub);
    };
};
