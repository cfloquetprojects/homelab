#!/bin/bash
# Charlie Floquet 8/3/21

### Script Requisites ###
# - Allow the bash script to be executable
#  -> chmod +x plexkickoff.bash
# - Change the owner of the script to be the specific named user
#  -> chown userName:users plexkickoff.bash
# - Lastly, if the script is complaining about ^M (carriage return) characters fix it with the line below:
#  -> sed -i -e 's/\r$//' PlexKickoff.bash

### Initial Firewall Config ###
# we need to first allow everything before we enable to not terminate SSH connections
sudo ufw default allow
sudo ufw enable
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
# now we are able to default deny incoming packets
sudo ufw default deny incoming
sudo ufw allow 32400/tcp

### Install ZFS Utils for Storage Pool Creation ###
# Fetch the ZFS Utilities package from apt, which we will use for disk formatting
sudo apt -y install zfsutils-linux
# List all 1TB+ drives connected to the host operating system
echo "[+] Install ZFS Utilities for Storage Pool Creation"
sudo fdisk -l | grep "Disk /dev"
# retrieve user decision on which drives to mirror
echo "Please enter the device name of the first drive you would like to include: (ex: /dev/sda)"
read diskOne
echo "Second disk (if using mirroring): "
read diskTwo
#use zpool to create a mirrored pool from two distinct disks
sudo zpool create plex mirror $diskOne $diskTwo
echo "[+] Created ZFS Mirrored Pool Plex"
sudo df -h | grep plex

# Create Plex folder and subfolders within target folder directory
echo "[+] Creating Subfolders for Plex Storage (Movies, TV, Anime)"
sudo mkdir -p plex/{TV,Movies,Anime}

# Download and Install Latest Patches/Updates:
echo "[+] Retrieving latest updates..."
sudo apt-get -y update
echo "[+] Installing latest updates..."
sudo apt-get -y upgrade

########## Setup MFA Authentication for SSH ##########
echo "[+] Setting up/Installing MFA SSH and Disallowing Root Login"

sudo apt install -y openssh-server
echo "[+] Installed OpenSSH Server"
sudo apt install -y libpam-google-authenticator
echo "[+] Installed Google Authenticator MFA"
sudo systemctl enable sshd
sudo systemctl restart sshd
# Disallow Root Login within /etc/ssh/sshd_config
sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/g' /etc/ssh/sshd_config
echo "[+] Disallowed Root SSH Login"
# Allow ChallengeResponseAuthentication, which accepts MFA Tokens
sudo sed -i 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/g' /etc/ssh/sshd_config
#Run the google authenticator setup script
sudo google-authenticator

########## Begin Docker Installation ##########
# update the apt package index and install packages to allow apt to use a repository over HTTPS:
sudo apt-get -y install \
    apt-transport-https \
    ca-certificates \

# install a few prerequisite packages which let apt use packages over HTTPS:
sudo apt -y install apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release

# add the GPG key for the official Docker repository to your system
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Use the following command to set up the stable repository
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# fetch one last update using the newly added repository
sudo apt-get -y update

# install the latest version of Docker Engine and containerd
sudo apt-get -y install docker-ce docker-ce-cli containerd.io

# alter the existing permissions to allow us to run Docker compose
#sudo chmod +x /usr/local/bin/docker-compose

# Now we need to add the Docker repository to APT sources
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"

# lets update once again with the new repo added:
sudo apt -y update

# Now we can finally begin the actual docker installation
sudo apt install -y docker-ce
sudo apt install -y docker-compose

# Display the status of the docker service
echo "[+] Checking if the Docker Service is running properly (Y/N)"
systemctl is-active sshd >/dev/null 2>&1 && echo "YES" || echo "NO"

# we should add our named user to the docker group to avoid needing to use sudo
sudo usermod -aG docker ${USER}

########## Completed Docker Installation ##########

# Now lets run docker composeto start pulling the image and start container
echo "[+] Starting Plex Container in Background with Docker-Compose "
# bring the docker container up with -d allowing it to run in the background
sudo docker-compose up -d

echo "[+] Plex Media Server Started and Running on Port 32400!"
echo " - Claim Server from remote host by creating an SSH tunnel"
echo " > ssh user@target_server_ip -L 8888:localhost:32400"
echo " - Then simply visit localhost:8888/web to setup the Plex Server"
