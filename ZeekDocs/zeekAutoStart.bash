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

echo "[+] Fetching Updates..."

##### Install Pre-Requisite Packages and Updates #####
sudo apt -y -update
sudo apt -y upgrade
echo "[+] Installing Requisite Software..."
sudo apt-get -y install cmake make gcc g++ flex bison libpcap-dev libssl-dev python-dev swig zlib1g-dev libmaxminddb-dev build-essential python3-dev net-tools

echo "[+] Successfully Install Requisite Packages & Updates"

##### Extract GeoLite2 and Copying .mmdb  #####

echo "[+] Extracting GeoLite2 City..."
sudo tar --extract --verbose --gunzip --file GeoLite*
sudo mkdir --parents /usr/share/GeoIP
sudo cp GeoLite2-City_20210914/GeoLite2-City.mmdb /usr/share/GeoIP/
echo "[+] Extracted GeoLite2 City and Copied .mmdb file to /usr/share/GeoIP/"

##### Installing Zeek using cmake #####

sudo git clone --recursive https://github.com/zeek/zeek

cd zeek/
sudo make distclean && sudo ./configure --with-geoip=/usr/share/GeoIP
sudo make && sudo make install

echo "[+] Creating Symbolic Links..."
sudo ln --symbolic /usr/local/zeek/bin/zeek /usr/bin/zeek
sudo ln --symbolic /usr/local/zeek/bin/zeekctl /usr/bin/zeekctl

echo "[+] Adding Zeek to $PATH variable..."
sudo echo "export PATH=$PATH:/usr/local/zeek/bin" >> ~/.bashrc

##### ZEEK Admin User Creation #####

#add the zeek user so we can assign it to install dir later
echo "[+] Creating Zeek administrative user..."
sudo useradd -aG sudo zeek 
echo "Please set Zeek management password: "
sudo passwd zeek
#enable permissions for zeek in install directory
chown -R zeek.zeek /usr/local/zeek
echo "[+] Successfully entered Clustered Configuration..."
sudo su zeek
#generate public/private key pair for managing workers 
#zeek requires us to use blank keys for managing workers
ssh-keygen -b 2048 -t rsa -f /tmp/sshkey -q -N ""
echo "[+] Generated public/private key pair successfully"

iterate="1"

echo "---------- Begin Zeek Configuration ----------"

while [[ "$iterate" == "1" ]]

do

echo "Standalone (S) or Clustered (C) configuration?"

read config
echo $config

if [[ "$config" == "S" ]]
then
   #end the while loop
   iterate="0"
   ## Enter Standalone Configuration

   echo "[+] Successfully Entered Standalone Configuration..."

   ## Add networks to monitor in networks.cfg

   echo "What is the network address you would like to monitor? (eg: 10.0.0.0/24)"

   read networkID
   #add our desired network to monitor on our standalone device
   sudo echo $networkID | sudo tee /usr/local/zeek/etc/networks.cfg -a

   echo "Enter the specific interface id you'd like to monitor (eg: ens160, eth0, etc)"

   read int
   #use some regex to replace the original line with the provided interface
   sudo sed -i "s/eth0/$int/g" /usr/local/zeek/etc/node.cfg
fi

if [[ "$config" == "C" ]]

