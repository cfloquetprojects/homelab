#!/bin/bash
# Charlie Floquet 8/3/21

### Script Requisites ###
# - This script is designed to be run on Ubuntu 20.04 LTS Core Systems with a network connection
# - Allow the bash script to be executable
#  -> chmod +x zeekKickoff.bash
# - We will be using the GeoLite2 database for geolocating IP addresses. 
#  -> Ensure that GeoLite2*.tar.gz file is present in your current working directory. 
# - Change the owner of the script to be the specific named user
#  -> chown userName:users zeekkickoff.bash
# - Lastly, if the script is complaining about ^M (carriage return) characters fix it with the line below:
#  -> sed -i -e 's/\r$//' zeekKickoff.bash

##### ZEEK Admin User Creation #####

#add the zeek user so we can assign it to install dir later
#echo "[+] Creating Zeek administrative user..."
# using -g lets add zeek to the sudoers group, and give it a home directory
# - sudo useradd -m -s $(which bash) -g sudo zeek
#echo "Please set Zeek management password: "
# - sudo passwd zeek
#enable permissions for zeek in install directory
# - 
# - sudo su - zeek

echo "[+] Fetching Updates..."

##### Install Pre-Requisite Packages and Updates #####


##### Extract GeoLite2 and Copying .mmdb  #####

echo "[+] Extracting GeoLite2 City..."
sudo tar --extract --verbose --gunzip --file GeoLite*
sudo mkdir --parents /usr/share/GeoIP
sudo cp GeoLite2-City_20210914/GeoLite2-City.mmdb /usr/share/GeoIP/
echo "[+] Extracted GeoLite2 City and Copied .mmdb file to /usr/share/GeoIP/"

# Install Zeek from Binaries
# fetch the .repo file from opensuse.org
#echo 'deb http://download.opensuse.org/repositories/security:/zeek/xUbuntu_20.04/ /' | sudo tee /etc/apt/sources.list.d/security:zeek.list
# add zeeks gpg key for installation verification
#sudo curl -fsSL https://download.opensuse.org/repositories/security:zeek/xUbuntu_20.04/Release.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/security_zeek.gpg > /dev/null
# move the repo config file to the proper directory
#sudo mv security:zeek.repo /etc/yum.repos.d/
# now with the repo in place we can install zeek
#sudo apt -y install zeek

echo "[+] Successfully Install Zeek Requisite Packages & Updates"

##### Installing Zeek from Source Code using cmake #####
# install requisite software for a source code install
sudo apt -y --fix-broken install
sudo apt -y update
sudo apt -y upgrade
sudo apt -y install cmake make gcc g++ flex bison libpcap-dev gdb libssl-dev python-dev swig zlib1g-dev libmaxminddb-dev build-essential python3-dev net-tools sendmail
sudo git clone --recursive https://github.com/zeek/zeek
cd zeek/
sudo make distclean && sudo ./configure --with-geoip=/usr/share/GeoIP
sudo make && sudo make install
sudo chown -R zeek.zeek /usr/local/zeek/
echo "[+] Creating Symbolic Links..."
sudo ln --symbolic /usr/local/zeek/bin/zeek /usr/bin/zeek
sudo ln --symbolic /usr/local/zeek/bin/zeekctl /usr/bin/zeekctl

echo "[+] Adding Zeek to $PATH variable..."
sudo echo "export PATH=$PATH:/usr/local/zeek/bin" >> ~/.bashrc

iterate="1"

echo "---------- Begin Zeek Configuration ----------"

while [[ "$iterate" == "1" ]]
do
#give option for method of deployment

read -p "Standalone (S) or Clustered (C) configuration? " config

if [[ "$config" == "S" ]]
then
   #end the while loop
   iterate="0"
   ## Enter Standalone Configuration

   echo "[+] Successfully Entered Standalone Configuration..."

   ## Add networks to monitor in networks.cfg

   read -p "What is the network address you would like to monitor? (eg: 10.0.0.0/24): " networkID
   #add our desired network to monitor on our standalone device
   echo $networkID | sudo tee /usr/local/zeek/etc/networks.cfg -a

   echo "Enter the specific interface id you'd like to monitor (eg: ens160, eth0, etc): " int
   #use some regex to replace the original line with the provided interface
   sed -i "s/eth0/$int/g" /usr/local/zeek/etc/node.cfg
   echo "[+] Completed Zeek Standalone Setup"
