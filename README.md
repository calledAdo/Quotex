# Quotex

Quotex is a decentralised margin trading protocol built on the Internet Comuter Protocol  that utilizes a fully onchain orderbook to execute swaps on the particular asset pair thereby resulting in MEV resistant and slippage free swaps <br>
Deployed Canisters3

[MarginProvider:](https://a4gq6-oaaaa-aaaab-qaa4q-cai.raw.icp0.io/?id=aid6k-6qaaa-aaaag-qkfdq-cai)<br>
[Market:](https://a4gq6-oaaaa-aaaab-qaa4q-cai.raw.icp0.io/?id=bzjav-gyaaa-aaaag-qkfga-cai)<br>
[Vault:](https://a4gq6-oaaaa-aaaab-qaa4q-cai.raw.icp0.io/?id=abavw-iyaaa-aaaag-qkfca-cai)<br>
[token0:](https://a4gq6-oaaaa-aaaab-qaa4q-cai.raw.icp0.io/?id=bfn2e-ryaaa-aaaag-qkfea-cai)<br>
[token1:](https://a4gq6-oaaaa-aaaab-qaa4q-cai.raw.icp0.io/?id=blpxm-kiaaa-aaaag-qkffa-cai) <br>
[token1_liquid:](https://a4gq6-oaaaa-aaaab-qaa4q-cai.raw.icp0.io/?id=bxln5-5iaaa-aaaag-qkfha-cai)<br>

## Test Locally

```bash
   dfx canister create --all
```

Deploy Vault

```bash
export MARGIN_PROVIDER=$(dfx canister id MarginProvider)
dfx deploy Vault  --argument "(principal \"${MARGIN_PROVIDER}\")"
```

Deploy Market specifying both base assets and quote assets as token0 and token1 respectively

```bash
export VAULTID=$(dfx canister id Vault)
export CURRENT_TICK=199900000
export BASE_PRICE_MULTIPLIER=10000
export TOKEN0=$(dfx canister id token0)
export TOKEN1=$(dfx canister id token1)
export TICK_SPACING=1
export TOKEN0_DECIMAL=8
export TOKEN1_DECIMAL=8
export TOKEN0_FEE=10_000
export TOKEN1_FEE=10_000


dfx deploy Market --argument "(record {base_price_multiplier = ${BASE_PRICE_MULTIPLIER};tick_spacing = ${TICK_SPACING};token0 = principal \"${TOKEN0}\";token1 = principal \"${TOKEN1}\";token1_decimal = ${TOKEN1_DECIMAL} ;token0_decimal= ${TOKEN0_DECIMAL}; token1_fee = ${TOKEN1_FEE} ; token0_fee = ${TOKEN0_FEE} },principal \"${VAULTID}\",${CURRENT_TICK})"

```

Deploy token0 and token1

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


dfx deploy token1  --argument "(variant {Init = record {decimals = opt 8;token_symbol = \"${TOKEN_SYMBOL}\";transfer_fee = ${TRANSFER_FEE};metadata = vec {};minting_account = record { owner = principal \"${ACCOUNT1_PRINCIPAL}\" ; subaccount = opt blob \"\6a\6c\bf\1f\1a\c1\56\54\5e\26\5d\dc\e8\d9\36\9d\ea\05\5b\e9\45\ba\14\27\ce\4c\89\67\45\29\55\d0\"};
initial_balances = vec { record { record { owner = principal \"${ACCOUNT2_PRINCIPAL}\" ; subaccount = opt blob \"\fc\21\22\4f\64\a0\3f\64\4c\41\6a\c6\2a\94\7e\7a\a5\bc\5f\d1\bf\90\08\d2\77\cd\b4\7c\73\6d\7f\69\" ;}; ${PRE_MINTED_TOKENS}; }; };archive_options = record {num_blocks_to_archive = ${NUM_OF_BLOCK_TO_ARCHIVE};trigger_threshold = ${TRIGGER_THRESHOLD};controller_id = principal \"${ARCHIVE_CONTROLLER}\";
cycles_for_archive_creation = opt ${CYCLE_FOR_ARCHIVE_CREATION};};token_name = \"${TOKEN_NAME}\";feature_flags = opt record{icrc2 = ${FEATURE_FLAGS}};}
})"

```

```bash
export TOKEN_NAME="TOKEN0"
export TOKEN_SYMBOL="T0"


dfx deploy token0 --argument "(variant {Init = record {decimals = opt 8;token_symbol = \"${TOKEN_SYMBOL}\";transfer_fee = ${TRANSFER_FEE};metadata = vec {};minting_account = record { owner = principal \"${ACCOUNT1_PRINCIPAL}\" ; subaccount = opt blob \"\6a\6c\bf\1f\1a\c1\56\54\5e\26\5d\dc\e8\d9\36\9d\ea\05\5b\e9\45\ba\14\27\ce\4c\89\67\45\29\55\d0\"};
initial_balances = vec { record { record { owner = principal \"${ACCOUNT2_PRINCIPAL}\" ; subaccount = opt blob \"\fc\21\22\4f\64\a0\3f\64\4c\41\6a\c6\2a\94\7e\7a\a5\bc\5f\d1\bf\90\08\d2\77\cd\b4\7c\73\6d\7f\69\" ;}; ${PRE_MINTED_TOKENS}; }; };archive_options = record {num_blocks_to_archive = ${NUM_OF_BLOCK_TO_ARCHIVE};trigger_threshold = ${TRIGGER_THRESHOLD};controller_id = principal \"${ARCHIVE_CONTROLLER}\";
cycles_for_archive_creation = opt ${CYCLE_FOR_ARCHIVE_CREATION};};token_name = \"${TOKEN_NAME}\";feature_flags = opt record{icrc2 = ${FEATURE_FLAGS}};}
})"

```

Deploy MarginProvider

```bash
export VAULT_PRINCIPAL=$(dfx canister id Vault)
dfx deploy MarginProvider --argument "(principal \"${VAULT_PRINCIPAL}\")"
```

Deploy liquid asset setting MarginProvider as minting account

```bash
export TOKEN_NAME="TOKEN1_LP"
export TOKEN_SYMBOL="T1_LP"
export MINTING_ACCOUNT=$(dfx canister id MarginProvider)

dfx deploy token1_liquid --argument "(variant {Init = record {decimals = opt 8;token_symbol = \"${TOKEN_SYMBOL}\";transfer_fee = ${TRANSFER_FEE};metadata = vec {};minting_account = record { owner = principal \"${MINTING_ACCOUNT}\";};
initial_balances = vec { record { record { owner = principal \"${ACCOUNT2_PRINCIPAL}\" ; subaccount = opt blob \"\fc\21\22\4f\64\a0\3f\64\4c\41\6a\c6\2a\94\7e\7a\a5\bc\5f\d1\bf\90\08\d2\77\cd\b4\7c\73\6d\7f\69\" ;}; 0 ; }; };archive_options = record {num_blocks_to_archive = ${NUM_OF_BLOCK_TO_ARCHIVE};trigger_threshold = ${TRIGGER_THRESHOLD};controller_id = principal \"${ARCHIVE_CONTROLLER}\";
cycles_for_archive_creation = opt ${CYCLE_FOR_ARCHIVE_CREATION};};token_name = \"${TOKEN_NAME}\";feature_flags = opt record{icrc2 = ${FEATURE_FLAGS}};}
})"

```

Fund account with token0 and token1

```bash
export VAULT=$(dfx canister id Vault)
dfx canister call token0 icrc1_transfer "(record {to = record { owner = principal \"${VAULT}\" ; subaccount = opt blob \"\6a\6c\bf\1f\1a\c1\56\54\5e\26\5d\dc\e8\d9\36\9d\ea\05\5b\e9\45\ba\14\27\ce\4c\89\67\45\29\55\d0\" ;
};from_subaccount = opt blob \"\6a\6c\bf\1f\1a\c1\56\54\5e\26\5d\dc\e8\d9\36\9d\ea\05\5b\e9\45\ba\14\27\ce\4c\89\67\45\29\55\d0\";amount = 10_000_000_000_000; })"


dfx canister call token1 icrc1_transfer "(record {to = record { owner = principal \"${VAULT}\" ; subaccount = opt blob \"\6a\6c\bf\1f\1a\c1\56\54\5e\26\5d\dc\e8\d9\36\9d\ea\05\5b\e9\45\ba\14\27\ce\4c\89\67\45\29\55\d0\" ;
};from_subaccount = opt blob \"\6a\6c\bf\1f\1a\c1\56\54\5e\26\5d\dc\e8\d9\36\9d\ea\05\5b\e9\45\ba\14\27\ce\4c\89\67\45\29\55\d0\";amount = 1_000_000_000_000_000_000; })"

```

Approve market

```bash
 export MARKET=$(dfx canister id Market)
   dfx canister call Vault approvePrincipal "(principal \"${MARKET}\",true)"
```

### Placing Orders(optionally multiplie orders) And Swapping

Sell Orders

```bash
   dfx canister call  Market placeOrder "(1_000_000_000,200000000)"

   dfx canister call  Market placeOrder "(300_000_000,200200000)"

   dfx canister call  Market placeOrder "(200_000_000,200400000)"

   dfx canister call  Market placeOrder "(200_000_000,200520000)"

```

buy Orders

```bash
  dfx canister call  Market placeOrder "(100_000_000_000,199200000)"

  dfx canister call  Market placeOrder "(30_000_000_000,199000000)"

  dfx canister call  Market placeOrder "(200_000_000_000,198000000)"
```

Swap (returns amount out and amount remaining)

```bash
   dfx canister call Market swap "(10_000_000_000 ,null,true)"
```

### STAKING AND MARGIN TRADING :

Add asset (only called by admin)

```bash
  export LIQUID_ASSET=$(dfx canister id token1_liquid)
  dfx canister call MarginProvider addAsset "(principal \"${TOKEN1}\",principal \"${LIQUID_ASSET}\")"
```

Deposit liqudiity as borrower

```bash
  dfx canister call MarginProvider deposit "(1_000_000_000_000,principal \"${TOKEN1}\")"
```

## Trade with Margin

```bash
 dfx canister call Market openPosition  "(1_000_000_000,50,true,null)"

 dfx canister call Market getUserPosition "(principal \"${ACCOUNT1_PRINCIPAL}\")"

dfx canister call Market closePosition "(principal \"${ACCOUNT1_PRINCIPAL}\")"

```
