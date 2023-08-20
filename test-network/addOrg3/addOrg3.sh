#!/bin/bash
#
# Copyright IBM Corp All Rights Reserved
#
# SPDX-License-Identifier: Apache-2.0
#

# This script extends the Hyperledger Fabric test network by adding
# adding a third organization to the network
#

# prepending $PWD/../bin to PATH to ensure we are picking up the correct binaries
# this may be commented out to resolve installed version of tools if desired
export PATH=${PWD}/../../bin:${PWD}:$PATH
export FABRIC_CFG_PATH=${PWD}
export VERBOSE=false

. ../scripts/utils.sh

: ${CONTAINER_CLI:="docker"}
: ${CONTAINER_CLI_COMPOSE:="${CONTAINER_CLI}-compose"}
infoln "Using ${CONTAINER_CLI} and ${CONTAINER_CLI_COMPOSE}"

# Using crpto vs CA. default is cryptogen

# Parse commandline args

## Parse mode
if [[ $# -lt 1 ]] ; then
  printHelp
  exit 0
else
  MODE=$1
  shift
fi

# parse flags

while [[ $# -ge 1 ]] ; do
  key="$1"
  case $key in
  -h )
    printHelp
    exit 0
    ;;
  -c )
    CHANNEL_NAME="$2"
    shift
    ;;
  -ca )
    CRYPTO="Certificate Authorities"
    ;;
  -t )
    CLI_TIMEOUT="$2"
    shift
    ;;
  -d )
    CLI_DELAY="$2"
    shift
    ;;
  -s )
    DATABASE="$2"
    shift
    ;;
  -verbose )
    VERBOSE=true
    ;;
    -org)
    ORG_NAME="$2"
    shift
    ;;
  -port)
    PORT_NUMBER="$2"
    shift
    ;;
  *)
    errorln "Unknown flag: $key"
    printHelp
    exit 1
    ;;
  esac
  shift
done

CRYPTO="Certificate Authorities"
# timeout duration - the duration the CLI should wait for a response from
# another container before giving up
CLI_TIMEOUT=10
#default for delay
CLI_DELAY=3
# channel name defaults to "mychannel"
# CHANNEL_NAME="mychannel"
# use this as the docker compose couch file
COMPOSE_FILE_COUCH_BASE="compose/compose-couch-${ORG_NAME}.yaml"
COMPOSE_FILE_COUCH_org4="compose/${CONTAINER_CLI}/docker-compose-couch-${ORG_NAME}.yaml"
# use this as the default docker-compose yaml definition
COMPOSE_FILE_BASE="compose/compose-${ORG_NAME}.yaml"
echo $COMPOSE_FILE_BASE
COMPOSE_FILE_org4="compose/${CONTAINER_CLI}/docker-compose-${ORG_NAME}.yaml"
# certificate authorities compose file
COMPOSE_FILE_CA_BASE="compose/compose-ca-${ORG_NAME}.yaml"
COMPOSE_FILE_CA_org4="compose/${CONTAINER_CLI}/docker-compose-ca-${ORG_NAME}.yaml"
# database
DATABASE="couchdb"

# Get docker sock path from environment variable
SOCK="${DOCKER_HOST:-/var/run/docker.sock}"
DOCKER_SOCK="${SOCK##unix://}"

ORG_NAME_CAPITAL="$(tr '[:lower:]' '[:upper:]' <<< ${ORG_NAME:0:1})${ORG_NAME:1}"


# Determine whether starting, stopping, restarting or generating for announce


# Print the usage message
function printHelp () {
  echo "Usage: "
  echo "  addOrg3.sh up|down|generate [-c <channel name>] [-t <timeout>] [-d <delay>] [-f <docker-compose-file>] [-s <dbtype>]"
  echo "  addOrg3.sh -h|--help (print this message)"
  echo "    <mode> - one of 'up', 'down', or 'generate'"
  echo "      - 'up' - add org3 to the sample network. You need to bring up the test network and create a channel first."
  echo "      - 'down' - bring down the test network and org3 nodes"
  echo "      - 'generate' - generate required certificates and org definition"
  echo "    -c <channel name> - test network channel name (defaults to \"mychannel\")"
  echo "    -ca <use CA> -  Use a CA to generate the crypto material"
  echo "    -t <timeout> - CLI timeout duration in seconds (defaults to 10)"
  echo "    -d <delay> - delay duration in seconds (defaults to 3)"
  echo "    -s <dbtype> - the database backend to use: goleveldb (default) or couchdb"
  echo "    -verbose - verbose mode"
  echo
  echo "Typically, one would first generate the required certificates and "
  echo "genesis block, then bring up the network. e.g.:"
  echo
  echo "	addOrg3.sh generate"
  echo "	addOrg3.sh up"
  echo "	addOrg3.sh up -c mychannel -s couchdb"
  echo "	addOrg3.sh down"
  echo
  echo "Taking all defaults:"
  echo "	addOrg3.sh up"
  echo "	addOrg3.sh down"
}


# We use the cryptogen tool to generate the cryptographic material
# (x509 certs) for the new org.  After we run the tool, the certs will
# be put in the organizations folder with org1 and org2

