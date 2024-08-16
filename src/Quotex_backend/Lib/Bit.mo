import Nat64 "mo:base/Nat64";

/*

*Name:Bit library
*Author :CalledDao

*/

/// Overview
/// The Bit Library is used for utilised with the Bitmap library for tracking next possible tick
/// core functions
/// most_significant_bit_position :finding the position from (1-99) of the most significant bit position
/// (position of the rightmost bit set to 1)

/// least-significant_bit_position :finding the position from (1-99) of the least significant bit
///(position of the leftmost bit set to 1)
///NOTE :counting is from right to left (1...99)

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
