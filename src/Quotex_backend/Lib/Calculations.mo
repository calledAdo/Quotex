import Time "mo:base/Time";
import Constants "Constants";

module {
    let C = Constants;

    ///
    public func mulAndBit(tick : Nat, tick_spacing : Nat) : (multiplier : Nat, bit_position : Nat) {

        let multiplier = tick / (C.HUNDRED_PERCENT * tick_spacing);

        let bit_position = (tick % (C.HUNDRED_PERCENT * tick_spacing)) / (C.HUNDRED_BASIS_POINT * tick_spacing);
        return (multiplier, bit_position);
    };

    public func defMaxTick(current_tick : Nat, buy : Bool) : Nat {
        if (buy) {
            current_tick + (50 * C.HUNDRED_PERCENT);
        } else {
            current_tick - (50 * C.HUNDRED_PERCENT);
        };
    };

    public func calcInterest(amount : Nat, interest_rate : Nat, start_time : Int) : Nat {

        var fee = 0;
        let one_hour = 3600 * (10 ** 9);

        var starting_time = start_time;
        let current_time = Time.now();

        while (starting_time < current_time) {
            fee += (interest_rate * amount) / (100 * C.HUNDRED_BASIS_POINT);
            starting_time += one_hour;
        };

        return fee;
    };

    public func exceeded(stopping_tick : Nat, current_tick : Nat, buy : Bool) : Bool {
        switch (buy) {
            case (true) {
                if (current_tick > stopping_tick) { return true } else {
                    return false;
                };
            };
            case (false) {
                if (current_tick < stopping_tick) { return true } else {
                    return false;
                };
            };
        };
    };
};
