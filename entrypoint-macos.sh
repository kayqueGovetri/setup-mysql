#!/bin/bash
set -e

PORT="${INPUT_MYSQL_PORT:-32768}"
PASSWORD="${INPUT_MYSQL_ROOT_PASSWORD:-root}"

echo "### Installing MySQL on macOS"
brew update
brew install mysql

echo "### Stopping any existing MySQL service"
brew services stop mysql || true

echo "### Writing custom my.cnf"
sudo tee /opt/homebrew/etc/my.cnf > /dev/null <<EOF
[mysqld]
port=$PORT
bind-address=0.0.0.0
skip-networking=0
log-error=/opt/homebrew/var/mysql/error.log
EOF

echo "### Starting mysqld manually with debug"
nohup /opt/homebrew/opt/mysql/bin/mysqld \
  --defaults-file=/opt/homebrew/etc/my.cnf \
  --user=$USER \
  --verbose \
  --log-error-verbosity=3 > /tmp/mysql.log 2>&1 &

echo "### Waiting for MySQL to start"
sleep 20

echo "### Updating root password with plugin caching_sha2_password"
mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY '${PASSWORD}'; FLUSH PRIVILEGES;"

echo "### Attempting MySQL connection"
if ! mysql -h 127.0.0.1 -P $PORT -u root -p$PASSWORD -e "SELECT VERSION();"; then
    echo "❌ Failed to connect to MySQL"
    tail -n 100 /opt/homebrew/var/mysql/error.log || echo "⚠️ Log not found"
    exit 1
fi

echo "✅ MySQL setup and connection successful"
