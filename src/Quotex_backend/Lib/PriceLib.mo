import Constants "Constants";

module {

    let C = Constants;

    public func _equivalent(
        amount : Nat,
        price : Nat,
        in1out0 : Bool,
        token0_decimal : Nat,
        token1_decimal : Nat,
    ) : Nat {
        // 10 ** base_dec = (price * (10** quote))/(Price_deciml)
        if (in1out0) {
            // quote in base out
            return (amount * C.PRICE_DECIMAL * (10 ** token0_decimal)) / (price * (10 ** token1_decimal));
        } else {
            // base in quote out
            return (amount * price * (10 ** token1_decimal)) / ((10 ** token0_decimal) * C.PRICE_DECIMAL);
        };

    };

    public func tick_to_price(tick : Nat, base_price_multiplier : Nat) : Nat {

        // minimum  reference for market price
        //multiple of $0.000100000 (min_reference)
        //i.e $1 = 0.0001 * 10000(min_reference_multiplier)
        let min_price_reference = C.BASE_PRICE * base_price_multiplier;

        /////////////////
        return (tick * min_price_reference) / (C.HUNDRED_PERCENT);
    };

};
