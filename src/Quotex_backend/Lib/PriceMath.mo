module {

    let MINIMUM_BASIS_POINT = 10; // correponds to 0.1%
    // hundred basis point or one percent
    private func HUNDRED_BASIS_POINT() : Nat {
        return 1_000;
    };

    public func _equivalent(amount : Nat, price : Nat, buy : Bool) : Nat {
        let price_decimal = 10 ** 9; // price_decimal 10** 9 ;
        if (buy) {
            // quote in base out
            return (amount * price_decimal) / price;
        } else {
            // base in quote out
            return ((amount * price) / price_decimal);
        };

    };

    public func tick_to_price(multiplier : Nat, bit_position : Nat, snapshot_price : Nat) : Nat {
        let percentile = ((bit_position * HUNDRED_BASIS_POINT()) / 100);
        let percentage = ((multiplier * HUNDRED_BASIS_POINT()) + percentile) * MINIMUM_BASIS_POINT;
        return (percentage * snapshot_price) / (HUNDRED_BASIS_POINT());
    };

};
