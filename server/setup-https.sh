#!/usr/bin/env bash
# Configura Nginx em HTTPS (443) com certificado Let's Encrypt (HTTP-01 webroot).
#
# Contexto: o DNS autoritativo da zona está no ptservidor.net (Cloudflare em CNAME setup)
# e o tráfego chega via Cloudflare Tunnel (dev.quintadafontinha.pt -> https://localhost:443).
# O Let's Encrypt valida http://dev.quintadafontinha.pt/.well-known/acme-challenge/...
# que passa pela Cloudflare e pelo tunnel até ao Nginx em 443.
#
# Antes de correr: na rota do tunnel "dev" ligar temporariamente
#   "Disable TLS certificate verification" (o Nginx arranca com certificado autoassinado).
# Depois de correr: definir "Origin Server Name" = dev.quintadafontinha.pt e desligar o noTLSVerify.
#
# Uso: sudo EMAIL=geral@quintadafontinha.pt bash setup-https.sh
set -euo pipefail

DOMAIN="${DOMAIN:-dev.quintadafontinha.pt}"
WEBROOT="${WEBROOT:-/var/www/quintadafontinha}"
ACME_ROOT="/var/www/letsencrypt"
EMAIL="${EMAIL:?defina EMAIL=...}"
SITE_CONF="/etc/nginx/sites-available/quintadafontinha"

[[ $EUID -eq 0 ]] || { echo "Correr com sudo"; exit 1; }

apt-get update -qq
apt-get install -y -qq nginx certbot ssl-cert
install -d -m 755 "$ACME_ROOT" "$WEBROOT"

write_conf() {   # $1 = cert, $2 = key
cat > "$SITE_CONF" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;
    location /.well-known/acme-challenge/ { root $ACME_ROOT; }
    location / { return 301 https://\$host\$request_uri; }
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name $DOMAIN;

    ssl_certificate     $1;
    ssl_certificate_key $2;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_session_cache shared:SSL:10m;

    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # O tunnel entrega todo o tráfego (incl. HTTP) em 443
    location /.well-known/acme-challenge/ { root $ACME_ROOT; }

    root $WEBROOT;
    index index.html;
    location / { try_files \$uri \$uri/ =404; }
    location ~ /\.(?!well-known) { deny all; }
    location ~* \.(css|js|jpg|jpeg|png|webp|svg|ico|woff2?)$ {
        expires 7d;
        add_header Cache-Control "public";
    }
}
EOF
}

LE_CERT="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
LE_KEY="/etc/letsencrypt/live/$DOMAIN/privkey.pem"

if [[ ! -f "$LE_CERT" ]]; then
  echo ">> Fase 1: Nginx com certificado autoassinado temporário"
  write_conf /etc/ssl/certs/ssl-cert-snakeoil.pem /etc/ssl/private/ssl-cert-snakeoil.key
  ln -sf "$SITE_CONF" /etc/nginx/sites-enabled/quintadafontinha
  rm -f /etc/nginx/sites-enabled/default
  nginx -t && systemctl reload nginx

  echo ">> Teste: o desafio ACME é acessível pela Internet?"
  install -d "$ACME_ROOT/.well-known/acme-challenge"
  echo ok > "$ACME_ROOT/.well-known/acme-challenge/ping"
  if ! curl -fsS -m 15 "http://$DOMAIN/.well-known/acme-challenge/ping" | grep -q ok; then
    echo "!! http://$DOMAIN/.well-known/acme-challenge/ping não responde 'ok'."
    echo "   Confirme na rota do tunnel: Service https://localhost:443 + 'Disable TLS verification' ligado."
    exit 1
  fi
  rm -f "$ACME_ROOT/.well-known/acme-challenge/ping"
fi

echo ">> Fase 2: obter/renovar certificado Let's Encrypt"
certbot certonly --non-interactive --agree-tos -m "$EMAIL" \
  --webroot -w "$ACME_ROOT" -d "$DOMAIN" --keep-until-expiring

write_conf "$LE_CERT" "$LE_KEY"
ln -sf "$SITE_CONF" /etc/nginx/sites-enabled/quintadafontinha
nginx -t && systemctl reload nginx

install -d /etc/letsencrypt/renewal-hooks/deploy
printf '#!/bin/sh\nsystemctl reload nginx\n' > /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh
chmod 755 /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh
systemctl enable --now certbot.timer 2>/dev/null || true
certbot renew --dry-run

echo
echo ">> Concluído. Agora, na rota do tunnel '$DOMAIN':"
echo "   - Origin Server Name = $DOMAIN"
echo "   - Disable TLS certificate verification = OFF"
