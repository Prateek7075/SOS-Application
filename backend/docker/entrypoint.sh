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

if [ -f /etc/secrets/service-account.json ]; then
    cp /etc/secrets/service-account.json storage/app/firebase/service-account.json
    chmod 644 storage/app/firebase/service-account.json
    chown www-data:www-data storage/app/firebase/service-account.json || true
fi

if [ -f /etc/secrets/ca.pem ]; then
    cp /etc/secrets/ca.pem storage/app/aiven/ca.pem
    chmod 644 storage/app/aiven/ca.pem
    chown www-data:www-data storage/app/aiven/ca.pem || true
fi

chown -R www-data:www-data storage bootstrap/cache || true
chmod -R 775 storage bootstrap/cache || true

php artisan optimize:clear || true

php artisan migrate --force

php artisan config:cache
php artisan route:cache
php artisan view:cache

apache2-foreground
