```bash
    dfx canister create --all
```

deploy Vault

```bash


export MARGIN_PROVIDER=$(dfx canister id MarginProvider)

dfx deploy Vault --argument "(principal \"${MARGIN_PROVIDER}\")"


```

deploy Market

```bash


export VAULTID=$(dfx canister id Vault)
export CURRENT_TICK=199900000
export BASE_PRICE_MULTIPLIER=10000
export MARGIN_PROVIDER=$(dfx canister id MarginProvider)
export TOKEN0=$(dfx canister id token0)
export TOKEN1=$(dfx canister id token1)
export TICK_SPACING=1
export TOKEN0_DECIMAL=8
export TOKEN1_DECIMAL=8
export TOKEN0_FEE=10_000
export TOKEN1_FEE=10_000



dfx deploy Market --argument "(record {base_price_multiplier = ${BASE_PRICE_MULTIPLIER};margin_provider = principal \"${MARGIN_PROVIDER}\";tick_spacing = ${TICK_SPACING};token0 = principal \"${TOKEN0}\";token1 = principal \"${TOKEN1}\";token1_decimal = ${TOKEN1_DECIMAL} ;token0_decimal= ${TOKEN0_DECIMAL}; token1_fee = ${TOKEN1_FEE} ; token0_fee = ${TOKEN0_FEE} },principal \"${VAULTID}\",${CURRENT_TICK})"

```

deploy token

```bash


export PRE_MINTED_TOKENS=10_000_000_000
export ACCOUNT1_PRINCIPAL=gvphd-z5ozt-rcgex-clrhh-2d6y3-j3eni-346vu-lde5d-iokcr-gy2ad-5qe
export ACCOUNT2_PRINCIPAL=ahrng-v5kxc-f45nx-5bpp4-xsbul-bfqqd-knx6g-y5lcx-qroyz-c5wxd-dqe
export TRANSFER_FEE=10_000
export TRIGGER_THRESHOLD=2000
export CYCLE_FOR_ARCHIVE_CREATION=10000000000000
export NUM_OF_BLOCK_TO_ARCHIVE=1000
export TOKEN_NAME="TOKEN1"
export TOKEN_SYMBOL="T1"
export MINTER=gvphd-z5ozt-rcgex-clrhh-2d6y3-j3eni-346vu-lde5d-iokcr-gy2ad-5qe
export FEATURE_FLAGS=false
export ARCHIVE_CONTROLLER=ahrng-v5kxc-f45nx-5bpp4-xsbul-bfqqd-knx6g-y5lcx-qroyz-c5wxd-dqe


dfx deploy token0 --argument "(variant {Init = record {decimals = opt 8;token_symbol = \"${TOKEN_SYMBOL}\";transfer_fee = ${TRANSFER_FEE};metadata = vec {};minting_account = record { owner = principal \"${ACCOUNT1_PRINCIPAL}\" ; subaccount = opt blob \"\6a\6c\bf\1f\1a\c1\56\54\5e\26\5d\dc\e8\d9\36\9d\ea\05\5b\e9\45\ba\14\27\ce\4c\89\67\45\29\55\d0\"};
initial_balances = vec { record { record { owner = principal \"${ACCOUNT2_PRINCIPAL}\" ; subaccount = opt blob \"\fc\21\22\4f\64\a0\3f\64\4c\41\6a\c6\2a\94\7e\7a\a5\bc\5f\d1\bf\90\08\d2\77\cd\b4\7c\73\6d\7f\69\" ;}; ${PRE_MINTED_TOKENS}; }; };archive_options = record {num_blocks_to_archive = ${NUM_OF_BLOCK_TO_ARCHIVE};trigger_threshold = ${TRIGGER_THRESHOLD};controller_id = principal \"${ARCHIVE_CONTROLLER}\";
cycles_for_archive_creation = opt ${CYCLE_FOR_ARCHIVE_CREATION};};token_name = \"${TOKEN_NAME}\";feature_flags = opt record{icrc2 = ${FEATURE_FLAGS}};}
})"




```

check

fund account token0 and token1

