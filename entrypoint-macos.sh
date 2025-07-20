#!/bin/bash
set -e

PORT="${INPUT_MYSQL_PORT:-32768}"
PASSWORD="${INPUT_MYSQL_ROOT_PASSWORD:-root}"

echo "### Installing MySQL on macOS"
brew update
brew install mysql
brew services stop mysql || true

sudo tee /opt/homebrew/etc/my.cnf > /dev/null <<EOF
[mysqld]
port=$PORT
bind-address=0.0.0.0
skip-networking=0
log-error=/opt/homebrew/var/mysql/error.log
EOF

nohup /opt/homebrew/opt/mysql/bin/mysqld \
  --defaults-file=/opt/homebrew/etc/my.cnf \
  --user=$USER \
  --verbose \
  --log-error-verbosity=3 > /tmp/mysql.log 2>&1 &

echo "### Waiting for MySQL to start"
sleep 20

if ! mysql -h 127.0.0.1 -P $PORT -u root -p$PASSWORD -e "SELECT VERSION();"; then
    echo "❌ Failed to connect to MySQL"
    exit 1
fi
