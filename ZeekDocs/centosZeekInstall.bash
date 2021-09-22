#!/bin/bash
# Charlie Floquet 8/3/21

### Script Requisites ###
# - This script is designed to be run on CentOS 7 Core Systems with a network connection
# -> Zeek sensors require atleast one interface to be used for monitoring in promiscous mode, therefore assign atleast 2
# - Allow the bash script to be executable
#  -> chmod +x zeekKickoff.bash
# - We will be using the GeoLite2 database for geolocating IP addresses. 
#  -> Ensure that GeoLite2*.tar.gz file is present in your current working directory. 
# - Change the owner of the script to be the specific named user
#  -> chown userName:users centosZeekInstall.bash
# - Lastly, if the script is complaining about ^M (carriage return) characters fix it with the line below:
#  -> sed -i -e 's/\r$//' zeekKickoff.bash


##### Zeek Local User Creation #####

# using -G lets add zeek to the sudoers group, -m gives them a home directory
# - sudo useradd -m -s $(which bash) -G sudo zeek
# set a complex password for the zeek user
# - sudo passwd zeek
# change into zeek user directory
# - sudo su - zeek 

#<< Install 
##### Begin Zeek Installation #####

echo "[+] Fetching Updates..."

##### Install Pre-Requisite Packages and Updates #####
sudo yum -y update
sudo yum -y upgrade
echo "[+] Installing Requisite Software..."
sudo yum -y install wget cmake make gcc gdb net-tools rsync gcc-c++ flex bison libpcap-devel openssl-devel python3 python3-devel 
sudo yum -y install epel-release htop
# lets choose EDT timezone for consistency
sudo timedatectl set-timezone EST
# update our time from centos.pool.ntp.org
sudo systemctl stop ntpd
sudo ntpdate 0.centos.pool.ntp.org
sudo systemctl start ntpd
#sudo yum -y install python3-GitPython python3-semantic_version
echo "[+] Successfully Install Requisite Packages & Updates"

##### Extract GeoLite2 and Copying .mmdb  #####

echo "[+] Extracting GeoLite2 City..."
sudo tar --extract --verbose --gunzip --file GeoLite*
sudo mkdir --parents /usr/share/GeoIP
sudo cp GeoLite2-City_20210914/GeoLite2-City.mmdb /usr/share/GeoIP/
echo "[+] Extracted GeoLite2 City and Copied .mmdb file to /usr/share/GeoIP/"

##### Installing Zeek #####

# Install Zeek from Binaries
# fetch the .repo file from opensuse.org
sudo wget https://download.opensuse.org/repositories/security:zeek/CentOS_7/security:zeek.repo
# move the repo config file to the proper directory
sudo mv security:zeek.repo /etc/yum.repos.d/
# now with the repo in place we can install zeek
sudo yum -y install zeek

# Install Zeek Network Security Monitor from Source Code
# fetch the latest version of zeek from their git repository
#sudo git clone --recursive https://github.com/zeek/zeek
# navigate into the zeek directory to begin the installation
#cd zeek/
#sudo make distclean && sudo ./configure --with-geoip=/usr/share/GeoIP
#sudo make && sudo make install
#cd ~

echo "[+] Adding Zeek to $PATH variable..."
sudo echo "export PATH=$PATH:/opt/zeek/bin" >> ~/.bashrc

# enable permissions for zeek user in install directory
sudo chown -R zeek:zeek /opt/zeek

#Install

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
   sudo echo $networkID | sudo tee /opt/zeek/etc/networks.cfg -a

   echo "Enter the specific interface id you'd like to monitor (eg: ens160, eth0, etc): " int
   #use some regex to replace the original line with the provided interface
   sudo sed -i "s/eth0/$int/g" /opt/zeek/etc/node.cfg
   echo "[+] Completed Zeek Standalone Setup"
fi

if [[ "$config" == "C" ]]

