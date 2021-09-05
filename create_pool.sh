#!/bin/bash

set -ex

MIN_TTL_MINUTES=1200

path="$1"
paymentaddr="$2"
paymentstakeaddr="$3"
paymentskey="$4"
stakeskey="$5"  # File
stake_cert="$6"

tmp=`mktemp -d`

echo "Executing deposit"


cardano-cli query protocol-parameters --testnet-magic 1097911063 --out-file $tmp/protocol.json

amount_ll=$(jq .stakePoolDeposit $tmp/protocol.json)
echo "Amount LL: $amount_ll"

cardano-cli query utxo --address $paymentaddr --testnet-magic 1097911063

tx_hash=$(cardano-cli query utxo --address $paymentaddr --testnet-magic 1097911063 | tail -n1 | awk '{print $1}')
tx_ix=$(cardano-cli query utxo --address $paymentaddr --testnet-magic 1097911063 | tail -n1 | awk '{print $2}')
balance=$(cardano-cli query utxo --address $paymentaddr --testnet-magic 1097911063 | tail -n1 | awk '{print $3}')
slot=$(cardano-cli query tip --testnet-magic 1097911063 | jq .slot)

echo "TxHash: $tx_hash"
echo "TxIx: $tx_ix"
echo "Current slot: $slot"
echo "Balance: $balance"

ttl=$(($slot+$MIN_TTL_MINUTES))


cardano-cli transaction build-raw \
    --shelley-era \
    --tx-in "$tx_hash#$tx_ix" \
    --tx-out $paymentstakeaddr+0 \
    --invalid-hereafter 0 \
    --fee 0 \
    --out-file $tmp/tx.draft \
    --certificate-file $path/pool-registration.crt \
    --certificate-file $path/delegation.cert



cat $tmp/tx.draft

fee=$(cardano-cli transaction calculate-min-fee \
	 --tx-body-file $tmp/tx.draft \
   --tx-in-count 1 \
   --tx-out-count 2 \
   --witness-count 3 \
   --byron-witness-count 0 \
	 --testnet-magic 1097911063 \
   --protocol-params-file $tmp/protocol.json | awk '{print $1}')

echo "Fee: $fee"
final_balance=$(($balance-$amount_ll-$fee))

echo "New balance: $final_balance = $balance-$amount_ll-$fee"

cardano-cli transaction build-raw \
  --shelley-era \
	--tx-in "$tx_hash#$tx_ix" \
	--tx-out $paymentstakeaddr+$amount_ll \
  --tx-out $paymentaddr+$final_balance \
	--invalid-hereafter $ttl \
	--fee $fee \
	--out-file $tmp/tx.raw \
  --certificate-file $stake_cert \
  --certificate-file $path/pool-registration.crt \
  --certificate-file $path/delegation.cert

cat $tmp/tx.raw

cardano-cli transaction view --tx-body-file $tmp/tx.raw

coldskey=$path/cold.skey
cardano-cli transaction sign \
	--tx-body-file $tmp/tx.raw \
	--signing-key-file $paymentskey \
  --signing-key-file $stakeskey \
  --signing-key-file $coldskey \
	--testnet-magic 1097911063 \
	--out-file $tmp/tx.signed

cat $tmp/tx.signed

cardano-cli transaction submit \
	--tx-file $tmp/tx.signed \
	--testnet-magic 1097911063

pool_id=$(cardano-cli stake-pool id --cold-verification-key-file $coldvkey --output-format "hex")

cardano-cli query ledger-state --testnet-magic 1097911063 | grep publicKey | grep "$pool_id"
