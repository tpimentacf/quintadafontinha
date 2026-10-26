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

Cada `push` para `main` executa `.github/workflows/deploy.yml`, que publica os ficheiros no servidor com `rsync` sobre SSH.
O servidor está numa rede privada (192.168.1.98), por isso o SSH é exposto através de um **Cloudflare Tunnel**
(`ssh-dev.quintadafontinha.pt`) protegido por **Cloudflare Access** com um *service token*.

```
GitHub Actions --cloudflared access ssh--> Cloudflare (Access) --Tunnel--> servidor:22
```

### 1. Chave SSH de deploy (local)

```bash
ssh-keygen -t ed25519 -C "github-deploy" -f deploy_key -N ""
```

### 2. Cloudflare Tunnel (dashboard Zero Trust)

1. **Networks → Connectors → Create a tunnel → Cloudflared**, nome `fontinha-server`. Copiar o token.
2. **Published application routes → Add**: hostname `ssh-dev.quintadafontinha.pt`, service `SSH` → `localhost:22`.

### 3. Cloudflare Access

1. **Access controls → Service credentials → Service Tokens → Create**: `github-deploy`. Guardar Client ID e Secret.
2. **Access controls → Applications → Add → Self-hosted**: domínio `ssh-dev.quintadafontinha.pt`.
   Política: Action **Service Auth**, Include **Service Token = github-deploy**.
   (Opcional: segunda política *Allow* com o seu email para acesso SSH pessoal.)

### 4. Servidor (uma vez)

```bash
scp server/*.sh fontinha@192.168.1.98:~
ssh fontinha@192.168.1.98
sudo TUNNEL_TOKEN=<token> DEPLOY_PUBKEY="$(cat deploy_key.pub)" bash setup-ssh-tunnel.sh   # tunnel + utilizador deploy
sudo CF_API_TOKEN=<token-dns> EMAIL=geral@quintadafontinha.pt bash setup-https.sh          # Nginx + HTTPS 443
ssh-keyscan -t ed25519 localhost | sed 's/^localhost/ssh-dev.quintadafontinha.pt/'      # -> SSH_KNOWN_HOSTS
```

### 5. GitHub Secrets (environment `production`)

| Secret                    | Valor                                      |
|---------------------------|--------------------------------------------|
| `SSH_HOST`                | `ssh-dev.quintadafontinha.pt`              |
| `SSH_USER`                | `deploy`                                   |
| `DEPLOY_PATH`             | `/var/www/quintadafontinha`                |
| `SSH_PRIVATE_KEY`         | conteúdo de `deploy_key`                   |
| `SSH_KNOWN_HOSTS`         | saída do `ssh-keyscan` acima               |
| `CF_ACCESS_CLIENT_ID`     | Client ID do service token                 |
| `CF_ACCESS_CLIENT_SECRET` | Client Secret do service token             |

### Acesso SSH pessoal (opcional)

```bash
brew install cloudflared
cat >> ~/.ssh/config <<EOF
Host ssh-dev.quintadafontinha.pt
  ProxyCommand cloudflared access ssh --hostname %h
EOF
ssh fontinha@ssh-dev.quintadafontinha.pt   # abre o browser para login Access
```
