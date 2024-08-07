import Nat64 "mo:base/Nat64";
import Bool "mo:base/Bool";
import bitcalc "Bit";
import C "PureFuncs";

module {

    ///Note: Uses zero indexing
    public func flipBit(bitmap : Nat, bit_position : Nat) : Nat {

        if (bit_position == 0) {
            return bitmap;
        };
        let first_bitmap = Nat64.fromNat(bitmap / (2 ** 64));
        let second_bitmap = Nat64.fromNat(bitmap - (Nat64.toNat(first_bitmap) * (2 ** 64)));
        if (bit_position <= 35) {
            let flipped_bitmap : Nat = Nat64.toNat(Nat64.bitflip(first_bitmap, 35 - bit_position));

            ///
            return (flipped_bitmap * (2 ** 64)) + Nat64.toNat(second_bitmap)

        } else {
            let flipped_bitmap : Nat64 = Nat64.bitflip(second_bitmap, 99 - bit_position);

            return ((Nat64.toNat(first_bitmap)) * (2 ** 64)) + Nat64.toNat((flipped_bitmap));
        };

    };

    public func next_initialized_tick(bitmap : Nat, tick : Nat, buy : Bool) : Nat {
        let first_bitmap = Nat64.fromNat(bitmap / (2 ** 64));
        let second_bitmap = Nat64.fromNat(bitmap - (Nat64.toNat(first_bitmap) * (2 ** 64)));

        let multiplier = tick / C.HUNDRED_BASIS_POINT();
        let current_bit_position = (tick % C.HUNDRED_BASIS_POINT()) / 10;

        if (current_bit_position <= 35) {

            switch (_next_tick_first_bitmap(first_bitmap, multiplier, current_bit_position, buy)) {
                case (?res) { return res };
                case (_) {
                    return _next_tick_second_bitmap(first_bitmap, second_bitmap, multiplier, 35, buy);
                };
            };
        } else {
            return _next_tick_second_bitmap(first_bitmap, second_bitmap, multiplier, current_bit_position, buy);
        };
    };

    private func _next_tick_first_bitmap(first_bitmap : Nat64, multiplier : Nat, current_bit_position : Nat, buy : Bool) : ?Nat {

        let reference : Nat = 35 - current_bit_position;
        if (buy) {
            let mask : Nat64 = Nat64.fromNat((2 ** reference) - 1); // (1 << reference) - 1
            let masked = Nat64.bitand(first_bitmap, mask);
            if (masked == 0) {
                return null;
            } else {
                return ?((multiplier * C.HUNDRED_BASIS_POINT()) + (bitcalc.most_significant_bit_position(masked, 29) * 10));
            };
        } else {
            if (current_bit_position == 0) {
                return ?(((multiplier - 1) * C.HUNDRED_BASIS_POINT()) + (99 * 10)); // the next possible tick after a percentile
            };
            // a mask that returns all positions to the right of current reference as 1's
            let mask = Nat64.bitnot(Nat64.fromNat((2 ** (reference + 1)) - 1));
            let masked = Nat64.bitand(first_bitmap, mask);

            if (masked == 0) {
                // return next decile ,starting at the 64 bit position
                return ?((multiplier - 1) * C.HUNDRED_BASIS_POINT());
            } else {

                return ?((multiplier * C.HUNDRED_BASIS_POINT()) + (bitcalc.least_significant_bit_position(masked, 29) * 10));
            };
        };
    };

    private func _next_tick_second_bitmap(first_bitmap : Nat64, second_bitmap : Nat64, multiplier : Nat, current_bit_position : Nat, buy : Bool) : Nat {

        let reference : Nat = 99 - current_bit_position;
        if (buy) {
            let mask = Nat64.fromNat((2 ** reference) - 1);

            let masked = Nat64.bitand(second_bitmap, mask);

            if (masked == 0) {
                return (multiplier + 1) * C.HUNDRED_BASIS_POINT();
            } else {
                return ((multiplier * C.HUNDRED_BASIS_POINT()) + ((35 + bitcalc.most_significant_bit_position(masked, 0)) * 10));
            };
        } else {
            // a mask that returns all positions to the right of current reference as 1's

            let x = Nat64.fromNat((2 ** (reference + 1)) - 1);
            let mask = Nat64.bitnot(x);
            let masked = Nat64.bitand(second_bitmap, mask);

            if (masked == 0) {

                return ((multiplier * C.HUNDRED_BASIS_POINT()) + (bitcalc.least_significant_bit_position(first_bitmap, 29) * 10));
            } else {

                //return the least significant bit from masked
                //i.e the next best(highest) price for buying
                return ((multiplier * C.HUNDRED_BASIS_POINT()) + ((35 + bitcalc.least_significant_bit_position(masked, 0)) * 10));
            };
        };
    };

};
