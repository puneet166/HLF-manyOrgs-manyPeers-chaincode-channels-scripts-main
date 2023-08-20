cd ../
# Check if the current directory is "test-network"
if [ "$(basename "$(pwd)")" != "test-network" ]; then
    echo "Error: This script should be executed in the 'test-network' directory."
    exit 1
fi

export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=${PWD}/configtx

# export FABRIC_CFG_PATH=$PWD/../config/


# Navigate to the parent directory
#!/bin/bash

# List of channel names
channel_names=(
    "SubhraOnly"
)

# Loop through each channel name and run the command
for channel_name in "${channel_names[@]}"; do
    echo "Working on channel: $channel_name"
    echo "line no 25"
    lowercase_channel_name=$(echo "$channel_name" | tr '[:upper:]' '[:lower:]') 
    echo "line no 27"  
    configtxgen -profile  $channel_name -outputBlock "./channel-artifacts/${lowercase_channel_name}.block" -channelID "$lowercase_channel_name"
    echo "line no 29"
    export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
    echo "line no 31"
    export ORDERER_ADMIN_TLS_SIGN_CERT=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt
    echo "line no 33"
    export ORDERER_ADMIN_TLS_PRIVATE_KEY=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.key
    echo "line no 35"
    osnadmin channel join --channelID "$lowercase_channel_name" --config-block "./channel-artifacts/${lowercase_channel_name}.block" -o localhost:7053 --ca-file "$ORDERER_CA" --client-cert "$ORDERER_ADMIN_TLS_SIGN_CERT" --client-key "$ORDERER_ADMIN_TLS_PRIVATE_KEY"
    osnadmin channel list -o localhost:7053 --ca-file "$ORDERER_CA" --client-cert "$ORDERER_ADMIN_TLS_SIGN_CERT" --client-key "$ORDERER_ADMIN_TLS_PRIVATE_KEY"

    echo "Completed for channel: $channel_name"
done




# Print a message indicating successful execution
echo "Script completed successfully!"