fi

if [[ "$config" == "C" ]]

then
   iterate="0"
   ## Enter Clustered Configuration
   #create the temporary node.cfg.temp file we will use to add config to
   touch /usr/local/zeek/etc/node.cfg.temp
   echo "-- Please choose the role of this device within Clustered Configuration:"
   echo "- Manager (M)"
   echo "- Worker (W)"
   read -p "Role to configure on this host [W/M]: " role
   if [[ "$role" == "W" ]]
   then
      read -p "Interface to monitor (eg: ens192, eth0, etc): " workerInt
      #create a systemd service allowing zeek to run promiscous mode on boot
	  zeekUnit="#\n[Unit]\nDescription=Allow Zeek Monitoring on Boot\nAfter=network.target
	  \n#\n[Service]\nType=oneshot\nExecStart=/usr/sbin/ip link set dev $workerInt promisc on\nTimeOutStartSec=0\nRemainAfterExit=yes\n#\n[Install]\nWantedBy=default.target"
      # create service that activates monitoring for chosen interface on boot
	  echo -e $zeekUnit | sudo tee /etc/systemd/system/promisc.service
	  #allow promisc.service to be run on boot, ignoring umask
	  sudo chmod u+x /etc/systemd/system/promisc.service
	  sudo systemctl daemon-reload
	  #enable and start the network interface promiscous mode service
	  sudo systemctl enable promisc
	  sudo systemctl start promisc
	  echo "[+] Promiscuous Mode Enabled on "$workerInt":"
	  sudo ip addr | grep PROMISC
   # begin management configuration
   fi 
   if [[ "$role" == "M" ]]
   then
	  echo "[+] Successfully entered Zeek Cluster Manager Configuration..."
	  # create temporary file to store our configurations
      touch /usr/local/zeek/etc/node.cfg.temp
	  #begin the manager node config
      read -p "What would you like your manager node to be named? (eg: man-zeek): " manager
      read -p "What is the IPv4 Address of "$manager"? (eg: 10.0.2.10): " managerIPv4
	  # fetch networks to monitor on all sensors
	  read -p "How many different subnets will be monitored? " numNetworks
	  # clear the existing config for networks.cfg
	  > test.txt
	  # create a simple for loop for adding several networks to the networks.cfg file
	  for i in $( eval echo {1..$numNetworks} )
      do
	     #add our desired network to monitor on our standalone device, replacing existing file
		 read -p "Network ID (and CIDR) of Subnet #"$i": " networkID
         echo $networkID | sudo tee /usr/local/zeek/etc/networks.cfg -a
	  done
	  read -p "Would you like to enable logger mode? [Y/N]: " loggerMode
	  if [[ "$confirm" == "Y" ]]
      then
	     #add the logger, which we can configure later for larger log storage if needed
	     loggerAdd="#\n[logger-zeek]\ntype=logger\nhost=$managerIPv4"
		 #overwrite existing file, if there is one
	     echo -e $loggerAdd | sudo tee /usr/local/zeek/etc/node.cfg.temp 
      else
	     #add the logger, commented out
	     loggerAddCommented="#\n#[logger-zeek]\n#type=logger\n#host=$managerIPv4"
		 #overwrite the existing file, if there is one
	     echo -e $loggerAddCommented | sudo tee /usr/local/zeek/etc/node.cfg.temp
	  fi
	  #add the manager configuration to our blank node.cfg.temp file
	  managerAdd="#\n[$manager]\ntype=manager\nhost=$managerIPv4\ninterface=$managerInt"
	  echo -e $managerAdd | sudo tee /usr/local/zeek/etc/node.cfg.temp -a
	  #add local zeek proxy here, note to add offloading proxies here in the future
	  proxyAdd="#\n[proxy-zeek]\ntype=proxy\nhost=$managerIPv4"
	  echo -e $proxyAdd | sudo tee /usr/local/zeek/etc/node.cfg.temp -a
	  #generate public/private key pair for managing workers and store it under zeek
	  mkdir -p /home/zeek/.ssh 
      #zeek requires us to use blank keys for managing workers
      ssh-keygen -b 2048 -t rsa -f /home/zeek/.ssh/id_rsa -q -N ""
      echo "[+] Generated public/private key pair successfully"
	  # begin worker configuration
      read -p "How many worker nodes are in this cluster? " workerCount
      # create a for loop to iterate and add workers
	  for i in $( eval echo {1..$workerCount} )
      do
		 read -p "Name of worker "$i": (eg: dmz-worker): " worker 
		 read -p "Sensor Interface on "$worker": " workerInt 
		 read -p "Management IPv4 Address of "$worker": " workerMgmt
		 #copy ssh public id to worker sensor
		 ssh-copy-id zeek@$workerMgmt
         # The line below adds the config options to node.cfg
         workerAdd="#\n[$worker]\ntype=worker\nhost=$workerMgmt\ninterface=$workerInt"
		 echo -e $workerAdd | sudo tee /usr/local/zeek/etc/node.cfg.temp -a
		 #copy the generated public key (id_rsa.pub) over to our dmz-sensor host for later authentication
	     ssh-copy-id zeek@$workerManagement
	  done
	  sudo cat /usr/local/zeek/etc/node.cfg.temp
	  #double check configuration before overwriting node.cfg
	  read -p "Please confirm the configuration setup before overwriting node.cfg [Y/N]: " confirm
	  if [[ "$confirm" == "Y" ]]
	  then
		 #overwrite node.cfg 
		 mv /usr/local/zeek/etc/node.cfg.temp /usr/local/zeek/etc/node.cfg
		 #append a line to our local.zeek file changing our log format to json for Splunk
	  else
		  echo "[-] Exiting Zeek Automated Install & Config..."
	      exit
      fi
   fi
