#!/bin/bash
set -e

PORT="${INPUT_MYSQL_PORT:-32768}"
PASSWORD="${INPUT_MYSQL_ROOT_PASSWORD:-root}"

echo "### Installing MySQL on Linux"
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server

echo "[mysqld]
port=$PORT
bind-address=0.0.0.0
skip-networking=0" | sudo tee /etc/mysql/mysql.conf.d/z-github.conf

sudo service mysql restart

echo "### Waiting for MySQL to start"
sleep 20

if ! mysql -h 127.0.0.1 -P $PORT -u root -p$PASSWORD -e "SELECT VERSION();"; then
    echo "❌ Failed to connect to MySQL"
    exit 1
fi
