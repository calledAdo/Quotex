/// Constants modules

// contains useful constants for different markets

module {

    /// Pri

    public let PRICE_DECIMAL = 1000_000_000; // ( 10 ** 9)

    public let BASE_PRICE = 100000; // 0.0001 i.e 1 basis point of a dollar * price decimal ;

    public let TICK_SPACING = 10; // each tick is ten basis point instaed of 1 (default)

    public let ONE_BASIS_POINT = 10;

    public let HUNDRED_BASIS_POINT = 1_000;

    public let HUNDRED_PERCENT = 100_000; // 10,000 basis points

    public let BASE_UNITS = 1_000_000_000_000_000_000; //(10 ** 18)

};
