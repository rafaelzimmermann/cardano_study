#!/bin/bash

set -ex

MIN_TTL_MINUTES=1200

metadata="$1"
metada_url="$2"
node_ip="$3"
node_port="$4"
path="$5"
paymentaddr="$6"
paymentskey="$7"
stakevkey="$8"  # File
stakeskey="$9"  # File
stake_cert="${10}"
genesis_file="${11}"
paymentaddr2="${12}"

hash=$(cardano-cli stake-pool metadata-hash --pool-metadata-file $metadata)
tmp=`mktemp -d`

echo "Creating stake pool keys"

cardano-cli node key-gen \
    --cold-verification-key-file $path/cold.vkey \
    --cold-signing-key-file $path/cold.skey \
    --operational-certificate-issue-counter-file $path/cold.counter

cardano-cli node key-gen-VRF \
    --verification-key-file $path/vrf.vkey \
    --signing-key-file $path/vrf.skey

cardano-cli node key-gen-KES \
    --verification-key-file $path/kes.vkey \
    --signing-key-file $path/kes.skey

slots_per_kes_period=$(cat $genesis_file | jq .slotsPerKESPeriod)
slot=$(cardano-cli query tip --testnet-magic 1097911063 | jq .slot)

keys_period=$(expr $slot / $slots_per_kes_period)

cardano-cli node issue-op-cert \
--kes-verification-key-file $path/kes.vkey \
--cold-signing-key-file $path/cold.skey \
--operational-certificate-issue-counter $path/cold.counter \
--kes-period $keys_period \
--out-file $path/node.cert


coldvkey=$path/cold.vkey
coldskey=$path/cold.skey
vrfkey=$path/vrf.vkey


cardano-cli stake-pool registration-certificate \
    --cold-verification-key-file $coldvkey \
    --vrf-verification-key-file $vrfkey \
    --pool-pledge 10000000 \
    --pool-cost 340000000 \
    --pool-margin 0.02 \
    --pool-reward-account-verification-key-file $stakevkey \
    --pool-owner-stake-verification-key-file $stakevkey \
    --pool-relay-ipv4 $node_ip \
    --pool-relay-port $node_port \
    --metadata-url $metada_url \
    --metadata-hash $hash \
    --out-file $path/pool-registration.crt \
    --testnet-magic 1097911063

cardano-cli stake-address delegation-certificate \
    --stake-verification-key-file $stakevkey \
    --cold-verification-key-file $coldvkey \
    --out-file $path/delegation.cert


echo "Executing deposit"


cardano-cli query protocol-parameters --testnet-magic 1097911063 --out-file $tmp/protocol.json

amount_ll=$(jq .stakePoolDeposit $tmp/protocol.json)
echo "Amount LL: $amount_ll"

cardano-cli query utxo --address $paymentaddr --testnet-magic 1097911063

tx_hash=$(cardano-cli query utxo --address $paymentaddr2 --testnet-magic 1097911063 | tail -n1 | awk '{print $1}')
tx_ix=$(cardano-cli query utxo --address $paymentaddr2 --testnet-magic 1097911063 | tail -n1 | awk '{print $2}')
balance=$(cardano-cli query utxo --address $paymentaddr2 --testnet-magic 1097911063 | tail -n1 | awk '{print $3}')

echo "TxHash: $tx_hash"
echo "TxIx: $tx_ix"
echo "Current slot: $slot"
echo "Balance: $balance"

ttl=$(($slot+$MIN_TTL_MINUTES))


cardano-cli transaction build-raw \
    --shelley-era \
    --tx-in "$tx_hash#$tx_ix" \
    --tx-out $paymentaddr+0 \
    --invalid-hereafter 0 \
    --fee 0 \
    --out-file $tmp/tx.draft \
    --certificate-file $path/pool-registration.crt \
    --certificate-file $path/delegation.cert



cat $tmp/tx.draft

fee=$(cardano-cli transaction calculate-min-fee \
	 --tx-body-file $tmp/tx.draft \
   --tx-in-count 1 \
   --tx-out-count 1 \
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
	--tx-out $paymentaddr+$final_balance \
	--invalid-hereafter $ttl \
	--fee $fee \
	--out-file $tmp/tx.raw \
  --certificate-file $stake_cert \
  --certificate-file $path/pool-registration.crt \
  --certificate-file $path/delegation.cert

cat $tmp/tx.raw

cardano-cli transaction view --tx-body-file $tmp/tx.raw

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
