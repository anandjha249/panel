#!/usr/bin/env bash
set -euo pipefail

SHARE=/mnt/panel-data
PANEL=/anandjha249/panel         # adjust to your repo name

sudo apt-get update -y
sudo apt-get install -y cifs-utils rsync

# --- mount Azure Files (SMB) ---
sudo mkdir -p "$SHARE"
if ! mountpoint -q "$SHARE"; then
  sudo mount -t cifs \
    "//${AZURE_STORAGE_ACCOUNT}.file.core.windows.net/${AZURE_FILE_SHARE}" \
    "$SHARE" \
    -o "username=${AZURE_STORAGE_ACCOUNT},password=${AZURE_STORAGE_KEY},serverino,nosharesock,actimeo=30,mfsymlinks,uid=1000,gid=1000"
fi
sudo chown -R 1000:1000 "$SHARE"

# --- bootstrap panel data into the share (first run only) ---
mkdir -p "$SHARE/panel/env" "$SHARE/panel/db"
cd "$PANEL"

if [ ! -f "$SHARE/panel/.bootstrapped" ]; then
  cp .env.example .env
  php artisan key:generate --force
  touch "$SHARE/panel/db/database.sqlite"
  sed -i 's/^DB_CONNECTION=.*/DB_CONNECTION=sqlite/' .env
  echo "DB_DATABASE=$SHARE/panel/db/database.sqlite" >> .env
  echo "APP_URL=https://panel.example.com" >> .env
  echo "TRUSTED_PROXIES=*" >> .env
  cp .env "$SHARE/panel/env/.env"
  rsync -a storage/ "$SHARE/panel/storage/"
  touch "$SHARE/panel/.bootstrapped"
fi
