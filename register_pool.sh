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

genesis_file="${11}"

echo "Creating stake pool keys"

tmp=`mktemp -d`


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
vrfkey=$path/vrf.vkey

hash=$(cardano-cli stake-pool metadata-hash --pool-metadata-file $metadata)


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
