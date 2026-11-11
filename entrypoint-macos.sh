
#!/bin/bash

set -Eeuo pipefail

# Configuration
PORT="${mysql_port:-32768}"
ROOT_PASSWORD="${mysql_root_password:-root}"
DATABASE="${mysql_database:-}"
MYSQL_USER="${mysql_user:-}"
MYSQL_USER_PASSWORD="${mysql_password:-}"

echo "### Installing MySQL on macOS"

brew update
brew install mysql

BREW_PREFIX="$(brew --prefix)"
MYSQL_BIN="$BREW_PREFIX/opt/mysql/bin"

echo "Using Homebrew prefix: $BREW_PREFIX"

echo "### Stopping existing MySQL service"

brew services stop mysql || true

echo "### Configuring MySQL"

MYSQL_CONF="$BREW_PREFIX/etc/my.cnf"

cat > "$MYSQL_CONF" <<EOF
[mysqld]
port=$PORT
bind-address=127.0.0.1
skip-networking=0
EOF

echo "### Starting MySQL service"

brew services start mysql

echo "### Waiting for MySQL"

READY=false

for i in {1..60}; do
    if "$MYSQL_BIN/mysqladmin" \
        -h 127.0.0.1 \
        -P "$PORT" \
        -u root \
        ping --silent 2>/dev/null; then
        READY=true
        break
    fi

    sleep 2
done

if [[ "$READY" != "true" ]]; then
    echo "❌ MySQL failed to start"

    brew services list
    cat "$BREW_PREFIX/var/mysql/"*.err 2>/dev/null || true

    exit 1
fi

echo "### Configuring root password"

"$MYSQL_BIN/mysql" \
    -h 127.0.0.1 \
    -P "$PORT" \
    -u root \
    -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$ROOT_PASSWORD';"

echo "### Creating database and user"

if [[ -n "$DATABASE" ]]; then
    "$MYSQL_BIN/mysql" \
        -h 127.0.0.1 \
        -P "$PORT" \
        -u root \
        -p"$ROOT_PASSWORD" \
        -e "CREATE DATABASE IF NOT EXISTS \`$DATABASE\`;"
fi

if [[ -n "$MYSQL_USER" ]]; then
    if [[ -z "$DATABASE" || -z "$MYSQL_USER_PASSWORD" ]]; then
        echo "❌ mysql_database and mysql_password are required when mysql_user is specified"
        exit 1
    fi

    "$MYSQL_BIN/mysql" \
        -h 127.0.0.1 \
        -P "$PORT" \
        -u root \
        -p"$ROOT_PASSWORD" \
        -e "CREATE USER IF NOT EXISTS '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_USER_PASSWORD';"

    "$MYSQL_BIN/mysql" \
        -h 127.0.0.1 \
        -P "$PORT" \
        -u root \
        -p"$ROOT_PASSWORD" \
        -e "GRANT ALL PRIVILEGES ON \`$DATABASE\`.* TO '$MYSQL_USER'@'%'; FLUSH PRIVILEGES;"
fi

echo "### Testing root connection"

"$MYSQL_BIN/mysql" \
    -h 127.0.0.1 \
    -P "$PORT" \
    -u root \
    -p"$ROOT_PASSWORD" \
    -e "SELECT VERSION();"

if [[ -n "$MYSQL_USER" ]]; then
    echo "### Testing custom user connection"

    "$MYSQL_BIN/mysql" \
        -h 127.0.0.1 \
        -P "$PORT" \
        -u "$MYSQL_USER" \
        -p"$MYSQL_USER_PASSWORD" \
        "$DATABASE" \
        -e "SELECT CURRENT_USER();"
fi

echo "✅ MySQL setup and connection successful"
