#!/bin/vbash

run=/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper

echo "[+] Starting EdgeRouter Automated Kickoff..."


#######  User Input / Configuration #####
echo "  - Desired hostname: "
read hostName
echo " Desired Upstream Gateway Address: "
read gatewayIP
echo "  - Please set a new username & password [default will be removed]:"
echo "Username: "
read username
echo "Password: "
## -s flag allows for 'silent' entry of pw
read -s password

#######  Begin Initial Gateway Setup & Config  #######
$run begin

#enter configuration environment

$run set system host-name $hostName
echo "[+] Hostname Set to " $hostName
$run set system login user $username authentication plaintext-password $password
echo "[+] Password Successfully Changed for " $username
$run set system login user cfloquet level admin
echo "[+] Set " $userName " to Level Admin"
$run set interfaces ethernet eth0 description WAN
echo "[+] Setting eth0 description as WAN"
$run set interfaces ethernet eth1 description LAN
echo "[+] Setting eth1 description as LAN"
$run set interfaces ethernet eth2 description DMZ
echo "[+] Setting eth0 description as DMZ"
$run set interfaces ethernet eth3 description MGMT
echo "[+] Setting eth0 description as MGMT"
$run delete interfaces ethernet eth1 address dhcp

## Define Static IP Addresses on Each interface
#LAN
$run set interfaces ethernet eth1 address 10.0.1.1/24
echo "[+] LAN interface set as 10.0.1.1/24"
#DMZ
$run set interfaces ethernet eth2 address 10.0.2.1/29
echo "[+] DMZ interface set as 10.0.2.1/29"
#MGMT
$run set interfaces ethernet eth3 address 10.0.3.1/28
echo "[+] MGMT interface set as 10.0.3.1/28"
$run set system gateway-address $gatewayIP
echo "[+] Gateway Address set as 192.168.1.1"
$run set system name-server 8.8.8.8
echo "[+] Name Server set as 8.8.8.8"

## Set UPLINK Ethernet Interface to DHCP
#$run set interfaces ethernet eth0 address dhcp

### Commit & Save

$run commit
$run save

######  End Initial Gateway Setup & Config  ########

######  Begin NAT Rules  #######

$run set service dns forwarding listen-on eth0

$run set service nat rule 5010 description "NAT from LAN to WAN"
$run set service nat rule 5010 outbound-interface eth0
$run set service nat rule 5010 source address 10.0.1.0/24
$run set service nat rule 5010 type masquerade
echo "[+] Added NAT from LAN -> WAN "

$run set service nat rule 5015 description "NAT from DMZ to WAN"
$run set service nat rule 5015 outbound-interface eth0
$run set service nat rule 5015 source address 10.0.2.0/29
$run set service nat rule 5015 type masquerade
echo "[+] Added NAT from DMZ -> WAN "

$run set service nat rule 5020 description "NAT from DMZ to LAN"
$run set service nat rule 5020 outbound-interface eth1
$run set service nat rule 5020 source address 10.0.2.0/29
$run set service nat rule 5020 type masquerade
echo "[+] Added NAT from MGMT -> LAN "

$run set service nat rule 5025 description "NAT from MGMT to WAN"
$run set service nat rule 5025 outbound-interface eth0
$run set service nat rule 5025 source address 10.0.3.0/28
$run set service nat rule 5025 type masquerade
echo "[+] Added NAT from MGMT -> WAN "

$run set service nat rule 5030 description "NAT from MGMT to DMZ"
$run set service nat rule 5030 outbound-interface eth2
$run set service nat rule 5030 source address 10.0.3.0/28
$run set service nat rule 5030 type masquerade
echo "[+] Added NAT from MGMT -> DMZ "

$run set service nat rule 5035 description "NAT from MGMT to LAN"
$run set service nat rule 5035 outbound-interface eth1
$run set service nat rule 5035 source address 10.0.3.0/28
$run set service nat rule 5035 type masquerade
echo "[+] Added NAT from MGMT -> LAN "


### Commit & Save

$run commit
$run save

######  End NAT Rules  #######

######  Begin Firewall Zone Definitions  ######
#$run set zone-policy zone WAN interface eth0
#$run set zone-policy zone LAN interface eth1
#$run set zone-policy zone DMZ interface eth2
#$run set zone-policy zone MGMT interface eth3

#####  Begin Firewall WAN Rule Creation #####

# WAN/LAN Rules
#$run set firewall name WAN-to-LAN default-action drop
#$run set firewall name WAN-to-LAN enable-default-log
#$run set firewall name LAN-to-WAN default-action drop
#$run set firewall name LAN-to-WAN enable-default-log
# WAN/DMZ Rules
#$run set firewall name WAN-to-DMZ default-action drop
#$run set firewall name WAN-to-DMZ enable-default-log
#$run set firewall name DMZ-to-WAN default-action drop
#$run set firewall name DMZ-to-WAN enable-default-log
# WAN/MGMT Rules
#$run set firewall name WAN-to-MGMT default-action drop
#$run set firewall name WAN-to-MGMT enable-default-log
#$run set firewall name MGMT-to-WAN default-action drop
#$run set firewall name MGMT-to-WAN enable-default-log

#####  Assign Created Firewall Rules to Defined Zones ####
#$run set zone-policy zone DMZ from WAN firewall name WAN-to-DMZ
#$run set zone-policy zone WAN from DMZ firewall name DMZ-to-WAN
#$run set zone-policy zone LAN from WAN firewall name WAN-to-LAN
#$run set zone-policy zone WAN from LAN firewall name LAN-to-WAN
#$run set zone-policy zone MGMT from WAN firewall name WAN-to-MGMT
#$run set zone-policy zone WAN from MGMT firewall name MGMT-to-WAN
$run commit
$run save


