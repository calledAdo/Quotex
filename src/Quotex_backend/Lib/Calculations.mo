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

    public func defMaxTick(current_tick : Nat, in1out0 : Bool) : Nat {
        if (in1out0) {
            current_tick + (50 * C.HUNDRED_PERCENT);
        } else {
            current_tick - (50 * C.HUNDRED_PERCENT);
        };
    };

    public func exceeded(stopping_tick : Nat, current_tick : Nat, in1out0 : Bool) : Bool {
        switch (in1out0) {
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

    /// calcShares function
    /// calculates the measure of liquidity provided by a particular order at a tick

    /// params
    /// amount_in : amount of order liquidity (base or quote token)
    /// init_total_shares : the total shares owned by all orders providing liquidity at that tick;
    /// init_liquidity :  the amount of liquidity already within the tick

    public func calcShares(amount_in : Nat, init_total_shares : Nat, init_liquidity : Nat) : Nat {
        if (init_liquidity == 0) {
            return amount_in;
        };
        return (amount_in * init_total_shares) / init_liquidity;
    };

    /// calcSharesValue function
    /// calculates the value of any amount of liquidity shares at a particular tick given the total liquidity at that tick

    ///shares : total shares
    ///init_total_shares : the total_amount of shares of orders at that tick
    /// init_liquidity : the current amount of liquidity
    public func calcSharesValue(shares : Nat, init_total_shares : Nat, init_liquidity : Nat) : Nat {
        return (shares * init_liquidity) / init_total_shares;
    };

    public func percentage(x : Nat, amount : Nat) : Nat {
        return (x * amount) / C.HUNDRED_PERCENT;
    };

};
