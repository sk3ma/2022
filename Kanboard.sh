#!/usr/bin/env bash

######################################################################
# This script will automate a Kanboard installation on Ubuntu 20.04. #
# The script installs the LAMP stack and configures Kanboard server  #
######################################################################

# Declaring variables.
DISTRO=$(lsb_release -ds)
USERID=$(id -u)

# Sanity checking.
if [[ ${USERID} -ne "0" ]]; then
    echo -e "\e[31;1;3mYou must be root, exiting.\e[m"
    exit 1
fi

# Apache installation.
apache() {
    echo -e "\e[96;1;3mDistribution: ${DISTRO}\e[m"
    echo -e "\e[32;1;3mInstalling Apache\e[m"
    apt update
    apt install apache2 apache2-utils certbot python3-certbot-apache -qy
    systemctl start apache2
    systemctl enable apache2
    echo "<h1>Apache is operational</h1>" > /var/www/html/index.html
    sed -ie 's/80/8082/g' /etc/apache2/ports.conf
}

# PHP installation.
web() {
    echo -e "\e[32;1;3mInstalling PHP\e[m"
    apt install libapache2-mod-php7.4 php7.4 php7.4-{cli,curl,common,dev,fpm,gd,mbstring,mysqlnd} -qy
    echo "<?php phpinfo(); ?>" > /var/www/html/info.php
}

# MariaDB installation.
maria() {
    echo -e "\e[32;1;3mInstalling MariaDB\e[m"
    apt install software-properties-common curl -qy
    cd /opt
    curl -LsS -O https://downloads.mariadb.com/MariaDB/mariadb_repo_setup
    bash mariadb_repo_setup --mariadb-server-version=10.6
    apt update
    apt install mariadb-server-10.6 mariadb-client-10.6 mariadb-common -qy
    echo -e "\e[32;1;3mStarting MariaDB\e[m"
    systemctl start mariadb
    systemctl enable mariadb
    rm -f mariadb_repo_setup
}

# Kanboard database.
data() {
    echo -e "\e[32;1;3mConfiguring MariaDB\e[m"
    local dbase=$(cat << STOP
CREATE DATABASE kanboard_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'osadmin'@'%' identified by '1q2w3e4r5t';
GRANT ALL PRIVILEGES ON kanboard_db.* TO 'osadmin'@'%';
STOP
)
    echo "${dbase}" > /var/www/html/kanboard_db.sql
}

# Composer installation.
comp() {
    echo -e "\e[32;1;3mInstalling Composer\e[m"
    apt install git unzip vim -y
    curl -sS https://getcomposer.org/installer | php
    mv -v composer.phar /usr/local/bin/composer
    chmod +x /usr/local/bin/composer
    source ~/.bashrc
}

# Kanboard database.
kanban() {
    echo -e "\e[32;1;3mInstalling Kanboard\e[m"
    cd /opt
    git clone https://github.com/kanboard/kanboard.git
    mv -v kanboard /var/www/kanboard
    cd /var/www/kanboard
    mv -v config.default.php config.php
    composer install
    echo -e "\e[32;1;3mChanging permissions\e[m"
    chown -R www-data:www-data /var/www/kanboard
    chmod -R 755 /var/www/kanboard
}

# Kanboard configuration.
config() {
    echo -e "\e[32;1;3mConfiguring Kanboard\e[m"
    echo -e 'define('DB_DRIVER', 'mysql');' >> /var/www/kanboard/config.php
    echo -e 'define('DB_USERNAME', 'osadmin');' >> /var/www/kanboard/config.php
    echo -e 'define('DB_PASSWORD', '1q2w3e4r5t');' >> /var/www/kanboard/config.php
    echo -e 'define('DB_NAME', 'kanboard_db');' >> /var/www/kanboard/config.php
}

# Kanboard virtualhost.
site() {
    echo -e "\e[32;1;3mConfiguring Apache\e[m"
    touch /etc/apache2/sites-available/kanboard.conf
    ln -s /etc/apache2/sites-available/kanboard.conf /etc/apache2/sites-enabled/kanboard.conf
    local vhost=$(cat << STOP
<VirtualHost *:80>
        ServerName kanboard.mycompany.com
        DocumentRoot /var/www/kanboard
        <Directory /var/www/kanboard>
            Options FollowSymLinks
            AllowOverride All
            Require all granted
        </Directory>
        ErrorLog /var/log/apache2/kanboard_error.log
        CustomLog /var/log/apache2/kanboard_access.log common
</VirtualHost>
STOP
)
    echo "${vhost}" > /etc/apache2/sites-available/kanboard.conf
    sed -ie 's/80/8082/g' /etc/apache2/sites-enabled/kanboard.conf
    a2enmod rewrite
    a2ensite kanboard.conf
    echo -e "\e[32;1;3mRestarting Apache\e[m"
    systemctl reload apache2
}

# Firewall creation.
fire() {
    echo -e "\e[32;1;3mAdjusting firewall\e[m"
    ufw allow 80,443/tcp
    ufw allow 8082/tcp
    echo "y" | ufw enable
    ufw reload
    echo -e "\e[33;1;3;5mFinished, installation complete.\e[m"
    exit
}

# Calling functions.
if [[ -f /etc/lsb-release ]]; then
    echo -e "\e[35;1;3;5mUbuntu detected, proceeding...\e[m"
    apache
    web
    maria
    data
    comp
    kanban
    config
    site
    fire
fi
