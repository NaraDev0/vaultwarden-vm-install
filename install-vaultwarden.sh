#!/bin/bash
# ============================================================
# Vaultwarden - Script d'installation VM (Debian 12 / Ubuntu 24.04)
# Usage : sudo bash install-vaultwarden.sh
# ============================================================

set -e

# ---- VARIABLES À MODIFIER ----
DOMAIN="vault.mondomaine.local"   # vVotre domaine ou IP locale
ADMIN_PASS="ChangeMoi123!"        # Mot de passe panneau admin
DATA_DIR="/opt/vaultwarden"       # Répertoire de données
# ------------------------------

echo "================================================"
echo " Installation de Vaultwarden"
echo "================================================"

# 1. Mise à jour système
apt-get update && apt-get upgrade -y

# 2. Dépendances
apt-get install -y \
    ca-certificates curl gnupg lsb-release \
    nginx argon2 openssl

# 3. Installation Docker
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") \
$(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# 4. Création du répertoire
mkdir -p "$DATA_DIR/data"
cd "$DATA_DIR"

# 5. Génération du token admin (hashé argon2)
echo "[*] Génération du token admin..."
ADMIN_TOKEN=$(echo -n "$ADMIN_PASS" | \
    argon2 "$(openssl rand -base64 16)" -e -id -k 65536 -t 3 -p 4 | \
    sed 's/\$/\$\$/g')

# 6. Création du docker-compose.yml
cat > docker-compose.yml <<EOF
services:
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    restart: unless-stopped
    environment:
      WEBSOCKET_ENABLED: "true"
      SIGNUPS_ALLOWED: "false"       # Désactiver les inscriptions libres
      ADMIN_TOKEN: "${ADMIN_TOKEN}"  # Token admin hashé
      DOMAIN: "https://${DOMAIN}"
    volumes:
      - ./data:/data
    ports:
      - "127.0.0.1:8080:80"
      - "127.0.0.1:3012:3012"        # WebSocket
EOF

# 7. Démarrage de Vaultwarden
docker compose up -d
echo "[✓] Vaultwarden démarré"

# 8. Certificat SSL auto-signé (pour usage interne)
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/vaultwarden.key \
    -out /etc/nginx/ssl/vaultwarden.crt \
    -subj "/CN=${DOMAIN}" \
    2>/dev/null || (mkdir -p /etc/nginx/ssl && openssl req -x509 -nodes \
    -days 3650 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/vaultwarden.key \
    -out /etc/nginx/ssl/vaultwarden.crt \
    -subj "/CN=${DOMAIN}")

# 9. Configuration Nginx
cat > /etc/nginx/sites-available/vaultwarden <<EOF
server {
    listen 80;
    server_name ${DOMAIN};
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name ${DOMAIN};

    ssl_certificate     /etc/nginx/ssl/vaultwarden.crt;
    ssl_certificate_key /etc/nginx/ssl/vaultwarden.key;
    ssl_protocols       TLSv1.2 TLSv1.3;

    client_max_body_size 128M;

    location / {
        proxy_pass         http://127.0.0.1:8080;
        proxy_set_header   Host \$host;
        proxy_set_header   X-Real-IP \$remote_addr;
        proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
    }

    location /notifications/hub {
        proxy_pass         http://127.0.0.1:3012;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade \$http_upgrade;
        proxy_set_header   Connection "upgrade";
    }

    location /notifications/hub/negotiate {
        proxy_pass http://127.0.0.1:8080;
    }
}
EOF

ln -sf /etc/nginx/sites-available/vaultwarden /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx
echo "[✓] Nginx configuré"

# 10. Résumé
IP=$(hostname -I | awk '{print $1}')
echo ""
echo "================================================"
echo " Installation terminée !"
echo "================================================"
echo " URL          : https://${DOMAIN}"
echo " IP directe   : https://${IP}"
echo " Admin panel  : https://${DOMAIN}/admin"
echo " Mot de passe admin : ${ADMIN_PASS}"
echo " Données      : ${DATA_DIR}/data"
echo ""
echo " IMPORTANT : Note le mot de passe admin quelque part !"
echo " Pour les mises à jour : cd ${DATA_DIR} && docker compose pull && docker compose up -d"
echo "================================================"
