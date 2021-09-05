#!/bin/bash

stakevkey=$1
outputfile=$2

cardano-cli stake-address registration-certificate \
  --stake-verification-key-file $stakevkey \
  --out-file $outputfile