```bash
export VAULT=$(dfx canister id Vault)
dfx canister call token0 icrc1_transfer "(record {to = record { owner = principal \"${VAULT}\" ; subaccount = opt blob \"\6a\6c\bf\1f\1a\c1\56\54\5e\26\5d\dc\e8\d9\36\9d\ea\05\5b\e9\45\ba\14\27\ce\4c\89\67\45\29\55\d0\" ;
};from_subaccount = opt blob \"\6a\6c\bf\1f\1a\c1\56\54\5e\26\5d\dc\e8\d9\36\9d\ea\05\5b\e9\45\ba\14\27\ce\4c\89\67\45\29\55\d0\";amount = 10_000_000_000_000; })"


dfx canister call token1 icrc1_transfer "(record {to = record { owner = principal \"${VAULT}\" ; subaccount = opt blob \"\6a\6c\bf\1f\1a\c1\56\54\5e\26\5d\dc\e8\d9\36\9d\ea\05\5b\e9\45\ba\14\27\ce\4c\89\67\45\29\55\d0\" ;
};from_subaccount = opt blob \"\6a\6c\bf\1f\1a\c1\56\54\5e\26\5d\dc\e8\d9\36\9d\ea\05\5b\e9\45\ba\14\27\ce\4c\89\67\45\29\55\d0\";amount = 10_000_000_000_000_000_000; })"


```

approve market

```bash
 export MARKET=$(dfx canister id Market)
   dfx canister call Vault approvePrincipal "(principal \"${MARKET}\")"



```

place order

```bash
  dfx canister call Market placeOrder "(1_000_000_000,199620000)"

```

swap

```bash
   dfx canister call Market swap "(1_000_000_000,null,true)"

   dfx canister call Market _tickDetails "(200000000 )"
```

STAKING :

deploy MarginProvider

```bash
export VAULT_PRINCIPAL=$(dfx canister id Vault)
dfx deploy MarginProvider --argument "(principal \"${VAULT_PRINCIPAL}\")"
```

deploy liquid asset setting MarginProvider as minting account

```bash
export TOKEN_NAME="TOKEN1_LP"
export TOKEN_SYMBOL="T1_LP"
export MINTING_ACCOUNT=$(dfx canister id MarginProvider)

dfx deploy token1_liquid --argument "(variant {Init = record {decimals = opt 8;token_symbol = \"${TOKEN_SYMBOL}\";transfer_fee = ${TRANSFER_FEE};metadata = vec {};minting_account = record { owner = principal \"${MINTING_ACCOUNT}\";};
initial_balances = vec { record { record { owner = principal \"${ACCOUNT2_PRINCIPAL}\" ; subaccount = opt blob \"\fc\21\22\4f\64\a0\3f\64\4c\41\6a\c6\2a\94\7e\7a\a5\bc\5f\d1\bf\90\08\d2\77\cd\b4\7c\73\6d\7f\69\" ;}; 0 ; }; };archive_options = record {num_blocks_to_archive = ${NUM_OF_BLOCK_TO_ARCHIVE};trigger_threshold = ${TRIGGER_THRESHOLD};controller_id = principal \"${ARCHIVE_CONTROLLER}\";
cycles_for_archive_creation = opt ${CYCLE_FOR_ARCHIVE_CREATION};};token_name = \"${TOKEN_NAME}\";feature_flags = opt record{icrc2 = ${FEATURE_FLAGS}};}
})"


dfx canister call token1_liquid icrc1_total_supply "()"

```

add asset (only called by admin)

```bash
  export LIQUID_ASSET=$(dfx canister id token1_liquid)
  dfx canister call MarginProvider addAsset "(principal \"${TOKEN1}\",principal \"${LIQUID_ASSET}\")"
```

deposit and withdraw

```bash
  dfx canister call MarginProvider deposit "(1000_000_000_000_000,principal \"${TOKEN1}\")"


    dfx canister call MarginProvider withdraw "(1_000_000_000_000,principal \"${TOKEN1}\")"
```

checking balance

```bash
   dfx canister call token1 icrc1_balance_of "(record { owner = principal \"${VAULT}\" ; subaccount = opt blob \"\6a\6c\bf\1f\1a\c1\56\54\5e\26\5d\dc\e8\d9\36\9d\ea\05\5b\e9\45\ba\14\27\ce\4c\89\67\45\29\55\d0\" ;
})"
```

Trading on Margin

```bash

dfx canister call Vault userMarketPosition  "(principal \"${ACCOUNT1_PRINCIPAL}\",principal
\"${MARKET}\")"

dfx canister call Market closePosition "(principal \"${ACCOUNT1_PRINCIPAL}\")"

   dfx canister call Market openPosition  "(1_000_000_000,50,true,null)"

```
