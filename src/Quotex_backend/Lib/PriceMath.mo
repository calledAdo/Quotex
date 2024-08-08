import Constants "Constants";
import Types "../Types/Types";

module {

    let C = Constants;

    public func _equivalent(amount : Nat, price : Nat, buy : Bool, constants : Types.SwapConstants) : Nat {
        // 10 ** base_dec = (price * (10** quote))/(Price_deciml)
        if (buy) {
            // quote in base out
            return (amount * C.PRICE_DECIMAL * (10 ** constants.base_token_decimal)) / (price * (10 ** constants.quote_token_decimal));
        } else {
            // base in quote out
            return (amount * price * (10 ** constants.quote_token_decimal)) / ((10 ** constants.base_token_decimal) * C.PRICE_DECIMAL);
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
