#!/bin/sh

set -e

echo "Starting Emergency SOS Laravel backend..."

mkdir -p storage/app/firebase
mkdir -p storage/app/aiven
mkdir -p storage/framework/cache
mkdir -p storage/framework/sessions
mkdir -p storage/framework/views
mkdir -p storage/logs
mkdir -p bootstrap/cache

echo "Preparing Render secret files..."

FIREBASE_TARGET="/var/www/html/storage/app/firebase/service-account.json"
AIVEN_CA_TARGET="/var/www/html/storage/app/aiven/ca.pem"

if [ -f /etc/secrets/service-account.json ]; then
    cp /etc/secrets/service-account.json "$FIREBASE_TARGET"
    chmod 644 "$FIREBASE_TARGET"
    chown www-data:www-data "$FIREBASE_TARGET" || true
fi

if [ -f /etc/secrets/ca.pem ]; then
    cp /etc/secrets/ca.pem "$AIVEN_CA_TARGET"
    chmod 644 "$AIVEN_CA_TARGET"
    chown www-data:www-data "$AIVEN_CA_TARGET" || true
fi

if [ ! -r "$FIREBASE_TARGET" ]; then
    echo "Firebase service account file is missing or not readable"
    ls -la /var/www/html/storage/app/firebase || true
    exit 1
fi

if [ ! -r "$AIVEN_CA_TARGET" ]; then
    echo "Aiven CA file is missing or not readable"
    ls -la /var/www/html/storage/app/aiven || true
    exit 1
fi

export FIREBASE_CREDENTIALS="$FIREBASE_TARGET"
export MYSQL_ATTR_SSL_CA="$AIVEN_CA_TARGET"

echo "Firebase credentials path: $FIREBASE_CREDENTIALS"
echo "Aiven CA path: $MYSQL_ATTR_SSL_CA"

chown -R www-data:www-data storage bootstrap/cache || true
chmod -R 775 storage bootstrap/cache || true

php artisan optimize:clear || true

php artisan migrate --force

php artisan config:cache
php artisan route:cache
php artisan view:cache

apache2-foreground
