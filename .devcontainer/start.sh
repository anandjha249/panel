#!/usr/bin/env bash
set -euo pipefail

SHARE=/mnt/panel-data
PANEL=/workspaces/panel

# remount share if codespace restarted
if ! mountpoint -q "$SHARE"; then
  sudo mkdir -p "$SHARE"
  sudo mount -t cifs \
    "//${AZURE_STORAGE_ACCOUNT}.file.core.windows.net/${AZURE_FILE_SHARE}" \
    "$SHARE" \
    -o "username=${AZURE_STORAGE_ACCOUNT},password=${AZURE_STORAGE_KEY},serverino,nosharesock,actimeo=30,mfsymlinks,uid=1000,gid=1000"
fi

cd "$PANEL"

# point panel data at the share (symlinks live in the repo, targets on SMB)
sudo mountpoint -q "$PANEL/storage" || sudo mount --bind "$SHARE/panel/storage" "$PANEL/storage"
ln -sfn "$SHARE/panel/env/.env" .env
ln -sfn "$SHARE/panel/db/database.sqlite" database/database.sqlite

# deps (cheap no-ops when already installed)
composer install --no-interaction --prefer-dist
yarn install --frozen-lockfile

# cloudflared (install once)
if ! command -v cloudflared &>/dev/null; then
  curl -fsSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o /tmp/cf.deb
  sudo dpkg -i /tmp/cf.deb
fi

# restart background services
pkill -f "artisan serve" 2>/dev/null || true
pkill cloudflared 2>/dev/null || true
sleep 1
nohup cloudflared tunnel run --token "$CF_TUNNEL_TOKEN" > /tmp/cloudflared.log 2>&1 &
nohup php artisan serve --host=0.0.0.0 --port=8080 > storage/logs/serve.log 2>&1 &

php artisan migrate --force
echo "Panel: https://panel.example.com"
