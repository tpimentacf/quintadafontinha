#!/usr/bin/env bash
# Configura Nginx para servir o site em HTTPS (443) com certificado Let's Encrypt.
# Usa o desafio DNS-01 via API Cloudflare (funciona com proxy Cloudflare e IP privado).
#
# Uso (no servidor):
#   sudo CF_API_TOKEN=xxxx EMAIL=geral@quintadafontinha.pt bash setup-https.sh
#
# Token Cloudflare: My Profile -> API Tokens -> Create Token -> template "Edit zone DNS"
#   Permissions: Zone / DNS / Edit   Zone Resources: quintadafontinha.pt
set -euo pipefail

DOMAIN="${DOMAIN:-dev.quintadafontinha.pt}"
WEBROOT="${WEBROOT:-/var/www/quintadafontinha}"
EMAIL="${EMAIL:?defina EMAIL=...}"
CF_API_TOKEN="${CF_API_TOKEN:?defina CF_API_TOKEN=...}"
SITE_CONF="/etc/nginx/sites-available/quintadafontinha"
CF_INI="/etc/letsencrypt/cloudflare.ini"

[[ $EUID -eq 0 ]] || { echo "Correr com sudo"; exit 1; }

echo ">> Instalar certbot + plugin Cloudflare"
apt-get update -qq
apt-get install -y -qq nginx certbot python3-certbot-dns-cloudflare

echo ">> Guardar credenciais Cloudflare em $CF_INI (600)"
install -d -m 700 /etc/letsencrypt
umask 077
printf 'dns_cloudflare_api_token = %s\n' "$CF_API_TOKEN" > "$CF_INI"
chmod 600 "$CF_INI"

echo ">> Obter certificado para $DOMAIN"
certbot certonly --non-interactive --agree-tos -m "$EMAIL" \
  --dns-cloudflare --dns-cloudflare-credentials "$CF_INI" \
  --dns-cloudflare-propagation-seconds 30 \
  -d "$DOMAIN" --keep-until-expiring

echo ">> Configurar Nginx (80 -> 443)"
install -d -o "${SUDO_USER:-root}" -g www-data "$WEBROOT"
cat > "$SITE_CONF" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name $DOMAIN;

    ssl_certificate     /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;

    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    root $WEBROOT;
    index index.html;

    location / { try_files \$uri \$uri/ =404; }
    location ~ /\. { deny all; }
    location ~* \.(css|js|jpg|jpeg|png|webp|svg|ico|woff2?)$ {
        expires 7d;
        add_header Cache-Control "public";
    }
}
EOF
ln -sf "$SITE_CONF" /etc/nginx/sites-enabled/quintadafontinha
rm -f /etc/nginx/sites-enabled/default

echo ">> Hook de renovação (reload Nginx)"
install -d /etc/letsencrypt/renewal-hooks/deploy
printf '#!/bin/sh\nsystemctl reload nginx\n' > /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh
chmod 755 /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh

if command -v ufw >/dev/null && ufw status | grep -q active; then
  echo ">> Abrir 443 no ufw"
  ufw allow 'Nginx Full'
fi

nginx -t
systemctl enable --now nginx
systemctl reload nginx
systemctl enable --now certbot.timer 2>/dev/null || true
certbot renew --dry-run

echo ">> Concluído: https://$DOMAIN"
