#!/usr/bin/env bash

############################################################################
# This script will automate a Gitlab CE installation on Ubuntu 20.04.      #
# The script installs and configures Gitlab CE and sets the root password. #
############################################################################

# Declaring variables.
DISTRO=$(lsb_release -ds)
IP="192.168.56.72"
PORT="8082"

# Welcome message.
echo -e "\e[96;1;3;5m[OK] Distribution: ${DISTRO}\e[m"
cat << STOP
#--------------------#
# Welcome to Ubuntu. #
#--------------------#
                    ##        .            
              ## ## ##       ==            
           ## ## ## ##      ===            
       /""""""""""""""""\___/ ===        
  ~~~ {~~ ~~~~ ~~~ ~~~~ ~~ ~ /  ===- ~~~
       \______ o          __/            
         \    \        __/             
          \____\______/                    
STOP

# Downloading Gitlab.
echo -e "\e[32;1;3m[INFO] Installing dependencies\e[m"
sudo apt update
sudo apt install curl openssh-server ca-certificates git expect -qy
echo -e "\e[32;1;3m[INFO] Downloading Gitlab\e[m"
cd /tmp || exit
curl -sS https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | sudo bash

# Installing Gitlab.
echo -e "\e[32;1;3m[INFO] Installing Gitlab\e[m"
sudo apt install gitlab-ce -qy

# Configuring Gitlab.
echo -e "\e[32;1;3m[INFO] Configuring Gitlab\e[m"
sudo sed -i "s|external_url 'http://gitlab.example.com'|external_url 'http://${IP}:${PORT}'|g" /etc/gitlab/gitlab.rb
sudo gitlab-ctl reconfigure
sudo gitlab-ctl start

# Confirmation prompt.
echo -e "\e[32;1;3m[INFO] Resetting password\e[m"
sudo grep Password: /etc/gitlab/initial_root_password
read -sp "Please enter the new password: " answer
echo "Entered password: ${answer}"

# Creating exception.
echo -e "\e[32;1;3m[INFO] Adjusting firewall\e[m"
sudo ufw allow ${PORT}/tcp
echo "y" | sudo ufw enable
sudo ufw reload

# Restarting service.
echo -e "\e[32;1;3m[INFO] Restarting service\e[m"
sudo gitlab-ctl restart

# Installation complete.
echo -e "\e[33;1;3;5m[✓] Finished, installation complete.\e[m"
exit
