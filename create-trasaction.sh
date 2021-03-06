#!/bin/bash

set -xe

MIN_TTL_MINUTES=1200
path=`mktemp -d`
input_addr=$1
output_addr=$2
amount=$3
signing_key=$4
amount_ll=$(printf "%.0f\n" $(bc -l <<<"$amount*1000000"))
echo "Amount LL: $amount_ll"
cardano-cli query protocol-parameters --testnet-magic 1097911063 --out-file $path/protocol.json

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

echo "TTL: $ttl"

cardano-cli transaction build-raw \
	--tx-in "$tx_hash#$tx_ix" \
	--tx-out $output_addr+$amount_ll \
	--tx-out $input_addr+0 \
	--ttl 0 \
	--fee 0 \
	--out-file $path/tx.raw

cat $path/tx.raw

fee=$(cardano-cli transaction calculate-min-fee \
	 --tx-body-file $path/tx.raw \
	 --tx-in-count 1 \
	 --tx-out-count 2 \
	 --witness-count 1 \
	 --byron-witness-count 0 \
	 --testnet-magic 1097911063 \
	 --protocol-params-file $path/protocol.json | awk '{print $1}')

echo "Fee: $fee"
amount_ll=$(($amount_ll-$fee))
final_balance=$(($balance-$amount_ll-$fee))

echo "New balance: $final_balance"


cardano-cli transaction build-raw \
	--tx-in "$tx_hash#$tx_ix" \
	--tx-out $output_addr+$amount_ll \
	--tx-out $input_addr+$final_balance \
	--ttl $ttl \
	--fee $fee \
	--out-file $path/tx.raw

cat $path/tx.raw


cardano-cli transaction sign \
	--tx-body-file $path/tx.raw \
	--signing-key-file $signing_key \
	--testnet-magic 1097911063 \
	--out-file $path/tx.signed

cat $path/tx.signed

cardano-cli transaction submit \
	--tx-file $path/tx.signed \
	--testnet-magic 1097911063
