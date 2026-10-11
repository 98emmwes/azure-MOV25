#!/bin/bash
# Installerar felanmalan-appen pa webbservern.
# Anvandning (pa VM:en, efter att W41 ligger pa GitHub):
#   sudo bash setup-app.sh <repoUrl> <repoFolder> <storageAccountName> <appIdentityClientId>
# Exempel:
#   sudo bash setup-app.sh https://github.com/98emmwes/azure-MOV25.git W41 stnordvik98emmwes01 <client-id>
set -euo pipefail

REPO_URL="$1"
REPO_FOLDER="$2"
STORAGE_ACCOUNT="$3"
CLIENT_ID="$4"

apt-get update -y
apt-get install -y git python3-venv

rm -rf /tmp/nordvik-repo
git clone "$REPO_URL" /tmp/nordvik-repo
SRC="/tmp/nordvik-repo/${REPO_FOLDER}/app"

mkdir -p /opt/nordvik
cp "$SRC/app.py" "$SRC/requirements.txt" /opt/nordvik/
python3 -m venv /opt/nordvik/venv
/opt/nordvik/venv/bin/pip install --quiet -r /opt/nordvik/requirements.txt

cat > /etc/nordvik-app.env <<EOF
STORAGE_ACCOUNT=${STORAGE_ACCOUNT}
AZURE_CLIENT_ID=${CLIENT_ID}
CONTAINER_NAME=felanmalningar
EOF
chmod 640 /etc/nordvik-app.env
chown root:www-data /etc/nordvik-app.env

cp "$SRC/nordvik-app.service" /etc/systemd/system/nordvik-app.service
cp "$SRC/public/index.html" /var/www/html/index.html
cp "$SRC/nginx-nordvik.conf" /etc/nginx/sites-available/default

systemctl daemon-reload
systemctl enable --now nordvik-app
systemctl restart nordvik-app
nginx -t
systemctl restart nginx
echo "Klart. Testa: systemctl status nordvik-app"
