
if [ $# -ne 2 ]; then
    echo "Usage: $0 <nameOfTheOrg> <portNumber>"
    exit 1
fi

nameOfTheOrg=$1
capitalizedNameOfTheOrg="$(tr '[:lower:]' '[:upper:]' <<< ${nameOfTheOrg:0:1})${nameOfTheOrg:1}"
portNumber=$2


  infoln "Enrolling the CA admin"
  mkdir -p "../organizations/peerOrganizations/${nameOfTheOrg}.example.com/"

  export FABRIC_CA_CLIENT_HOME=${PWD}/../organizations/peerOrganizations/${nameOfTheOrg}.example.com/

  set -x
  ../../bin/fabric-ca-client enroll -u https://admin:adminpw@localhost:$(($portNumber + 3)) --caname ca-${nameOfTheOrg} --tls.certfiles "${PWD}/fabric-ca/${nameOfTheOrg}/tls-cert.pem"
  { set +x; } 2>/dev/null

  echo 'NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/localhost-'$(($portNumber + 3))'-ca-'${nameOfTheOrg}'.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/localhost-'$(($portNumber + 3))'-ca-'${nameOfTheOrg}'.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/localhost-'$(($portNumber + 3))'-ca-'${nameOfTheOrg}'.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/localhost-'$(($portNumber + 3))'-ca-'${nameOfTheOrg}'.pem
    OrganizationalUnitIdentifier: orderer' > "${PWD}/../organizations/peerOrganizations/${nameOfTheOrg}.example.com/msp/config.yaml"

  infoln "Registering peer0"
  set -x
  ../../bin/fabric-ca-client register --caname ca-${nameOfTheOrg} --id.name peer0 --id.secret peer0pw --id.type peer --tls.certfiles "${PWD}/fabric-ca/${nameOfTheOrg}/tls-cert.pem"
  { set +x; } 2>/dev/null

  infoln "Registering user"
  set -x
  ../../bin/fabric-ca-client register --caname ca-${nameOfTheOrg} --id.name user1 --id.secret user1pw --id.type client --tls.certfiles "${PWD}/fabric-ca/${nameOfTheOrg}/tls-cert.pem"
  { set +x; } 2>/dev/null

  infoln "Registering the org admin"
  set -x
  ../../bin/fabric-ca-client register --caname ca-${nameOfTheOrg} --id.name ${nameOfTheOrg}admin --id.secret ${nameOfTheOrg}adminpw --id.type admin --tls.certfiles "${PWD}/fabric-ca/${nameOfTheOrg}/tls-cert.pem"
  { set +x; } 2>/dev/null

  infoln "Generating the peer0 msp"
  set -x
  ../../bin/fabric-ca-client enroll -u https://peer0:peer0pw@localhost:$(($portNumber + 3)) --caname ca-${nameOfTheOrg} -M "${PWD}/../organizations/peerOrganizations/${nameOfTheOrg}.example.com/peers/peer0.${nameOfTheOrg}.example.com/msp" --tls.certfiles "${PWD}/fabric-ca/${nameOfTheOrg}/tls-cert.pem"
  { set +x; } 2>/dev/null

  cp "${PWD}/../organizations/peerOrganizations/${nameOfTheOrg}.example.com/msp/config.yaml" "${PWD}/../organizations/peerOrganizations/${nameOfTheOrg}.example.com/peers/peer0.${nameOfTheOrg}.example.com/msp/config.yaml"
  infoln "Generating the peer0-tls certificates, use --csr.hosts to specify Subject Alternative Names"
  set -x
  ../../bin/fabric-ca-client enroll -u https://peer0:peer0pw@localhost:$(($portNumber + 3)) --caname ca-${nameOfTheOrg} -M "${PWD}/../organizations/peerOrganizations/${nameOfTheOrg}.example.com/peers/peer0.${nameOfTheOrg}.example.com/tls" --enrollment.profile tls --csr.hosts peer0.${nameOfTheOrg}.example.com --csr.hosts localhost --tls.certfiles "${PWD}/fabric-ca/${nameOfTheOrg}/tls-cert.pem"
  { set +x; } 2>/dev/null
  cp "${PWD}/../organizations/peerOrganizations/${nameOfTheOrg}.example.com/peers/peer0.${nameOfTheOrg}.example.com/tls/tlscacerts/"* "${PWD}/../organizations/peerOrganizations/${nameOfTheOrg}.example.com/peers/peer0.${nameOfTheOrg}.example.com/tls/ca.crt"
  cp "${PWD}/../organizations/peerOrganizations/${nameOfTheOrg}.example.com/peers/peer0.${nameOfTheOrg}.example.com/tls/signcerts/"* "${PWD}/../organizations/peerOrganizations/${nameOfTheOrg}.example.com/peers/peer0.${nameOfTheOrg}.example.com/tls/server.crt"
  cp "${PWD}/../organizations/peerOrganizations/${nameOfTheOrg}.example.com/peers/peer0.${nameOfTheOrg}.example.com/tls/keystore/"* "${PWD}/../organizations/peerOrganizations/${nameOfTheOrg}.example.com/peers/peer0.${nameOfTheOrg}.example.com/tls/server.key"
  
  mkdir "${PWD}/../organizations/peerOrganizations/${nameOfTheOrg}.example.com/msp/tlscacerts"
  cp "${PWD}/../organizations/peerOrganizations/${nameOfTheOrg}.example.com/peers/peer0.${nameOfTheOrg}.example.com/tls/tlscacerts/"* "${PWD}/../organizations/peerOrganizations/${nameOfTheOrg}.example.com/msp/tlscacerts/ca.crt"

  mkdir -p "${PWD}/../organizations/peerOrganizations/${nameOfTheOrg}.example.com/tlsca"
  cp "${PWD}/../organizations/peerOrganizations/${nameOfTheOrg}.example.com/peers/peer0.${nameOfTheOrg}.example.com/tls/tlscacerts/"* "${PWD}/../organizations/peerOrganizations/${nameOfTheOrg}.example.com/tlsca/tlsca.${nameOfTheOrg}.example.com-cert.pem"

  mkdir -p "${PWD}/../organizations/peerOrganizations/${nameOfTheOrg}.example.com/ca"
  cp "${PWD}/../organizations/peerOrganizations/${nameOfTheOrg}.example.com/peers/peer0.${nameOfTheOrg}.example.com/msp/cacerts/"* "${PWD}/../organizations/peerOrganizations/${nameOfTheOrg}.example.com/ca/ca.${nameOfTheOrg}.example.com-cert.pem"

  infoln "Generating the user msp"
  set -x
  ../../bin/fabric-ca-client enroll -u https://user1:user1pw@localhost:$(($portNumber + 3)) --caname ca-${nameOfTheOrg} -M "${PWD}/../organizations/peerOrganizations/${nameOfTheOrg}.example.com/users/User1@${nameOfTheOrg}.example.com/msp" --tls.certfiles "${PWD}/fabric-ca/${nameOfTheOrg}/tls-cert.pem"
  { set +x; } 2>/dev/null

  cp "${PWD}/../organizations/peerOrganizations/${nameOfTheOrg}.example.com/msp/config.yaml" "${PWD}/../organizations/peerOrganizations/${nameOfTheOrg}.example.com/users/User1@${nameOfTheOrg}.example.com/msp/config.yaml"

  infoln "Generating the org admin msp"
  set -x
  ../../bin/fabric-ca-client enroll -u https://${nameOfTheOrg}admin:${nameOfTheOrg}adminpw@localhost:$(($portNumber + 3)) --caname ca-${nameOfTheOrg} -M "${PWD}/../organizations/peerOrganizations/${nameOfTheOrg}.example.com/users/Admin@${nameOfTheOrg}.example.com/msp" --tls.certfiles "${PWD}/fabric-ca/${nameOfTheOrg}/tls-cert.pem"
  { set +x; } 2>/dev/null

  cp "${PWD}/../organizations/peerOrganizations/${nameOfTheOrg}.example.com/msp/config.yaml" "${PWD}/../organizations/peerOrganizations/${nameOfTheOrg}.example.com/users/Admin@${nameOfTheOrg}.example.com/msp/config.yaml"


