#!/usr/bin/env bash
# 行情通 · 本地一键推送到腾讯云轻量服务器
# 用法：在 stock-quotes 目录下执行  ./deploy/deploy.sh
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$DIR")"
CONF="$DIR/deploy.conf"

if [[ ! -f "$CONF" ]]; then
  echo "找不到 $CONF，请先复制一份并填写 SERVER_IP"
  exit 1
fi

# shellcheck disable=SC1090
source "$CONF"

if [[ -z "${SERVER_IP:-}" || "$SERVER_IP" == "1.2.3.4" ]]; then
  echo "请先在 deploy/deploy.conf 里把 SERVER_IP 改成真实的公网 IP"
  exit 1
fi

command -v rsync >/dev/null 2>&1 || { echo "本机缺少 rsync，请先安装"; exit 1; }

echo "目标：$SERVER_USER@$SERVER_IP:${REMOTE_DIR:-/var/www/hahastock} (SSH ${SSH_PORT:-22})"

# 先确认远端目录存在，不存在就顺手建一个
ssh -p "${SSH_PORT:-22}" -o StrictHostKeyChecking=accept-new \
  "$SERVER_USER@$SERVER_IP" "sudo mkdir -p ${REMOTE_DIR:-/var/www/hahastock} 2>/dev/null || mkdir -p ${REMOTE_DIR:-/var/www/hahastock}"

cd "$ROOT"

rsync -avz --delete \
  --exclude 'deploy/' \
  --exclude '.git/' \
  --exclude '.DS_Store' \
  --exclude '*.bak' \
  -e "ssh -p ${SSH_PORT:-22}" \
  ./ "$SERVER_USER@$SERVER_IP:${REMOTE_DIR:-/var/www/hahastock}/"

cat <<EOF

推送完成。
  HTTP  ：http://$SERVER_IP
  HTTPS ：https://$SERVER_IP   （自签证书，首次需点「继续访问」）

提示：HTTPS 下持仓预警的系统通知才可用。
EOF
