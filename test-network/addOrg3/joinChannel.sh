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

# Check if the current directory is "test-network"
if [ "$(basename "$(pwd)")" != "test-network" ]; then
    echo "Not in the 'test-network' directory."
    exit 1
fi

# Capitalize the first letter of orgName for MSP ID
mspID="$(tr '[:lower:]' '[:upper:]' <<< ${orgName:0:1})${orgName:1}MSP"

# Export environment variables
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="$mspID"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/${orgName}.example.com/peers/peer0.${orgName}.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/${orgName}.example.com/users/Admin@${orgName}.example.com/msp
export CORE_PEER_ADDRESS=localhost:${portNumber}

# Your code logic using $orgName, $portNumber, and $channelName goes here
echo "In the 'test-network' directory."
echo "orgName: $orgName"
echo "portNumber: $portNumber"
echo "channelName: $channelName"

# Add more script logic here as needed
export FABRIC_CFG_PATH=$PWD/../config/
peer channel join -b ./channel-artifacts/${channelName}.block