then
   iterate="0"
   ## Enter Clustered Configuration
   
   echo "-- Please choose the role of this device within Clustered Configuration:"
   echo "- Manager (M)"
   echo "- Worker (W)"
   read role
   if [[ "$role" == "W" ]]
   then
      #enter worker configuration
	  echo "Name of worker:"
	  read worker
	  echo "Interface to monitor on "$worker":"
	  read workerInt
	  echo "IPv4 Address of "$worker":"
	  read workerIPv4
	  #set the capabilities of zeek folders
	  sudo setcap cap_net,cap_net_admin=eip /usr/local/zeek/etc/zeek
	  sudo setcap cap_net,cap_net_admin=eip /usr/local/zeek/etc/zeekctl
	  #create a systemd service allowing zeek to run promiscous mode on boot
	  zeekUnit="#\n[Unit]\nDescription=Allow Zeek Monitoring on Boot\nAfter=network.target
	  \n#\n[Service]\nType=oneshot\nExecStart=/usr/sbin/ip link set dev $workerInt promisc on\n
	  TimeOutStartSec=0\nRemainAfterExit=yes\n#\n[Install]\nWantedBy=default.target"
	  sudo echo -e $zeekUnit | sudo tee /etc/systemd/system/promisc.service
	  #allow promisc.service to be run on boot, ignoring umask
	  sudo chmod u+x /etc/systemd/system/promisc.service
	  sudo systemctl daemon-reload
	  sudo systemctl enable promisc
	  sudo systemctl start promisc
	  echo "[+] Promiscuous Mode Enabled on $workerInt:"
	  ip.addr | grep $workerInt
   fi 
      useradd 
   if [[ "$role" == "M" ]]
   then
      #Begin Management configuration
	  echo "[+] Successfully entered Zeek Cluster Manager Configuration..."
	  #create a temporary file to insert our new configuration into
	  sudo touch /usr/local/zeek/etc/node.cfg.backup
	  echo "Would you like to enable logger mode? [Y/N]"
	  read loggerMode
	  if [[ "$confirm" == "Y" ]]
      then
	     #add the logger, which we can configure later for larger log storage if needed
	     loggerAdd="#\n[logger-zeek]\ntype=logger\nhost=localhost"
	     sudo echo -e $loggerAdd | sudo tee /usr/local/zeek/etc/node.cfg.backup -a
      else
	     #add the logger, commented out
	     loggerAddCommented="#\n#[logger-zeek]\n#type=logger\n#host=localhost"
	     sudo echo -e $loggerAddCommented | sudo tee /usr/local/zeek/etc/node.cfg.backup -a
	  fi
	  #begin the manager node config
      echo "What would you like your manager node to be named? (eg: man-zeek):"
      read manager
      echo "What is the IPv4 Address of "$manager"? (eg: 10.0.2.10)"
      read managerIPv4
	  echo "Interface to monitor on "$manager"?"
	  read managerInt
	  #add the manager configuration to our blank node.cfg.backup file
	  managerAdd="#\n[$manager]\ntype=manager\nhost=$managerIPv4\ninterface=$managerInt"
	  sudo echo -e $managerAdd | sudo tee /usr/local/zeek/etc/node.cfg.backup -a
	  #add local zeek proxy here, note to add offloading proxies here in the future
	  proxyAdd="#\n[proxy-zeek]\ntype=proxy\nhost=$managerIPv4"
	  sudo echo -e $proxyAdd | sudo tee /usr/local/zeek/etc/node.cfg.backup -a
	  # begin worker configuration
	  echo "How many worker nodes (networks) would you like to monitor?:"
      read workerCount
      # create a for loop to iterate and add workers
	  for i in $( eval echo {1..$workerCount} )
      do
		 echo "Name of worker "$i": (eg: dmz-worker)"
		 read worker
		 echo "IPv4 Address of "$worker1":"
		 read workerIPv4
		 echo "Interface to monitor on "$worker1":"
		 read workerInt
		 echo "Management IPv4 Address of "$worker1":"
		 read workerMgmt
		 #switch into zeek user to copy ssh id
		 sudo su - zeek
		 #copy ssh public id to worker sensor
		 ssh-copy-id zeek@$workerMgmt
         # The line below adds the config options to node.cfg
         workerAdd="#\n[$worker]\ntype=worker\nhost=$workerIPv4\ninterface=$workerInt"
		 sudo echo -e $workerAdd | sudo tee /usr/local/zeek/etc/node.cfg.backup -a
	  done
   fi
   sudo cat /usr/local/zeek/etc/node.cfg.backup
   #double check configuration before overwriting node.cfg
   echo "Please confirm the configuration setup before overwriting node.cfg [Y/N]:"
   read confirm
   if [[ "$confirm" == "Y" ]]
   then
      #overwrite node.cfg 
	  sudo mv /usr/local/zeek/etc/node.cfg.backup /usr/local/zeek/etc/node.cfg
	  #append a line to our local.zeek file changing our log format to json for Splunk
   else
      echo "[-] Exiting Zeek Automated Install & Config..."
	  exit
   fi
fi
done
sudo echo "@load policy/tuning/json-logs" | sudo tee /usr/local/zeek/share/zeek/site/local.zeek -a
#add administrator email to zeekctl.cfg
echo "Zeek Administrator Email Address (optional): "
read adminEmail
sudo sed -i "s/MailTo = root@localhost/MailTo = $adminEmail/g" /usr/local/zeek/etc/zeekctl.cfg
#change the log rotation interval to once every 86400 seconds or 24 hours
echo "Log Rotation Interval (3600, 86400, etc.): "
read logRotation
sudo sed -i "s/LogRotationInterval = 3600/LogRotationInterval = $logRotation/g" /usr/local/zeek/etc/zeekctl.cfg

echo "[+] Adding firewall rules to allow remote management:"
sudo ufw allow ssh
sudo ufw enable
sudo ufw allow 47761
sudo ufw allow 47762

echo "[+] Ready to Deploy Zeek Network Security Monitor!"
zeekctl deploy