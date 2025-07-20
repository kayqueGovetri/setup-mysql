#!/bin/bash
set -e

PORT="${INPUT_MYSQL_PORT:-32768}"
ROOT_PASSWORD="${INPUT_MYSQL_ROOT_PASSWORD:-root}"
DATABASE="${INPUT_MYSQL_DATABASE:-}"
USER="${INPUT_MYSQL_USER:-}"
USER_PASSWORD="${INPUT_MYSQL_PASSWORD:-}"

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
mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY '${ROOT_PASSWORD}'; FLUSH PRIVILEGES;"

if [ -n "$USER" ]; then
  echo "### Creating user and database (if specified)"
  mysql -u root -p"$ROOT_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS \`$DATABASE\`;"
  mysql -u root -p"$ROOT_PASSWORD" -e "CREATE USER IF NOT EXISTS '$USER'@'%' IDENTIFIED BY '$USER_PASSWORD';"
  mysql -u root -p"$ROOT_PASSWORD" -e "GRANT ALL PRIVILEGES ON \`$DATABASE\`.* TO '$USER'@'%'; FLUSH PRIVILEGES;"
fi

echo "### Attempting MySQL root connection"
if ! mysql -h 127.0.0.1 -P $PORT -u root -p"$ROOT_PASSWORD" -e "SELECT VERSION();"; then
    echo "❌ Failed to connect to MySQL as root"
    tail -n 100 /opt/homebrew/var/mysql/error.log || echo "⚠️ Log not found"
    exit 1
fi

if [ -n "$USER" ]; then
  echo "### Attempting MySQL custom user connection"
  if ! mysql -h 127.0.0.1 -P $PORT -u "$USER" -p"$USER_PASSWORD" -e "SELECT CURRENT_USER();"; then
    echo "❌ Failed to connect to MySQL as custom user"
    exit 1
  fi
fi

echo "✅ MySQL setup and connection successful"
