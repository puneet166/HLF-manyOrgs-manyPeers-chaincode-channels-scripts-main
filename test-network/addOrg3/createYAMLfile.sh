

if [ $# -ne 3 ]; then
    echo "Usage: $0 <nameOfTheOrg> <portNumber> <couch_db_portNumber>"
    exit 1
fi

nameOfTheOrg=$1
capitalizedNameOfTheOrg="$(tr '[:lower:]' '[:upper:]' <<< ${nameOfTheOrg:0:1})${nameOfTheOrg:1}"
portNumber=$2
couch_db_portNumber=$3
# proceed=$4
# channelName=$3

crypto_content=$(cat <<EOF
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

# ---------------------------------------------------------------------------
# "PeerOrgs" - Definition of organizations managing peer nodes
# ---------------------------------------------------------------------------
PeerOrgs:
  # ---------------------------------------------------------------------------
  # $capitalizedNameOfTheOrg
  # ---------------------------------------------------------------------------
  - Name: $capitalizedNameOfTheOrg
    Domain: ${nameOfTheOrg}.example.com
    EnableNodeOUs: true
    Template:
      Count: 1
      SANS:
        - localhost
    Users:
      Count: 1
EOF
)
echo $capitalizedNameOfTheOrg
# Generate the configtx.yaml content with variable substitution
configtx_content=$(cat <<EOF
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

---
Organizations:
    # ---------------------------------------------------------------------------
    # $capitalizedNameOfTheOrg
    # ---------------------------------------------------------------------------
    - &$capitalizedNameOfTheOrg
        Name: ${capitalizedNameOfTheOrg}MSP
        ID: ${capitalizedNameOfTheOrg}MSP
        MSPDir: ../organizations/peerOrganizations/${nameOfTheOrg}.example.com/msp
        Policies:
            Readers:
                Type: Signature
                Rule: "OR('${capitalizedNameOfTheOrg}MSP.admin', '${capitalizedNameOfTheOrg}MSP.peer', '${capitalizedNameOfTheOrg}MSP.client')"
            Writers:
                Type: Signature
                Rule: "OR('${capitalizedNameOfTheOrg}MSP.admin', '${capitalizedNameOfTheOrg}MSP.client')"
            Admins:
                Type: Signature
                Rule: "OR('${capitalizedNameOfTheOrg}MSP.admin')"
            Endorsement:
                Type: Signature
                Rule: "OR('${capitalizedNameOfTheOrg}MSP.peer')"
EOF
)

compose_name_of_the_org=$(cat <<EOF
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

version: '3.7'

volumes:
  peer0.${nameOfTheOrg}.example.com:

networks:
  test:
    name: fabric_test

services:

  peer0.${nameOfTheOrg}.example.com:
    container_name: peer0.${nameOfTheOrg}.example.com
    image: hyperledger/fabric-peer:latest
    labels:
      service: hyperledger-fabric
    environment:
      - FABRIC_CFG_PATH=/etc/hyperledger/peercfg
      # Generic peer variables
      - FABRIC_LOGGING_SPEC=INFO
      #- FABRIC_LOGGING_SPEC=DEBUG
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_PROFILE_ENABLED=true
      - CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/tls/server.crt
      - CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/fabric/tls/server.key
      - CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/tls/ca.crt
      # Peer specific variables
      - CORE_PEER_ID=peer0.${nameOfTheOrg}.example.com
      - CORE_PEER_ADDRESS=peer0.${nameOfTheOrg}.example.com:${portNumber}
      - CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/msp
      - CORE_PEER_LISTENADDRESS=0.0.0.0:${portNumber}
      - CORE_PEER_CHAINCODEADDRESS=peer0.${nameOfTheOrg}.example.com:$(($portNumber + 1))
      - CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:$(($portNumber + 1))
      - CORE_PEER_GOSSIP_BOOTSTRAP=peer0.${nameOfTheOrg}.example.com:${portNumber}
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer0.${nameOfTheOrg}.example.com:${portNumber}
      - CORE_PEER_LOCALMSPID=${capitalizedNameOfTheOrg}MSP
      - CORE_METRICS_PROVIDER=prometheus
      - CHAINCODE_AS_A_SERVICE_BUILDER_CONFIG={"peername":"peer0org1"}
      - CORE_CHAINCODE_EXECUTETIMEOUT=300s
    volumes:
        - ../../organizations/peerOrganizations/${nameOfTheOrg}.example.com/peers/peer0.${nameOfTheOrg}.example.com:/etc/hyperledger/fabric
        - peer0.${nameOfTheOrg}.example.com:/var/hyperledger/production
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric/peer
    command: peer node start
    ports:
      - ${portNumber}:${portNumber}
    networks:
      - test
EOF
)
ca_docker_compose_content=$(cat << EOF
version: '3.7'

networks:
  test:
    name: fabric_test

services:
  ca_${nameOfTheOrg}:
    image: hyperledger/fabric-ca:latest
    labels:
      service: hyperledger-fabric
    environment:
      - FABRIC_CA_HOME=/etc/hyperledger/fabric-ca-server
      - FABRIC_CA_SERVER_CA_NAME=ca-${nameOfTheOrg}
      - FABRIC_CA_SERVER_TLS_ENABLED=true
      - FABRIC_CA_SERVER_PORT=$(($portNumber + 3))
    ports:
      - "$(($portNumber + 3)):$(($portNumber + 3))"
    command: sh -c 'fabric-ca-server start -b admin:adminpw -d'
    volumes:
      - ../fabric-ca/${nameOfTheOrg}:/etc/hyperledger/fabric-ca-server
    container_name: ca_${nameOfTheOrg}
EOF
)
couchdb_yaml_content=$(cat << EOF
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

version: '3.7'

networks:
  test:
    name: fabric_test

services:
  couchdb${nameOfTheOrg}:
    container_name: couchdb${nameOfTheOrg}
    image: couchdb:3.3.2
    labels:
      service: hyperledger-fabric
    # Populate the COUCHDB_USER and COUCHDB_PASSWORD to set an admin user and password
    # for CouchDB.  This will prevent CouchDB from operating in an "Admin Party" mode.
    environment:
      - COUCHDB_USER=admin
      - COUCHDB_PASSWORD=adminpw
    ports:
      - "${couch_db_portNumber}:5984"
    networks:
      - test

  peer0.${nameOfTheOrg}.example.com:
    environment:
      - CORE_LEDGER_STATE_STATEDATABASE=CouchDB
      - CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS=couchdb${nameOfTheOrg}:5984
      - CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME=admin
      - CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD=adminpw
    depends_on:
      - couchdb${nameOfTheOrg}
    networks:
      - test
EOF
)
some_content=$(cat <<EOF
version: "3.7"

networks:
  test:
    name: fabric_test

services:
  peer0.${nameOfTheOrg}.example.com:
    container_name: peer0.${nameOfTheOrg}.example.com
    image: hyperledger/fabric-peer:latest
    labels:
      service: hyperledger-fabric
    environment:
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=fabric_test
    volumes:
      - ./docker/peercfg/:/etc/hyperledger/peercfg
      - \${DOCKER_SOCK}/:/host/var/run/docker.sock

EOF
)
couch_compose_content=$(cat << EOF
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

version: '3.7'

EOF
)
echo "$crypto_content" > "${nameOfTheOrg}-crypto.yaml"
echo "$configtx_content" > "configtx.yaml"

echo "$compose_name_of_the_org" > "compose/compose-${nameOfTheOrg}.yaml"
echo "$ca_docker_compose_content" > "compose/compose-ca-${nameOfTheOrg}.yaml"
echo "$couchdb_yaml_content" > "compose/compose-couch-${nameOfTheOrg}.yaml"
echo "$some_content" > "compose/docker/docker-compose-${nameOfTheOrg}.yaml"
echo "$couch_compose_content" > "compose/docker/docker-compose-couch-${nameOfTheOrg}.yaml"
echo "$couch_compose_content" > "compose/docker/docker-compose-ca-${nameOfTheOrg}.yaml"


