#!/bin/bash
# Charlie Floquet 11/5/2021

# run the wireguard-tools json script to generate a json 
./wg-json > log.json

# use sed -i option to edit file in place, trim out VPN server private key
sed -i 's/\("privateKey": "\).*\(",\)/\1\2/' log.json

# use sed -i option to edit file in place, trim out client pre-shared keys
sed -i 's/\("presharedKey": "\).*\(",\)/\1\2/' log.json

# retrieve date for logkeeping purposes:
dt=$(date '+%m.%d.%Y-%H:%M:%S')

# define the absolute path for where we will be storing our logs before forwarding
logPath="/var/log/wireguard/$dt-log.json"

cp log.json $logPath