then
   iterate="0"
   ## Enter Clustered Configuration
   #create the temporary node.cfg.temp file we will use to add config to
   sudo touch /opt/zeek/etc/node.cfg.temp
   echo "-- Please choose the role of this device within Clustered Configuration:"
   echo "- Manager (M)"
   echo "- Worker (W)"
   read -p "Role to configure on this host [W/M]: " role
   if [[ "$role" == "W" ]]
   then
      #input the worker configuration
      read -p "What is the network address you would like to monitor? (eg: 10.0.0.0/24)" networkID
      #add our desired network to monitor on our standalone device, replacing existing file
      sudo echo $networkID | sudo tee /usr/local/zeek/etc/networks.cfg 
	  # get more information about worker config 
	  read -p "Name of worker: " worker
	  read -p "Interface to monitor on "$worker": " workerInt
	  read -p "IPv4 Address of "$worker": " workerIPv4
	  read -p "Management IPv4 Address of "$worker": " workerMgmt
	  #begin the manager node config
      read -p "What would you like your manager node to be named? (eg: man-zeek): " manager
      read -p "What is the IPv4 Address of "$manager"? (eg: 10.0.2.10) " managerIPv4
	  read -p "Interface to monitor on "$manager"? " managerInt
	  #create a systemd service allowing zeek to run promiscous mode on boot
	  zeekUnit="#\n[Unit]\nDescription=Allow Zeek Monitoring on Boot\nAfter=network.target
	  \n#\n[Service]\nType=oneshot\nExecStart=/usr/sbin/ip link set dev $workerInt promisc on\nTimeOutStartSec=0\nRemainAfterExit=yes\n#\n[Install]\nWantedBy=default.target"
	  #add the new service configuration to /systemd/system to run as a service, overwrite existing service if it's there
	  sudo echo -e $zeekUnit | sudo tee /etc/systemd/system/promisc.service
	  #allow promisc.service to be run on boot, ignoring umask
	  sudo chmod u+x /etc/systemd/system/promisc.service
	  sudo systemctl daemon-reload
	  #enable and start the network interface promiscous mode service
	  sudo systemctl enable promisc
	  sudo systemctl start promisc
	  echo "[+] Promiscuous Mode Enabled on "$workerInt":"
	  sudo ifconfig | grep PROMISC
	  #add the manager configuration to our blank node.cfg.temp file
	  managerAdd="#\n[$manager]\ntype=manager\nhost=$managerIPv4\ninterface=$managerInt"
	  sudo echo -e $managerAdd | sudo tee /opt/zeek/etc/node.cfg.temp 
	  # The line below adds the config options to node.cfg
	  workerAdd="#\n[$worker]\ntype=worker\nhost=$workerIPv4\ninterface=$workerInt"
	  #do not append the following line, replace the file with the new config
	  sudo echo -e $workerAdd | sudo tee /opt/zeek/etc/node.cfg.temp -a
	  #display the current temporary node.cfg.temp file
	  read -p "Overwrite existing node.cfg configuration with "$worker" config? [Y/N]: " overwrite
	  if [[ "$overwrite" == "Y" ]]
      then
		sudo mv /opt/zeek/etc/node.cfg.temp /opt/zeek/etc/node.cfg
	  else 
	    # if they do not want to overwrite the config, than exit the program
	    exit
	  fi
   # begin management configuration
   fi 
   if [[ "$role" == "M" ]]
   then
      
	  echo "[+] Successfully entered Zeek Cluster Manager Configuration..."
	  #create a temporary file to insert our new configuration into
	  read -p "Would you like to enable logger mode? [Y/N]: " loggerMode
	  if [[ "$confirm" == "Y" ]]
      then
	     #add the logger, which we can configure later for larger log storage if needed
	     loggerAdd="#\n[logger-zeek]\ntype=logger\nhost=localhost"
		 #overwrite existing file, if there is one
	     sudo echo -e $loggerAdd | sudo tee /opt/zeek/etc/node.cfg.temp 
      else
	     #add the logger, commented out
	     loggerAddCommented="#\n#[logger-zeek]\n#type=logger\n#host=localhost"
		 #overwrite the existing file, if there is one
	     sudo echo -e $loggerAddCommented | sudo tee /opt/zeek/etc/node.cfg.temp
	  fi
	  #begin the manager node config
      read -p "What would you like your manager node to be named? (eg: man-zeek): " manager
      read -p "What is the IPv4 Address of "$manager"? (eg: 10.0.2.10)" managerIPv4
	  read -p "Interface to monitor on "$manager"? " managerInt
	  #add the manager configuration to our blank node.cfg.temp file
	  managerAdd="#\n[$manager]\ntype=manager\nhost=$managerIPv4\ninterface=$managerInt"
	  sudo echo -e $managerAdd | sudo tee /opt/zeek/etc/node.cfg.temp -a
	  #add local zeek proxy here, note to add offloading proxies here in the future
	  proxyAdd="#\n[proxy-zeek]\ntype=proxy\nhost=$managerIPv4"
	  sudo echo -e $proxyAdd | sudo tee /opt/zeek/etc/node.cfg.temp -a
	  #generate public/private key pair for managing workers and store it under zeek
	  mkdir -p /home/zeek/.ssh 
      #zeek requires us to use blank keys for managing workers
      ssh-keygen -b 2048 -t rsa -f /home/zeek/.ssh/id_rsa -q -N ""
      echo "[+] Generated public/private key pair successfully"
	  # begin worker configuration
      read -p "How many worker nodes (networks) would you like to monitor? " workerCount
      # create a for loop to iterate and add workers
	  for i in $( eval echo {1..$workerCount} )
      do
		 echo "Name of worker "$i": (eg: dmz-worker)"
		 read worker
		 echo "IPv4 Address of "$worker":"
		 read workerIPv4
		 echo "Interface to monitor on "$worker":"
		 read workerInt
		 echo "Management IPv4 Address of "$worker":"
		 read workerMgmt
		 #copy ssh public id to worker sensor
		 ssh-copy-id zeek@$workerMgmt
         # The line below adds the config options to node.cfg
         workerAdd="#\n[$worker]\ntype=worker\nhost=$workerIPv4\ninterface=$workerInt"
		 sudo echo -e $workerAdd | sudo tee /opt/zeek/etc/node.cfg.temp -a
		 #copy the generated public key (id_rsa.pub) over to our dmz-sensor host for later authentication
	     ssh-copy-id zeek@$workerManagement
	  done
	  sudo cat /opt/zeek/etc/node.cfg.temp
	  #double check configuration before overwriting node.cfg
	  read -p "Please confirm the configuration setup before overwriting node.cfg [Y/N]: " confirm
	  if [[ "$confirm" == "Y" ]]
	  then
		 #overwrite node.cfg 
		 sudo mv /opt/zeek/etc/node.cfg.temp /opt/zeek/etc/node.cfg
		 #append a line to our local.zeek file changing our log format to json for Splunk
	  else
		  echo "[-] Exiting Zeek Automated Install & Config..."
	      exit
      fi
   fi
