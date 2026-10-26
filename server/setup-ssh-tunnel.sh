#!/usr/bin/env bash
# Instala o cloudflared como serviço (tunnel gerido no dashboard) e prepara o
# utilizador "deploy" usado pelo GitHub Actions para publicar o site via rsync.
#
# Uso (no servidor):
#   sudo TUNNEL_TOKEN=eyJh... DEPLOY_PUBKEY="ssh-ed25519 AAAA... github-deploy" bash setup-ssh-tunnel.sh
#
# TUNNEL_TOKEN: Zero Trust -> Networks -> Connectors -> Create a tunnel (Cloudflared)
#               -> copiar o token do comando "cloudflared service install <TOKEN>"
set -euo pipefail

TUNNEL_TOKEN="${TUNNEL_TOKEN:?defina TUNNEL_TOKEN=...}"
DEPLOY_PUBKEY="${DEPLOY_PUBKEY:?defina DEPLOY_PUBKEY=\"ssh-ed25519 ...\"}"
DEPLOY_USER="${DEPLOY_USER:-deploy}"
WEBROOT="${WEBROOT:-/var/www/quintadafontinha}"

[[ $EUID -eq 0 ]] || { echo "Correr com sudo"; exit 1; }

echo ">> Instalar cloudflared (repositório oficial)"
install -d -m 0755 /usr/share/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg -o /usr/share/keyrings/cloudflare-main.gpg
echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main" \
  > /etc/apt/sources.list.d/cloudflared.list
apt-get update -qq
apt-get install -y -qq cloudflared rsync openssh-server

echo ">> Registar o tunnel como serviço"
if systemctl list-unit-files | grep -q '^cloudflared.service'; then
  echo "   cloudflared.service já existe - a reinstalar com o novo token"
  cloudflared service uninstall || true
fi
cloudflared service install "$TUNNEL_TOKEN"
systemctl enable --now cloudflared

echo ">> Utilizador $DEPLOY_USER (só chave, sem password)"
id "$DEPLOY_USER" &>/dev/null || adduser --disabled-password --gecos "" "$DEPLOY_USER"
install -d -m 700 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "/home/$DEPLOY_USER/.ssh"
AUTH="/home/$DEPLOY_USER/.ssh/authorized_keys"
touch "$AUTH"
grep -qxF "$DEPLOY_PUBKEY" "$AUTH" || echo "$DEPLOY_PUBKEY" >> "$AUTH"
chown "$DEPLOY_USER:$DEPLOY_USER" "$AUTH"
chmod 600 "$AUTH"

echo ">> Webroot $WEBROOT"
install -d -m 2775 -o "$DEPLOY_USER" -g www-data "$WEBROOT"
chown -R "$DEPLOY_USER:www-data" "$WEBROOT"

systemctl enable --now ssh 2>/dev/null || systemctl enable --now sshd
systemctl --no-pager --lines=5 status cloudflared
echo ">> Concluído. Verifique no dashboard que o tunnel está HEALTHY."
