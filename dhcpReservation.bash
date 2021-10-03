#!/bin/bash
# BASH Script to Add New DHCP Reservations

read -p "Hostname of New IPv4 Reservation: " hostname

read -p "Desired IPv4 Address: " desiredIPv4

read -p "MAC Address: " mac

addConf="#\nhost $hostname {\nhardware ethernet $mac;\nfixed-address $desiredIPv4;\n}"
# add this to the existing reservations within the privileged access .conf file
sudo echo -e $addConf | sudo tee /etc/dhcp/dhcpd.conf -a

addLease="#\nlease $desiredIPv4 {\nbinding state active;\nreserved;\nhardware ethernet $mac;\n}"
# add this to the existing reservations within the privileged access .leases file
sudo echo -e $addLease | sudo tee /etc/dhcp/dhcpd.leases -a

sudo systemctl restart dhcpd

echo "[+] Added DHCP Reservation for $hostname at $desiredIPv4 Address"