fi
done
# create a zeek service to use in the future, and enable on boot
zeekService="#\n[Unit]\nDescription=Zeek Network Security Monitor (NSM)\nAfter=network.target
	  \n#\n[Service]\nType=forking\nuser=zeek\ngroup=zeek\nExecStart=/opt/zeek/bin/zeekctl deploy\nExecStop=/opt/zeek/bin/zeekctl stop\n#\n[Install]\nWantedBy=default.target"
sudo echo -e $zeekService | sudo tee /etc/systemd/system/zeek.service
sudo chmod u+x /etc/systemd/system/zeek.service
# install zeekctl prior to starting zeek
sudo zeekctl install
sudo systemctl daemon-reload
sudo systemctl enable zeek
sudo systemctl start zeek
sudo systemctl status zeek

# add json-logs load policy for easy exporting to splunk 
sudo echo "@load policy/tuning/json-logs" | sudo tee /opt/zeek/share/zeek/site/local.zeek -a
# add administrator email to zeekctl.cfg
read -p "Configure Zeek Management Email Address? " emailPreference
if [[ "$confirm" == "Y" ]]
then
   # retrieve desired administrator email
   read -p "Zeek Administrator Email Address: " adminEmail
   # replace existing configuration with adminEmail using sed
   sudo sed -i "s/MailTo = root@localhost/MailTo = $adminEmail/g" /opt/zeek/etc/zeekctl.cfg
else
   # set the mail server to send mail to our zeek user rather than root
   sudo sed -i "s/MailTo = root@localhost/MailTo = zeek@localhost/g" /opt/zeek/etc/zeekctl.cfg
fi
#change the log rotation interval to once every 86400 seconds or 24 hours
read -p "Log Rotation Interval (3600, 86400, etc.): " logRotation
sudo sed -i "s/LogRotationInterval = 3600/LogRotationInterval = $logRotation/g" /opt/zeek/etc/zeekctl.cfg
#check one last time to make sure we've got correct permissions
sudo chmod -R zeek:zeek /opt/zeek

# set the capabilities of zeek folders, allowing them access to the monitoring interface
sudo setcap cap_net_raw,cap_net_admin=eip /opt/zeek/bin/zeek
sudo setcap cap_net_raw,cap_net_admin=eip /opt/zeek/bin/zeekctl

echo "[+] Adding firewall rules to allow remote management:"
sudo firewall-cmd --add-service=sshd --permanent
sudo firewall-cmd --add-port=47761/tcp --permanent
sudo firewall-cmd --add-port=47761/udp --permanent
sudo firewall-cmd --add-port=47762/tcp --permanent
sudo firewall-cmd --add-port=47762/udp --permanent

echo "[+] Ready to Deploy Zeek Network Security Monitor!"
#zeekctl deploy