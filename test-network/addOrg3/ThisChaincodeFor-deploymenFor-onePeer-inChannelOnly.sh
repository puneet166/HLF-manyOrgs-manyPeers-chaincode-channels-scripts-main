# This chaincode deployment file like this senerio -
# You have created a new org name - "student" with single peer that is "peero" and create a new channel in student that is "studentOnly"
# org - student
# channel - studentonly
# peers - peer0 in student
# want to deploy chaincode on peer0 in studentonly channel"

#!/bin/bash

if [ $# -ne 6 ]; then
    echo "Usage: $0 <nameOfTheOrg> <portNumber> <channelName> <chaincodelan> <path> <nameOfChainCode>"
    exit 1
fi
cd .. 
orgName="$1"
portNumber="$2"
channelName="$3"
chaincodeLan="$4"
pathOfChainCode="$5"
nameOfChaincode="$6"
mspID="$(tr '[:lower:]' '[:upper:]' <<< ${orgName:0:1})${orgName:1}MSP"
export PATH=${PWD}/../bin:$PATH
export CORE_PEER_TLS_ENABLED=true
export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
export PEER0_ORG1_CA=${PWD}/organizations/peerOrganizations/${orgName}.example.com/peers/peer0.${orgName}.example.com/tls/ca.crt
export FABRIC_CFG_PATH=${PWD}/../config/


CHANNEL_NAME=$channelName
CC_RUNTIME_LANGUAGE=$chaincodeLan
VERSION="1"
CC_SRC_PATH=$pathOfChainCode
CC_NAME=$nameOfChaincode
CC_INIT_FCN=${7:-"NA"}


setGlobalsForOrderer() {
    export CORE_PEER_LOCALMSPID="OrdererMSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/ordererOrganizations/example.com/users/Admin@example.com/msp

}

setGlobalsForPeer0Org1() {
    # export CORE_PEER_TLS_ENABLED=true
    # echo "line no 43 $mspID"
    export CORE_PEER_LOCALMSPID="$mspID"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/${orgName}.example.com/peers/peer0.${orgName}.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/${orgName}.example.com/users/Admin@${orgName}.example.com/msp
    export CORE_PEER_ADDRESS=localhost:${portNumber}
    
}


CC_RUNTIME_LANGUAGE=$(echo "$CC_RUNTIME_LANGUAGE" | tr [:upper:] [:lower:])
# echo "line no 79 $CC_RUNTIME_LANGUAGE"
# do some language specific preparation to the chaincode before packaging
if [ "$CC_RUNTIME_LANGUAGE" = "go" ]; then
  CC_RUNTIME_LANGUAGE=golang

  echo "Vendoring Go dependencies at $CC_SRC_PATH"
  echo "path current $PWD"
  pushd $CC_SRC_PATH
  GO111MODULE=on go mod vendor
  popd
  echo "Finished vendoring Go dependencies"

elif [ "$CC_RUNTIME_LANGUAGE" = "java" ]; then
  CC_RUNTIME_LANGUAGE=java

  rm -rf $CC_SRC_PATH/build/install/
  echo "Compiling Java code..."
  pushd $CC_SRC_PATH
  ./gradlew installDist
  popd
  echo "Finished compiling Java code"
  CC_SRC_PATH=$CC_SRC_PATH/build/install/$CC_NAME

elif [ "$CC_RUNTIME_LANGUAGE" = "javascript" ]; then
  CC_RUNTIME_LANGUAGE=node

elif [ "$CC_RUNTIME_LANGUAGE" = "typescript" ]; then
  CC_RUNTIME_LANGUAGE=node

  echo "Compiling TypeScript code into JavaScript..."
  pushd $CC_SRC_PATH
  npm install
  npm run build
  popd
  echo "Finished compiling TypeScript code into JavaScript"

else
  echo "The chaincode language ${CC_RUNTIME_LANGUAGE} is not supported by this script. Supported chaincode languages are: go, java, javascript, and typescript"
  exit 1
fi



# presetup() {
#     echo Vendoring Go dependencies ...
#     echo "linr no 80 $pathOfChainCode"
#     pushd $pathOfChainCode
#     GO111MODULE=on go mod vendor
#     popd
#     echo Finished vendoring Go dependencies
# }
# presetup


packageChaincode() {
    echo "line no 89"
    rm -rf ${CC_NAME}.tar.gz
    setGlobalsForPeer0Org1
    echo "line no 92  $CC_SRC_PATH $CC_RUNTIME_LANGUAGE $CC_NAME $VERSION"
    


    peer lifecycle chaincode package ${CC_NAME}.tar.gz \
        --path ${CC_SRC_PATH} --lang ${CC_RUNTIME_LANGUAGE} \
        --label ${CC_NAME}_${VERSION}
    echo "line no 98"
    PACKAGE_ID=$(peer lifecycle chaincode calculatepackageid ${CC_NAME}.tar.gz)

    echo "===================== Chaincode is packaged on peer0.org1 ===================== "
}
# packageChaincode

installChaincode() {
    setGlobalsForPeer0Org1
    peer lifecycle chaincode install ./${CC_NAME}.tar.gz
    echo "===================== Chaincode is installed on peer0.org1 ===================== "

  
}

# installChaincode

queryInstalled() {
    setGlobalsForPeer0Org1
    peer lifecycle chaincode queryinstalled >&log.txt
    cat log.txt
    PACKAGE_ID=$(sed -n "/${CC_NAME}_${VERSION}/{s/^Package ID: //; s/, Label:.*$//; p;}" log.txt)
    echo PackageID is ${PACKAGE_ID}
    echo "===================== Query installed successful on peer0.org1 on channel ===================== "
}


approveForMyOrg1() {
    setGlobalsForPeer0Org1
   
    peer lifecycle chaincode approveformyorg -o localhost:7050 \
        --ordererTLSHostnameOverride orderer.example.com --tls \
        --cafile $ORDERER_CA --channelID $CHANNEL_NAME --name ${CC_NAME} --version ${VERSION} \
        --package-id ${PACKAGE_ID} \
        --sequence ${VERSION}
    # set +x

    echo "===================== chaincode approved from org 1 ===================== "

}

getBlock() {
    setGlobalsForPeer0Org1
   
    peer channel getinfo  -c $CHANNEL_NAME -o localhost:7050 \
        --ordererTLSHostnameOverride orderer.example.com --tls \
        --cafile $ORDERER_CA
}



checkCommitReadyness() {
    setGlobalsForPeer0Org1
    peer lifecycle chaincode checkcommitreadiness  --channelID $CHANNEL_NAME --name ${CC_NAME} --version ${VERSION} --sequence ${VERSION} --output json

    echo "===================== checking commit readyness from org 1 ===================== "
}



commitChaincodeDefination() {
    setGlobalsForPeer0Org1
   
    peer lifecycle chaincode commit -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com \
        --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA \
        --channelID $CHANNEL_NAME --name ${CC_NAME} --peerAddresses localhost:$portNumber --tlsRootCertFiles $PEER0_ORG1_CA --version ${VERSION} --sequence ${VERSION}
     

}

# commitChaincodeDefination

queryCommitted() {
    echo "line no 220"
    setGlobalsForPeer0Org1
    peer lifecycle chaincode querycommitted --channelID $CHANNEL_NAME --name ${CC_NAME}
    echo "line no 223"

}

# queryCommitted

chaincodeInvokeInit() {
    setGlobalsForPeer0Org1
    fcn_call='{"function":"'${CC_INIT_FCN}'","Args":[]}'


    peer chaincode invoke -o localhost:7050 \
        --ordererTLSHostnameOverride orderer.example.com \
        --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA \
        -C $CHANNEL_NAME -n ${CC_NAME} \
        --peerAddresses localhost:$portNumber --tlsRootCertFiles $PEER0_ORG1_CA  -c '{"function":"CreateAsset","Args":["asset1", "blue", "2","puneet","300"]}'
        # --peerAddresses localhost:9051 --tlsRootCertFiles $PEER0_ORG2_CA \

}

# chaincodeInvokeInit

chaincodeInvoke() {
  
    setGlobalsForPeer0Org1

    
    ## Init ledger
    peer chaincode invoke -o localhost:7050 \
        --ordererTLSHostnameOverride orderer.example.com \
        --tls $CORE_PEER_TLS_ENABLED \
        --cafile $ORDERER_CA \
        -C $CHANNEL_NAME -n ${CC_NAME} \
        --peerAddresses localhost:$portNumber --tlsRootCertFiles $PEER0_ORG1_CA \
        -c '{"function": "initLedger","Args":[]}'

    ## Add private data
    export CAR=$(echo -n "{\"key\":\"1111\", \"make\":\"Tesla\",\"model\":\"Tesla A1\",\"color\":\"White\",\"owner\":\"pavan\",\"price\":\"10000\"}" | base64 | tr -d \\n)
    peer chaincode invoke -o localhost:7050 \
        --ordererTLSHostnameOverride orderer.example.com \
        --tls $CORE_PEER_TLS_ENABLED \
        --cafile $ORDERER_CA \
        -C $CHANNEL_NAME -n ${CC_NAME} \
        --peerAddresses localhost:$portNumber --tlsRootCertFiles $PEER0_ORG1_CA \
        -c '{"function": "createPrivateCar", "Args":[]}' \
        --transient "{\"car\":\"$CAR\"}"
}

# chaincodeInvoke

chaincodeQuery() {
    setGlobalsForPeer0Org1
    peer chaincode query -C $CHANNEL_NAME -n ${CC_NAME} -c '{"function": "GetAllAssets","Args":[""]}'
   
}



packageChaincode
installChaincode
queryInstalled
approveForMyOrg1
checkCommitReadyness

commitChaincodeDefination
queryCommitted
chaincodeInvokeInit

sleep 3
chaincodeQuery
