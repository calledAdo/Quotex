import Nat64 "mo:base/Nat64";
import Bool "mo:base/Bool";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import bitcalc "Bit";
import Constants "Constants";
import F "Calculations";

/*
 *Name :BitMap lib
  *Author:CalledDAO


*/

/// Overview

/// Bitmap library is utilised for finding next possible ticks with liquidity
/// during swaps to ensure gas efficient and fast swaps

///Concepts
/// Each tick represents a percentage value of the reference price (see Constants.mio)
/// ticks comprises of two parts
///   the multiplier which can be seen as the ratio tick/one percent (the interger part )
///   the basis which can be seen as the the modulo of tick by one percent (the decimals part)

/// Each multiplier is mapped to a bitmap of 99 bits representing all possible percentage within
///(multiplier percent and (multiplier + 1) with each bit being 1 basis point from the previous)

module {

    let HUNDRED_PERCENT = Constants.HUNDRED_PERCENT;

    let HUNDRED_BASIS_POINT = Constants.HUNDRED_BASIS_POINT;

    /// flipBit function
    ///  sets a particular bit position in a bitmap to zero or to one
    /// utilised when setting a new tick or deactivating a set one

    public func flipBit(bitmap : Nat, bit_position : Nat) : Nat {

        if (bit_position == 0) {
            return bitmap;
        };
        let first_bitmap = Nat64.fromNat(Nat.bitshiftRight(bitmap, 64));
        let second_bitmap = Nat64.fromNat(bitmap - Nat.bitshiftLeft(Nat64.toNat(first_bitmap), 64));
        if (bit_position <= 35) {
            let flipped_bitmap : Nat = Nat64.toNat(Nat64.bitflip(first_bitmap, 35 - bit_position));

            ///
            return Nat.bitshiftLeft(flipped_bitmap, 64) + Nat64.toNat(second_bitmap)

        } else {
            let flipped_bitmap : Nat64 = Nat64.bitflip(second_bitmap, 99 - bit_position);

            return Nat.bitshiftLeft(Nat64.toNat(first_bitmap), 64) + Nat64.toNat((flipped_bitmap));
        };

    };

    /// next_initialised_tick function
    /// gets the next initialised tick  to the right (for buying) or to the left (for selling) within a particular multiplier
    // utilised for swaps spanning across multiple price ranges
    ///params
    /// bitmap :the current bitmap of the tick's multiplier
    /// tick : the particular tick
    /// in1out0 : true when swap is a buy  and false when a sell

    /// bitmap os typically split into two parts of 64 bits each

    public func next_initialized_tick(bitmap : Nat, current_tick : Nat, in1out0 : Bool, tick_spacing : Nat) : Nat {

        // split the bitmap into two portions
        let first_bitmap = Nat64.fromNat(Nat.bitshiftRight(bitmap, 64));
        let second_bitmap = Nat64.fromNat(bitmap - Nat.bitshiftLeft(Nat64.toNat(first_bitmap), 64));

        let (multiplier, current_bit_position) = F.mulAndBit(current_tick, tick_spacing);

        if (current_bit_position <= 35) {

            switch (_next_tick_first_bitmap(multiplier, current_bit_position, first_bitmap, in1out0, tick_spacing)) {
                case (?res) { return res };
                case (_) {
                    return _next_tick_second_bitmap(multiplier, 35, first_bitmap, second_bitmap, in1out0, tick_spacing);
                };
            };
        } else {
            return _next_tick_second_bitmap(multiplier, current_bit_position, first_bitmap, second_bitmap, in1out0, tick_spacing);
        };
    };

    /// takes in the first part of the bitmap and checks for the next initialised within it
    /// if swap is a buy and no tick is initialised ,it returns null,and the check continues in the second
    /// part of the bitmap

    /// params
    /*

    multiplier : the specific multiplier value
    current_bit_position : the bit position or (decimals ) of the current tick
    first_bitmap : the first portion of the multiplier bitmap
    in1out0; true if buying and false otherwise
    tickspacing :the value of the tick spacing between two adjacent bits in the bitmap
        */
    private func _next_tick_first_bitmap(
        multiplier : Nat,
        current_bit_position : Nat,
        first_bitmap : Nat64,
        in1out0 : Bool,
        tick_spacing : Nat,
    ) : ?Nat {

        let reference : Nat32 = 35 - Nat32.fromNat(current_bit_position);
        if (in1out0) {
            let mask : Nat64 = Nat64.fromNat(
                Nat.bitshiftLeft(1, reference) - 1
            ); // (1 << reference) - 1
            let masked = Nat64.bitand(first_bitmap, mask);
            if (masked == 0) {
                return null;
            } else {
                return ?(
                    (
                        (multiplier * HUNDRED_PERCENT) +
                        (bitcalc.most_significant_bit_position(masked, 29) * HUNDRED_BASIS_POINT)
                    ) * tick_spacing
                );
            };
        } else {
            if (current_bit_position == 0) {
                return ?((((multiplier - 1) * HUNDRED_PERCENT) + (99 * HUNDRED_BASIS_POINT)) * tick_spacing); // the next possible tick after a percentile
            };
            // a mask that returns all positions to the right of current reference as 1's
            let mask = Nat64.bitnot(
                Nat64.fromNat(
                    Nat.bitshiftLeft(1, reference + 1) - 1
                )
            );
            let masked = Nat64.bitand(first_bitmap, mask);

            if (masked == 0) {
                // return next decile ,starting at the 64 bit position
                return ?(((multiplier - 1) * HUNDRED_PERCENT) * tick_spacing);
            } else {

                return ?(
                    ((multiplier * HUNDRED_PERCENT) + (bitcalc.least_significant_bit_position(masked, 29) * HUNDRED_BASIS_POINT)) * tick_spacing
                );
            };
        };
    };

    /// Checks for the next intialised tick within the second bitmap
    /// if selling and no tick is initialised within second bitmap
    /// it returns the  next initialised tick closest to the right of the first bitmap

    /*

    multiplier : the specific multiplier value
    current_bit_position : the bit position or (decimals ) of the current tick
    first_bitmap : the first part of the multiplier bitmap
    second_bitmap : the second part of the multiplier bitmap
    in1out0; true if buying and false otherwise
    tickspacing :the value of the tick spacing between two adjacent bits in the bitmap

    */

    private func _next_tick_second_bitmap(
        multiplier : Nat,
        current_bit_position : Nat,
        first_bitmap : Nat64,
        second_bitmap : Nat64,
        in1out0 : Bool,
        tick_spacing : Nat,
    ) : Nat {

        let reference : Nat32 = 99 - Nat32.fromNat(current_bit_position);
        if (in1out0) {
            let mask = Nat64.fromNat(
                Nat.bitshiftLeft(1, reference) - 1
            ); //shiftleft(1,reference ) - 1

            let masked = Nat64.bitand(second_bitmap, mask);

            if (masked == 0) {
                return ((multiplier + 1) * HUNDRED_PERCENT) * tick_spacing;
            } else {
                return (((multiplier * HUNDRED_PERCENT) + ((35 + bitcalc.most_significant_bit_position(masked, 0)) * HUNDRED_BASIS_POINT)) * tick_spacing);
            };
        } else {
            // a mask that returns all positions to the right of current reference as 1's

            let x = Nat64.fromNat(
                Nat.bitshiftLeft(1, (reference + 1)) - 1
            );
            let mask = Nat64.bitnot(x);
            let masked = Nat64.bitand(second_bitmap, mask);

            if (masked == 0) {
                // if selling and no tick is initialised within second bitmap
                // returns the initilaised tick closest to the right within  first  bitmap
                return (((multiplier * HUNDRED_PERCENT) + (bitcalc.least_significant_bit_position(first_bitmap, 29) * HUNDRED_BASIS_POINT)) * tick_spacing);
            } else {

                //return the least significant bit from masked
                //i.e the next best(highest) price for buying
                return (((multiplier * HUNDRED_PERCENT) + ((35 + bitcalc.least_significant_bit_position(masked, 0)) * HUNDRED_BASIS_POINT)) * tick_spacing);
            };
        };
    };

};
