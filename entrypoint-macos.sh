
#!/bin/bash

set -e

PORT="${mysql_port:-32768}"
ROOT_PASSWORD="${mysql_root_password:-root}"
DATABASE="${mysql_database:-}"
MYSQL_USER="${mysql_user:-}"
MYSQL_USER_PASSWORD="${mysql_password:-}"

echo "### Installing MySQL on macOS"
brew update
brew install mysql

echo "### Stopping any existing MySQL service"
brew services stop mysql || true

# Detect Homebrew prefix
if [ -d /opt/homebrew ]; then
  BREW_PREFIX=/opt/homebrew
else
  BREW_PREFIX="$(brew --prefix)"
fi

echo "Using Homebrew prefix: $BREW_PREFIX"

sudo mkdir -p "$BREW_PREFIX/etc"

echo "### Writing custom my.cnf"
sudo tee "$BREW_PREFIX/etc/my.cnf" > /dev/null <<EOF
[mysqld]
port=$PORT
bind-address=127.0.0.1
skip-networking=0
log-error=$BREW_PREFIX/var/mysql/error.log
EOF

echo "### Starting mysqld"
nohup "$BREW_PREFIX/opt/mysql/bin/mysqld" \
  --defaults-file="$BREW_PREFIX/etc/my.cnf" \
  --user="$(whoami)" \
  --verbose \
  --log-error-verbosity=3 > /tmp/mysql.log 2>&1 &

echo "### Waiting for MySQL to start"

READY=false

for i in {1..30}; do
  if mysqladmin ping -h 127.0.0.1 --silent; then
    READY=true
    break
  fi

  sleep 2
done

if [ "$READY" != "true" ]; then
  echo "❌ MySQL failed to start"
  tail -n 100 /tmp/mysql.log || true
  tail -n 100 "$BREW_PREFIX/var/mysql/error.log" || true
  exit 1
fi

echo "### Updating root password"

mysql -u root -e \
  "ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY '${ROOT_PASSWORD}'; FLUSH PRIVILEGES;"

echo "### Creating database and custom user"

if [ -n "$MYSQL_USER" ]; then
  if [ -z "$DATABASE" ] || [ -z "$MYSQL_USER_PASSWORD" ]; then
    echo "❌ mysql_database and mysql_password are required when mysql_user is specified"
    exit 1
  fi

  mysql -u root -p"$ROOT_PASSWORD" -e \
    "CREATE DATABASE IF NOT EXISTS \`$DATABASE\`;"

  mysql -u root -p"$ROOT_PASSWORD" -e \
    "CREATE USER IF NOT EXISTS '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_USER_PASSWORD';"

  mysql -u root -p"$ROOT_PASSWORD" -e \
    "GRANT ALL PRIVILEGES ON \`$DATABASE\`.* TO '$MYSQL_USER'@'%'; FLUSH PRIVILEGES;"
elif [ -n "$DATABASE" ]; then
  mysql -u root -p"$ROOT_PASSWORD" -e \
    "CREATE DATABASE IF NOT EXISTS \`$DATABASE\`;"
fi

echo "### Testing MySQL root connection"

if ! mysql \
  -h 127.0.0.1 \
  -P "$PORT" \
  -u root \
  -p"$ROOT_PASSWORD" \
  -e "SELECT VERSION();"; then

  echo "❌ Failed to connect to MySQL as root"
  tail -n 100 "$BREW_PREFIX/var/mysql/error.log" || true
  exit 1
fi

if [ -n "$MYSQL_USER" ]; then
  echo "### Testing MySQL custom user connection"

  if ! mysql \
    -h 127.0.0.1 \
    -P "$PORT" \
    -u "$MYSQL_USER" \
    -p"$MYSQL_USER_PASSWORD" \
    "$DATABASE" \
    -e "SELECT CURRENT_USER();"; then

    echo "❌ Failed to connect to MySQL as custom user"
    exit 1
  fi
fi

echo "✅ MySQL setup and connection successful"
