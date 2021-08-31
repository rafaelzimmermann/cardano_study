#!/bin/bash

addr=$1
cardano-cli query utxo --address $addr --testnet-magic 1097911063
