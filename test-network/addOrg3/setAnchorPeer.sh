#!/bin/bash

if [ $# -ne 3 ]; then
    echo "Usage: $0 <nameOfTheOrg> <portNumber> <channelName>"
    exit 1
fi
cd ..   
orgName="$1"
portNumber="$2"
channelName="$3"
export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=$PWD/../config/
# export FABRIC_CFG_PATH=${PWD}/configtx

# Check if the current directory is "test-network"
if [ "$(basename "$(pwd)")" != "test-network" ]; then
    echo "Not in the 'test-network' directory."
    exit 1
fi

# Capitalize the first letter of orgName for MSP ID
mspID="$(tr '[:lower:]' '[:upper:]' <<< ${orgName:0:1})${orgName:1}MSP"

# Export environment variables
export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
export ORDERER_ADMIN_TLS_SIGN_CERT=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt
export ORDERER_ADMIN_TLS_PRIVATE_KEY=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.key
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="$mspID"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/${orgName}.example.com/peers/peer0.${orgName}.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/${orgName}.example.com/users/Admin@${orgName}.example.com/msp
export CORE_PEER_ADDRESS=localhost:${portNumber}
echo "line no 29"
peer channel fetch config channel-artifacts/config_block.pb -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com -c  $channelName --tls --cafile $ORDERER_CA
echo "line no 31"
# peer channel fetch config channel-artifacts/config_block.pb -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com -c channel1 --tls --cafile "$ORDERER_CA"
cd channel-artifacts
echo "line no 34"
configtxlator proto_decode --input config_block.pb --type common.Block --output config_block.json
echo "line no 36"
jq '.data.data[0].payload.data.config' config_block.json > config.json
echo "line no 38"
cp config.json config_copy.json
echo "line no 40"
jq ".channel_group.groups.Application.groups.${mspID}.values += {\"AnchorPeers\":{\"mod_policy\": \"Admins\",\"value\":{\"anchor_peers\": [{\"host\": \"peer0.${orgName}.example.com\",\"port\": ${portNumber}}]},\"version\": \"0\"}}" config_copy.json > modified_config.json
echo "line no 42"
configtxlator proto_encode --input config.json --type common.Config --output config.pb
echo "line no 44"
configtxlator proto_encode --input modified_config.json --type common.Config --output modified_config.pb
echo "line no 49"
configtxlator compute_update --channel_id $channelName --original config.pb --updated modified_config.pb --output config_update.pb
echo "line no 51"
configtxlator proto_decode --input config_update.pb --type common.ConfigUpdate --output config_update.json
echo "line no 53"
echo "{\"payload\":{\"header\":{\"channel_header\":{\"channel_id\": \"$channelName\", \"type\":2}},\"data\":{\"config_update\":$(cat config_update.json)}}}" | jq . > config_update_in_envelope.json
echo "line no 55"
configtxlator proto_encode --input config_update_in_envelope.json --type common.Envelope --output config_update_in_envelope.pb
echo "line no 56"
cd ..
echo "line no 59"
peer channel update -f channel-artifacts/config_update_in_envelope.pb -c $channelName -o localhost:7050  --ordererTLSHostnameOverride orderer.example.com --tls --cafile "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem"
echo "line no 61"
peer channel getinfo -c $channelName

# Your code logic using $orgName, $portNumber, and $channelName goes here
echo "In the 'test-network' directory."
echo "orgName: $orgName"
echo "portNumber: $portNumber"
echo "channelName: $channelName"
echo "channels joined by the org is "
peer channel list
# Add more script logic here as needed
# export FABRIC_CFG_PATH=$PWD/../config/
# peer channel join -b ./channel-artifacts/${channelName}.block