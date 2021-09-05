#!/bin/bash

path=$1
paymentvkey=$2

# create stake key pair
cardano-cli stake-address key-gen \
 --verification-key-file $path/stake.vkey \
 --signing-key-file $path/stake.skey

# create stake address
cardano-cli stake-address build \
 --stake-verification-key-file $path/stake.vkey \
 --out-file $path/stake.addr \
 --testnet-magic 1097911063

cat $path/stake.addr
echo "\n"

# regenerate payment key
cardano-cli address build \
 --payment-verification-key-file $paymentvkey \
 --stake-verification-key-file $path/stake.vkey \
 --out-file $path/paymentwithstake.addr \
 --testnet-magic 1097911063

