#!/bin/bash

cardano-node run \
	--topology relay/testnet-topology.json \
	--database-path database \
	--socket-path database/node.socket \
	--host-addr 0.0.0.0 \
	--port 3001 \
	--config relay/testnet-config.json

