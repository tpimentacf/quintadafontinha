# Quinta da Fontinha – Website

Website estático (HTML/CSS/JS) da Quinta da Fontinha – Alojamento e Restauração, Celorico de Basto.

## Estrutura

```
index.html
assets/css/style.css
assets/js/main.js
assets/img/
.github/workflows/deploy.yml
```

## Desenvolvimento local

```bash
python3 -m http.server 8080
# abrir http://localhost:8080
```

## Deploy automático

Cada `push` para `main` executa o workflow `.github/workflows/deploy.yml`, que sincroniza os ficheiros com o VPS via `rsync` sobre SSH.

### 1. Preparar o servidor (uma vez)

```bash
# no VPS (exemplo Ubuntu + Nginx)
sudo apt install -y nginx rsync
sudo adduser --disabled-password --gecos "" deploy
sudo mkdir -p /var/www/quintadafontinha
sudo chown -R deploy:www-data /var/www/quintadafontinha
```

Configuração Nginx (`/etc/nginx/sites-available/quintadafontinha`):

```nginx
server {
    listen 80;
    server_name quintadafontinha.pt www.quintadafontinha.pt;
    root /var/www/quintadafontinha;
    index index.html;
    location / { try_files $uri $uri/ =404; }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/quintadafontinha /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

### 2. Chave SSH de deploy

```bash
ssh-keygen -t ed25519 -C "github-deploy" -f deploy_key -N ""
# copiar deploy_key.pub para /home/deploy/.ssh/authorized_keys no VPS
```

### 3. GitHub Secrets

Em **Settings → Secrets and variables → Actions** (ou no environment `production`):

| Secret            | Exemplo                          |
|-------------------|----------------------------------|
| `SSH_HOST`        | `203.0.113.10`                   |
| `SSH_USER`        | `deploy`                         |
| `SSH_PORT`        | `22` (opcional)                  |
| `SSH_PRIVATE_KEY` | conteúdo do ficheiro `deploy_key`|
| `DEPLOY_PATH`     | `/var/www/quintadafontinha`      |
