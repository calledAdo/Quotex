import Nat64 "mo:base/Nat64";
import Bool "mo:base/Bool";
import bitcalc "Bit";

module {

    private func one_percent() : Nat64 {
        return 1_000;
    };

    ///Note: Uses zero indexing
    public func flipBit(bitmap : Nat, bit_position : Nat64) : Nat {

        if (bit_position == 0) {
            return bitmap;
        };
        let first_bitmap = Nat64.fromNat(bitmap / (2 ** 64));
        let second_bitmap = Nat64.fromNat(bitmap - Nat64.toNat(first_bitmap));
        if (bit_position <= 35) {
            let flipped_bitmap = Nat64.toNat(Nat64.bitflip(first_bitmap, 35 - Nat64.toNat(bit_position)));
            return (flipped_bitmap * (2 ** 64)) + Nat64.toNat(second_bitmap)

        } else {
            let flipped_bitmap = Nat64.bitflip(second_bitmap, 99 - Nat64.toNat(bit_position));

            return ((Nat64.toNat(first_bitmap)) * (2 ** 64)) + Nat64.toNat((flipped_bitmap));
        };

    };

    public func next_initialized_tick(bitmap : Nat, tick : Nat64, buy : Bool) : Nat64 {
        let first_bitmap = Nat64.fromNat(bitmap / (2 ** 64));
        let second_bitmap = Nat64.fromNat(bitmap - Nat64.toNat(first_bitmap));

        let multiplier = tick / one_percent();
        let current_bit_position : Nat64 = (tick % one_percent()) / 10;

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

    private func _next_tick_first_bitmap(shortened_bitmap : Nat64, multiplier : Nat64, current_bit_position : Nat64, buy : Bool) : ?Nat64 {

        let reference = 35 - current_bit_position;
        if (buy) {
            let mask = (1 << reference) - 1;
            let masked = Nat64.bitand(shortened_bitmap, mask);
            if (masked == 0) {
                return null;
            } else {
                return ?((multiplier * one_percent()) + (bitcalc.most_significant_bit_position(masked, 29) * 10));
            };
        } else {
            if (current_bit_position == 0) {
                return ?(((multiplier - 1) * one_percent()) + (99 * 10));
            };
            // a mask that returns all positions to the right of current reference as 1's
            let mask = Nat64.bitnot((1 << (reference + 1)) - 1);
            let masked = Nat64.bitand(shortened_bitmap, mask);

            if (masked == 0) {
                // return next decile ,starting at the 64 bit position
                return ?((multiplier - 1) * one_percent());
            } else {

                return ?((multiplier * one_percent()) + (bitcalc.least_significant_bit_position(masked, 29) * 10));
            };
        };
    };

    private func _next_tick_second_bitmap(first_bitmap : Nat64, second_bitmap : Nat64, multiplier : Nat64, current_bit_position : Nat64, buy : Bool) : Nat64 {

        let reference = 99 - current_bit_position;
        if (buy) {
            let mask = (1 << reference) - 1;
            let masked = Nat64.bitand(second_bitmap, mask);
            if (masked == 0) {
                return (multiplier + 1) * one_percent();
            } else {
                return ((multiplier * one_percent()) + ((35 + bitcalc.most_significant_bit_position(masked, 0)) * 10));
            };
        } else {
            // a mask that returns all positions to the right of current reference as 1's
            let mask = Nat64.bitnot((1 << (reference + 1)) - 1);
            let masked = Nat64.bitand(second_bitmap, mask);

            if (masked == 0) {
                // return next decile ,starting at the 64 bit position
                return ((multiplier * one_percent()) + (bitcalc.least_significant_bit_position(first_bitmap, 29) * 10));
            } else {

                //return the least significant bit from masked
                //i.e the next best(highest) price for buying
                return ((multiplier * one_percent()) + ((35 + bitcalc.least_significant_bit_position(masked, 0)) * 10));
            };
        };
    };

    /// Calculates the next initialised tick within a nultiplier
    /// returns either the  multiplier +- 1 if no tick is initialised within that bitmap

    ///special case
    /// if selling and current bit position is 0 it returns
    ///   (multiplier * one_percent) + (bitcalc.most_significant_bit_position(tick_bitmap) * 10)
    // public func next_initialized_tick(tick_bitmap : Nat64, tick : Nat64, buy : Bool) : Nat64 {

    //     let multiplier = tick / one_percent();
    //     let current_bit_position : Nat64 = (tick % one_percent()) / 10;

    //     //reference serve to rotate the bit position i.e counting from right to left
    //     let reference = (64 - current_bit_position);
    //     if (buy) {

    //         // a mask that returns all positions to the right of current reference as ones
    //         let mask = (1 << reference) - 1; //+ (1 << reference);
    //         let masked = Nat64.bitand(tick_bitmap, mask);
    //         if (masked == 0) {
    //             // return next decile

    //             return (multiplier + 1) * one_percent();
    //         } else {

    //             // return the most significant bit from masked
    //             //i.e the next best(lowest) price for buying
    //             return (multiplier * one_percent()) + (bitcalc.most_significant_bit_position(masked) * 10);
    //         };

    //     } else {
    //         if (current_bit_position == 0) {
    //             return ((multiplier - 1) * one_percent()) + (64 * 10);
    //         };
    //         // a mask that returns all positions to the right of current reference as 1's
    //         let mask = Nat64.bitnot((1 << (reference + 1)) - 1);
    //         let masked = Nat64.bitand(tick_bitmap, mask);

    //         if (masked == 0) {
    //             // return next decile ,starting at the 64 bit position
    //             return ((multiplier - 1) * one_percent());
    //         } else {

    //             //return the least significant bit from masked
    //             //i.e the next best(highest) price for buying
    //             return (multiplier * one_percent()) + (bitcalc.least_significant_bit_position(masked) * 10);
    //         };

    //     };
    // };
};
