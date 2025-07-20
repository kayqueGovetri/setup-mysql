#!/bin/bash
set -e

PORT="${INPUT_MYSQL_PORT:-32768}"
PASSWORD="${INPUT_MYSQL_ROOT_PASSWORD:-root}"

echo "### Installing MySQL on Linux"
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server

echo "### Configuring MySQL to allow TCP connections"
sudo tee /etc/mysql/mysql.conf.d/z-github.conf >/dev/null <<EOF
[mysqld]
port = $PORT
bind-address = 127.0.0.1
skip-networking = 0
EOF

echo "### Restarting MySQL"
sudo service mysql restart

echo "### Waiting for MySQL to start"
sleep 10

echo "### Setting root password and auth plugin"
# Use socket for local root access first
sudo mysql <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$PASSWORD';
FLUSH PRIVILEGES;
EOF

echo "### Testing connection over TCP"
if ! mysql -h 127.0.0.1 -P "$PORT" -u root -p"$PASSWORD" -e "SELECT VERSION();"; then
    echo "❌ Failed to connect to MySQL on 127.0.0.1:$PORT"
    exit 1
fi

echo "✅ MySQL is up and running on 127.0.0.1:$PORT"
