#!/bin/bash
set -e

# Entradas com valores padrão
PORT="${INPUT_MYSQL_PORT:-32768}"
ROOT_PASSWORD="${INPUT_MYSQL_ROOT_PASSWORD:-root}"
DATABASE="${INPUT_MYSQL_DATABASE:-}"
USER="${INPUT_MYSQL_USER:-}"
USER_PASSWORD="${INPUT_MYSQL_PASSWORD:-}"

echo "🐳 Starting MySQL Docker container on Linux..."

docker run -d \
  --name mysql \
  -e MYSQL_ROOT_PASSWORD="$ROOT_PASSWORD" \
  ${DATABASE:+-e MYSQL_DATABASE="$DATABASE"} \
  ${USER:+-e MYSQL_USER="$USER"} \
  ${USER:+-e MYSQL_PASSWORD="$USER_PASSWORD"} \
  -p "$PORT":3306 \
  mysql:8.0

echo "⏳ Waiting for MySQL to become ready..."

for i in {1..15}; do
  if docker exec mysql mysqladmin ping -h "127.0.0.1" --silent; then
    echo "✅ MySQL is ready!"
    break
  fi
  sleep 2
done

echo "🔎 Testing connection with root user..."
mysql -h 127.0.0.1 -P "$PORT" -u root -p"$ROOT_PASSWORD" -e "SELECT VERSION();" || {
  echo "❌ Failed to connect to MySQL as root"
  exit 1
}

if [[ -n "$USER" ]]; then
  echo "🔎 Testing connection with custom user..."
  mysql -h 127.0.0.1 -P "$PORT" -u "$USER" -p"$USER_PASSWORD" -e "SELECT CURRENT_USER();" || {
    echo "❌ Failed to connect to MySQL as custom user"
    exit 1
  }
fi
