import Time "mo:base/Time";

module {
    public func HUNDRED_BASIS_POINT() : Nat {
        1_000;
    };

    public func HUNDRED_PERCENT() : Nat {
        100 * HUNDRED_BASIS_POINT();
    };

    public func MIN_BASIS_POINT() : Nat {
        10;
    };

    public func defMaxTick(current_tick : Nat, buy : Bool) : Nat {
        if (buy) {
            current_tick + (10 * HUNDRED_BASIS_POINT());
        } else {
            current_tick - (10 * HUNDRED_BASIS_POINT());
        };
    };

    public func calcInterest(amount : Nat, interest_rate : Nat, start_time : Int) : Nat {

        var fee = 0;
        let one_hour = 3600 * (10 ** 9);

        var starting_time = start_time;
        let current_time = Time.now();

        while (starting_time < current_time) {
            fee += (interest_rate * amount) / (100 * HUNDRED_BASIS_POINT());
            starting_time += one_hour;
        };

        return fee;
    };
};
