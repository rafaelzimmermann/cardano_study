#!/bin/bash

path=$1
name=$2

cardano-cli address key-gen \
	--verification-key-file "$path/$name.vkey" \
	--signing-key-file "$path/$name.skey"

ls "$path/$name".*

