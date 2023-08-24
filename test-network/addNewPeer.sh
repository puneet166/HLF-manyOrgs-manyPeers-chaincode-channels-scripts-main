#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Usage: $0 <nameOfTheOrg> <peerName> "
    exit 1
fi
# cd ..   
orgName="$1"
peerName="$2"
# channelName="$3"
# peerName="$4"
# export PATH=${PWD}/../bin:$PATH
# export PATH=$PATH:$PWD/
echo "line no 14"
export PATH=${PWD}/../bin:$PATH

# export PATH=$PATH:${PWD}/../bin
echo "line no 17"

export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/${orgName}.example.com/
echo "line no 20"

fabric-ca-client register --caname ca-${orgName} --id.name ${peerName} --id.secret ${peerName}pw --id.type peer --tls.certfiles ${PWD}/organizations/fabric-ca/${orgName}/tls-cert.pem
echo "line no 23"

mkdir -p organizations/peerOrganizations/${orgName}.example.com/peers/${peerName}.${orgName}.example.com
echo "line no 26"

fabric-ca-client enroll -u https://${peerName}:${peerName}pw@localhost:7054 --caname ca-${orgName} -M ${PWD}/organizations/peerOrganizations/${orgName}.example.com/peers/${peerName}.${orgName}.example.com/msp --csr.hosts ${peerName}.${orgName}.example.com --tls.certfiles ${PWD}/organizations/fabric-ca/${orgName}/tls-cert.pem
echo "line no 29"

cp ${PWD}/organizations/peerOrganizations/${orgName}.example.com/msp/config.yaml ${PWD}/organizations/peerOrganizations/${orgName}.example.com/peers/${peerName}.${orgName}.example.com/msp/config.yaml
echo "line no 32"

fabric-ca-client enroll -u https://${peerName}:${peerName}pw@localhost:7054 --caname ca-${orgName} -M ${PWD}/organizations/peerOrganizations/${orgName}.example.com/peers/${peerName}.${orgName}.example.com/tls --enrollment.profile tls --csr.hosts ${peerName}.${orgName}.example.com --csr.hosts localhost --tls.certfiles ${PWD}/organizations/fabric-ca/${orgName}/tls-cert.pem
echo "line no 35"

cp ${PWD}/organizations/peerOrganizations/${orgName}.example.com/peers/${peerName}.${orgName}.example.com/tls/tlscacerts/* ${PWD}/organizations/peerOrganizations/${orgName}.example.com/peers/${peerName}.${orgName}.example.com/tls/ca.crt
echo "line no 38"

cp ${PWD}/organizations/peerOrganizations/${orgName}.example.com/peers/${peerName}.${orgName}.example.com/tls/signcerts/* ${PWD}/organizations/peerOrganizations/${orgName}.example.com/peers/${peerName}.${orgName}.example.com/tls/server.crt
echo "line no 41"

cp ${PWD}/organizations/peerOrganizations/${orgName}.example.com/peers/${peerName}.${orgName}.example.com/tls/keystore/* ${PWD}/organizations/peerOrganizations/${orgName}.example.com/peers/${peerName}.${orgName}.example.com/tls/server.key
