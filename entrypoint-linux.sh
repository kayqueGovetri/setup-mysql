#!/bin/bash
set -e

PORT="${INPUT_MYSQL_PORT:-32768}"
PASSWORD="${INPUT_MYSQL_ROOT_PASSWORD:-root}"

echo "🐳 Starting MySQL Docker container on Linux..."

docker run -d \
  --name mysql \
  -e MYSQL_ROOT_PASSWORD=$PASSWORD \
  -p $PORT:3306 \
  mysql:8.0

echo "⏳ Waiting for MySQL to become ready..."

for i in {1..15}; do
  if docker exec mysql mysqladmin ping -h "127.0.0.1" --silent; then
    echo "✅ MySQL is ready!"
    break
  fi
  sleep 2
done

echo "🔎 Testing connection..."
mysql -h 127.0.0.1 -P $PORT -u root -p$PASSWORD -e "SELECT VERSION();" || {
  echo "❌ Failed to connect to MySQL"
  exit 1
}
