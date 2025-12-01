#!/usr/bin/env bash
set -e

###########################################################
# SchedulerBot Production Installer v1
# 使用方式（Ubuntu 伺服器）：
#
#   chmod +x install_production.sh
#   ./install_production.sh schedulerbot.com admin@example.com
#
# 若省略參數，預設：
#   DOMAIN = schedulerbot.com
#   EMAIL  = admin@example.com
###########################################################

DOMAIN="${1:-schedulerbot.com}"
EMAIL="${2:-admin@example.com}"

echo "🚀 SchedulerBot Production Installer v1"
echo "--------------------------------------"
echo "Domain : ${DOMAIN}"
echo "Email  : ${EMAIL}"
echo

# 需要 root 或有 sudo 權限
if [ "$EUID" -ne 0 ]; then
  if ! command -v sudo >/dev/null 2>&1; then
    echo "❌ 請用 root 或安裝 sudo 再執行此腳本。"
    exit 1
  fi
fi

run_cmd() {
  if [ "$EUID" -ne 0 ]; then
    sudo bash -c "$1"
  else
    bash -c "$1"
  fi
}

###########################################################
# 1. 安裝 Docker
###########################################################
if ! command -v docker >/dev/null 2>&1; then
  echo "🐳 未找到 docker，開始安裝..."
  run_cmd "apt-get update"
  run_cmd "apt-get install -y ca-certificates curl gnupg lsb-release"

  run_cmd "mkdir -p /etc/apt/keyrings"
  run_cmd "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg"
  run_cmd "echo \
    \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    \$(lsb_release -cs) stable\" | tee /etc/apt/sources.list.d/docker.list > /dev/null"

  run_cmd "apt-get update"
  run_cmd "apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
else
  echo "🐳 Docker 已安裝，略過。"
fi

###########################################################
# 2. 確認 docker compose 可用
###########################################################
if docker compose version >/dev/null 2>&1; then
  echo "📦 docker compose 已可使用。"
else
  echo "📦 安裝 docker compose plugin..."
  run_cmd "apt-get update"
  run_cmd "apt-get install -y docker-compose-plugin"
fi

###########################################################
# 3. 寫入 .env (SB_DOMAIN / SB_EMAIL)
###########################################################
echo "📝 建立 .env 檔案（SB_DOMAIN / SB_EMAIL）..."

cat > .env <<EOF
SB_DOMAIN=${DOMAIN}
SB_EMAIL=${EMAIL}
EOF

echo ".env 內容："
cat .env
echo

###########################################################
# 4. 建立必要目錄（db / caddy 資料）
###########################################################
mkdir -p social-scheduler-api/db
mkdir -p caddy_data
mkdir -p caddy_config

###########################################################
# 5. 使用 docker compose 啟動
###########################################################
echo "🚀 透過 docker compose 建立 / 啟動容器..."

# 先確保舊容器關閉（如果有）
if docker ps -a --format '{{.Names}}' | grep -q '^schedulerbot$'; then
  echo "   偵測到舊的 schedulerbot 容器，先停用並刪除..."
  docker compose down || true
fi

# build + up
docker compose build
docker compose up -d

echo
echo "✅ SchedulerBot 容器已啟動。"
echo

###########################################################
# 6. 顯示狀態 & 提示
###########################################################
echo "📦 目前容器狀態："
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | sed 's/^/  /'
echo

IP=$(curl -s https://ipinfo.io/ip || echo "YOUR_SERVER_IP")

echo "🎉 安裝完成！"
echo
echo "請確認你的 DNS 已將："
echo "  ${DOMAIN}  → 指向此伺服器 IP (${IP})"
echo
echo "幾分鐘後，打開瀏覽器："
echo "  https://${DOMAIN}"
echo
echo "第一次開啟時 Caddy 會自動申請 HTTPS 憑證，"
echo "若畫面顯示 SchedulerBot UI（Setup Admin / Login），就代表成功 🎯"
echo
echo "若要查看日誌，可執行："
echo "  docker logs -f schedulerbot"
echo "  docker logs -f schedulerbot-caddy"
echo
