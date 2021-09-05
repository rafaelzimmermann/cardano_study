#!/bin/bash

set -xe

MIN_TTL_MINUTES=1200
path=`mktemp -d`
input_addr=$1
output_addr=$2
signing_key=$3
stake_cert=$4
stakeskey=$5


cardano-cli query protocol-parameters --testnet-magic 1097911063 --out-file $path/protocol.json

amount_ll=$(jq    .stakeAddressDeposit $path/protocol.json)
echo "Amount LL: $amount_ll"

slot=$(cardano-cli query tip --testnet-magic 1097911063 | jq .slot)

cardano-cli query utxo --address $input_addr --testnet-magic 1097911063

tx_hash=$(cardano-cli query utxo --address $input_addr --testnet-magic 1097911063 | tail -n1 | awk '{print $1}')
tx_ix=$(cardano-cli query utxo --address $input_addr --testnet-magic 1097911063 | tail -n1 | awk '{print $2}')
balance=$(cardano-cli query utxo --address $input_addr --testnet-magic 1097911063 | tail -n1 | awk '{print $3}')

echo "TxHash: $tx_hash"
echo "TxIx: $tx_ix"
echo "Current slot: $slot"
echo "Balance: $balance"

ttl=$(($slot+$MIN_TTL_MINUTES))


cardano-cli transaction build-raw \
    --tx-in "$tx_hash#$tx_ix" \
    --tx-out $output_addr+0 \
    --ttl 0 \
    --fee 0 \
    --out-file $path/tx.raw \
    --certificate-file $stake_cert \
    --shelley-era

cat $path/tx.raw

fee=$(cardano-cli transaction calculate-min-fee \
	 --tx-body-file $path/tx.raw \
	 --tx-in-count 1 \
	 --tx-out-count 1 \
	 --witness-count 1 \
	 --byron-witness-count 0 \
	 --testnet-magic 1097911063 \
	 --protocol-params-file $path/protocol.json | awk '{print $1}')

echo "Fee: $fee"
final_balance=$(($balance-$amount_ll-$fee))

echo "New balance: $final_balance = $balance-$amount_ll-$fee"

cardano-cli transaction build-raw \
	--tx-in "$tx_hash#$tx_ix" \
	--tx-out $output_addr+$amount_ll \
	--tx-out $input_addr+$final_balance \
	--ttl $ttl \
	--fee $fee \
	--out-file $path/tx.raw \
  --certificate-file $stake_cert

cat $path/tx.raw


cardano-cli transaction sign \
	--tx-body-file $path/tx.raw \
	--signing-key-file $signing_key \
    --signing-key-file $stakeskey \
	--testnet-magic 1097911063 \
	--out-file $path/tx.signed

cat $path/tx.signed

cardano-cli transaction submit \
	--tx-file $path/tx.signed \
	--testnet-magic 1097911063