# Create Organziation crypto material using cryptogen or CAs
function generateOrg3() {
  # Create crypto material using cryptogen
  if [ "$CRYPTO" == "cryptogen" ]; then
    which cryptogen
    if [ "$?" -ne 0 ]; then
      fatalln "cryptogen tool not found. exiting"
    fi
    infoln "Generating certificates using cryptogen tool"

    infoln "Creating Org3 Identities"

    set -x
    cryptogen generate --config="${ORG_NAME}-crypto.yaml" --output="../organizations"
    res=$?
    { set +x; } 2>/dev/null
    if [ $res -ne 0 ]; then
      fatalln "Failed to generate certificates..."
    fi

  fi

  # Create crypto material using Fabric CA
  if [ "$CRYPTO" == "Certificate Authorities" ]; then
    fabric-ca-client version > /dev/null 2>&1
    if [[ $? -ne 0 ]]; then
      echo "ERROR! fabric-ca-client binary not found.."
      echo
      echo "Follow the instructions in the Fabric docs to install the Fabric Binaries:"
      echo "https://hyperledger-fabric.readthedocs.io/en/latest/install.html"
      exit 1
    fi

    infoln "Generating certificates using Fabric CA"
    ${CONTAINER_CLI_COMPOSE} -f ${COMPOSE_FILE_CA_BASE} -f $COMPOSE_FILE_CA_org4 up -d 2>&1
    # docker-compose -f compose/compose-ca-${ORG_NAME}.yaml -f compose/${CONTAINER_CLI}/docker-compose-ca-${ORG_NAME}.yaml up -d
    

    sleep 10

    infoln "Creating ${ORG_NAME} Identities"
    ./fabric-ca/registerEnroll.sh ${ORG_NAME} ${PORT_NUMBER}

  fi

  # infoln "Generating CCP files for Org3"
  # ./ccp-generate.sh ${ORG_NAME} ${PORT_NUMBER}
}

# Generate channel configuration transaction
function generateOrg3Definition() {
  which configtxgen
  if [ "$?" -ne 0 ]; then
    fatalln "configtxgen tool not found. exiting"
  fi
  infoln "Generating Org3 organization definition"
  export FABRIC_CFG_PATH=$PWD
  set -x
  configtxgen -printOrg ${ORG_NAME_CAPITAL}MSP > ../organizations/peerOrganizations/${ORG_NAME}.example.com/${ORG_NAME}.json
  res=$?
  { set +x; } 2>/dev/null
  if [ $res -ne 0 ]; then
    fatalln "Failed to generate Org3 organization definition..."
  fi
}

function Org3Up () {
  # start org3 nodes

  if [ "$CONTAINER_CLI" == "podman" ]; then
    cp ../podman/core.yaml ../../organizations/peerOrganizations/${ORG_NAME}.example.com/peers/peer0.${ORG_NAME}.example.com/
  fi

  if [ "${DATABASE}" == "couchdb" ]; then
    DOCKER_SOCK=${DOCKER_SOCK} ${CONTAINER_CLI_COMPOSE} -f ${COMPOSE_FILE_BASE} -f ${COMPOSE_FILE_org4} -f ${COMPOSE_FILE_COUCH_BASE} -f ${COMPOSE_FILE_COUCH_org4} up -d 2>&1
  else
    DOCKER_SOCK=${DOCKER_SOCK} ${CONTAINER_CLI_COMPOSE} -f ${COMPOSE_FILE_BASE} -f $COMPOSE_FILE_org4 up -d 2>&1
  fi
  if [ $? -ne 0 ]; then
    fatalln "ERROR !!!! Unable to start ${ORG_NAME} network"
  fi
}

# Generate the needed certificates, the genesis block and start the network.
function addOrg3 () {
  # If the test network is not up, abort
  if [ ! -d ../organizations/ordererOrganizations ]; then
    fatalln "ERROR: Please, run ./network.sh up createChannel first."
  fi

  # generate artifacts if they don't exist
    generateOrg3
    generateOrg3Definition

  infoln "Bringing up Org3 peer"
  Org3Up


}

# Tear down running network
function networkDown () {
    cd ..
    ./network.sh down
}

if [ "$MODE" == "up" ]; then
  infoln "Adding ${ORG_NAME} to channel '${CHANNEL_NAME}' with '${CLI_TIMEOUT}' seconds and CLI delay of '${CLI_DELAY}' seconds and using database '${DATABASE}'"
  echo
elif [ "$MODE" == "down" ]; then
  EXPMODE="Stopping network"
elif [ "$MODE" == "generate" ]; then
  EXPMODE="Generating certs and organization definition for ${ORG_NAME}"
else
  printHelp
  exit 1
fi

#Create the network using docker compose
if [ "${MODE}" == "up" ]; then
  addOrg3
elif [ "${MODE}" == "down" ]; then ## Clear the network
  networkDown
elif [ "${MODE}" == "generate" ]; then ## Generate Artifacts
  generateOrg3
  generateOrg3Definition
else
  printHelp
  exit 1
fi