fi
done

# add json-logs load policy for easy exporting to splunk 
sudo echo "@load policy/tuning/json-logs" | sudo tee /usr/local/zeek/share/zeek/site/local.zeek -a
# add administrator email to zeekctl.cfg
read -p "Configure Zeek Management Email Address? " emailPreference
if [[ "$confirm" == "Y" ]]
then
   # retrieve desired administrator email
   read -p "Zeek Administrator Email Address: " adminEmail
   # replace existing configuration with adminEmail using sed
   sudo sed -i "s/MailTo = root@localhost/MailTo = $adminEmail/g" /usr/local/zeek/etc/zeekctl.cfg
else
   # set the mail server to send mail to our zeek user rather than root
   sudo sed -i "s/MailTo = root@localhost/MailTo = zeek@localhost/g" /usr/local/zeek/etc/zeekctl.cfg
fi
#change the log rotation interval to once every 86400 seconds or 24 hours
read -p "Log Rotation Interval (3600, 86400, etc.): " logRotation
sudo sed -i "s/LogRotationInterval = 3600/LogRotationInterval = $logRotation/g" /usr/local/zeek/etc/zeekctl.cfg
#check one last time to make sure we've got correct permissions
sudo chmod -R zeek.zeek /usr/local/zeek

# set the capabilities of zeek folders, allowing them access to the monitoring interface
sudo setcap cap_net_raw,cap_net_admin=eip /usr/local/zeek/bin/zeek
sudo setcap cap_net_raw,cap_net_admin=eip /usr/local/zeek/bin/zeekctl
# set proper permissions
sudo chown -R zeek.zeek /usr/local/zeek/

echo "[+] Adding firewall rules to allow remote management:"
sudo ufw allow ssh
sudo ufw enable
sudo ufw allow 47761
sudo ufw allow 47762

echo "[+] Ready to Deploy Zeek Network Security Monitor!"
#zeekctl deploy