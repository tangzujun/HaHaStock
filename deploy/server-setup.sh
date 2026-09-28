#!/usr/bin/env bash
# 行情通 · 腾讯云轻量服务器（Ubuntu）初始化脚本
# 用法：ssh 登录服务器后执行  chmod +x server-setup.sh && ./server-setup.sh
# 可传参指定公网 IP：./server-setup.sh 1.2.3.4   （不传则自动探测）
set -euo pipefail

SITE_DIR="/var/www/hahastock"
SSL_DIR="/etc/nginx/ssl"
NGINX_CONF="/etc/nginx/sites-available/hahastock"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "请用 root 执行（或 sudo ./server-setup.sh）"
  exit 1
fi

echo "==> 安装 nginx"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq nginx openssl curl >/dev/null

echo "==> 探测公网 IP"
PUBLIC_IP="${1:-}"
if [[ -z "$PUBLIC_IP" ]]; then
  PUBLIC_IP="$(curl -s --max-time 5 https://api.ipify.org || true)"
  [[ -z "$PUBLIC_IP" ]] && PUBLIC_IP="$(curl -s --max-time 5 ifconfig.me || true)"
fi
if [[ -z "$PUBLIC_IP" ]]; then
  read -r -p "自动探测失败，请输入本机公网 IP: " PUBLIC_IP
fi
echo "    公网 IP：$PUBLIC_IP"

echo "==> 准备站点目录 $SITE_DIR"
mkdir -p "$SITE_DIR"
if [[ ! -f "$SITE_DIR/index.html" ]]; then
  cat > "$SITE_DIR/index.html" <<'HTML'
<!doctype html><meta charset="utf-8"><title>行情通</title>
<h1>行情通</h1><p>站点目录已就绪，请在本地执行 <code>./deploy/deploy.sh</code> 推送文件。</p>
HTML
fi
chown -R www-data:www-data "$SITE_DIR"

echo "==> 生成自签 HTTPS 证书（10 年）"
mkdir -p "$SSL_DIR"
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout "$SSL_DIR/server.key" \
  -out "$SSL_DIR/server.crt" \
  -subj "/CN=${PUBLIC_IP}" \
  -addext "subjectAltName=IP:${PUBLIC_IP},DNS:localhost" >/dev/null 2>&1
chmod 600 "$SSL_DIR/server.key"
chmod 644 "$SSL_DIR/server.crt"

echo "==> 写入 nginx 配置 $NGINX_CONF"
cat > "$NGINX_CONF" <<'CONF'
server {
    listen 80;
    listen [::]:80;
    server_name _;

    root /var/www/hahastock;
    index index.html;
    charset utf-8;

    access_log /var/log/nginx/hahastock.access.log;
    error_log  /var/log/nginx/hahastock.error.log;

    location ~* \.(html|json|md)$ {
        add_header Cache-Control "no-cache, must-revalidate";
        try_files $uri =404;
    }

    location ^~ /vendor/ {
        expires 30d;
        add_header Cache-Control "public, max-age=2592000";
        try_files $uri =404;
    }

    location / {
        try_files $uri $uri/ =404;
    }

    gzip on;
    gzip_types text/html text/css application/javascript application/json text/plain;
    gzip_min_length 1024;
    client_max_body_size 10m;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name _;

    root /var/www/hahastock;
    index index.html;
    charset utf-8;

    ssl_certificate     /etc/nginx/ssl/server.crt;
    ssl_certificate_key /etc/nginx/ssl/server.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;

    access_log /var/log/nginx/hahastock.access.log;
    error_log  /var/log/nginx/hahastock.error.log;

    location ~* \.(html|json|md)$ {
        add_header Cache-Control "no-cache, must-revalidate";
        try_files $uri =404;
    }

    location ^~ /vendor/ {
        expires 30d;
        add_header Cache-Control "public, max-age=2592000";
        try_files $uri =404;
    }

    location / {
        try_files $uri $uri/ =404;
    }

    gzip on;
    gzip_types text/html text/css application/javascript application/json text/plain;
    gzip_min_length 1024;
    client_max_body_size 10m;
}
CONF

ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/hahastock
rm -f /etc/nginx/sites-enabled/default

echo "==> 校验并启动 nginx"
nginx -t
systemctl enable nginx >/dev/null 2>&1 || true
systemctl restart nginx

if command -v ufw >/dev/null 2>&1 && ufw status | grep -qi active; then
  ufw allow 22/tcp   >/dev/null 2>&1 || true
  ufw allow 80/tcp   >/dev/null 2>&1 || true
  ufw allow 443/tcp  >/dev/null 2>&1 || true
  echo "==> 已放行 ufw 22/80/443"
fi

cat <<EOF

初始化完成。

  HTTP  : http://$PUBLIC_IP
  HTTPS : https://$PUBLIC_IP   （自签证书，浏览器点一次「继续访问」即可）

下一步（在本地 Mac 上）：
  1. 编辑 stock-quotes/deploy/deploy.conf，填入 SERVER_IP="$PUBLIC_IP"
  2. ./deploy/deploy.sh

⚠️ 别忘了在腾讯云轻量控制台 → 防火墙，放行 22 / 80 / 443（TCP）。
   如果 80/443 被备案监测拦截，改成本脚本里换成 8080/8443 并同步放行防火墙。
EOF
