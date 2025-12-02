#!/usr/bin/env bash
set -euo pipefail

# =========================
# SchedulerBot 更新腳本
# 使用方式：
#   bash update.sh --version 1.1.0 [--token YOUR_PAT]
#
# 也可以用環境變數：
#   export SCHEDULERBOT_VERSION=1.1.0
#   export GHCR_TOKEN=ghp_xxx...
#   bash update.sh
# =========================

IMAGE_BASE="ghcr.io/gda-project-dev/schedulerbot"
CONTAINER_NAME="${CONTAINER_NAME:-schedulerbot}"

# 可以用環境變數覆蓋
HOST_PORT="${HOST_PORT:-3067}"
DB_DIR="${DB_DIR:-/opt/schedulerbot/db}"
EXTRA_DOCKER_ARGS="${EXTRA_DOCKER_ARGS:-}"

VERSION="${SCHEDULERBOT_VERSION:-}"
TOKEN="${GHCR_TOKEN:-}"

# ----- 解析參數 -----
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version|-v)
      VERSION="$2"
      shift 2
      ;;
    --token)
      TOKEN="$2"
      shift 2
      ;;
    --help|-h)
      cat <<EOF
SchedulerBot 更新腳本

用法：
  bash update.sh --version 1.1.0 [--token YOUR_GHCR_PAT]

或使用環境變數：
  export SCHEDULERBOT_VERSION=1.1.0
  export GHCR_TOKEN=ghp_xxx...
  bash update.sh

可覆蓋的環境變數：
  CONTAINER_NAME  (預設: schedulerbot)
  HOST_PORT       (預設: 3067)
  DB_DIR          (預設: /opt/schedulerbot/db)
  EXTRA_DOCKER_ARGS (附加到 docker run 後面)
EOF
      exit 0
      ;;
    *)
      echo "未知參數: $1"
      echo "使用 --help 查看說明"
      exit 1
      ;;
  esac
done

if [[ -z "$VERSION" ]]; then
  echo "❌ 必須指定版本號，例如："
  echo "   bash update.sh --version 1.0.1"
  exit 1
fi

IMAGE_TAG="${IMAGE_BASE}:${VERSION}"

echo "========================================"
echo "🚀 更新 SchedulerBot"
echo "  Image:      ${IMAGE_TAG}"
echo "  Container:  ${CONTAINER_NAME}"
echo "  Host Port:  ${HOST_PORT}"
echo "  DB Dir:     ${DB_DIR}"
echo "========================================"

# ----- Docker login（如提供 token）-----
if [[ -n "$TOKEN" ]]; then
  echo "🔐 使用提供的 GHCR token 登入 ghcr.io..."
  echo "$TOKEN" | docker login ghcr.io -u gda-project-dev --password-stdin
else
  echo "ℹ️ 未提供 GHCR_TOKEN / --token，假設已經登錄過 ghcr.io。"
fi

# ----- 確保 DB 目錄存在 -----
if [[ ! -d "$DB_DIR" ]]; then
  echo "📁 建立 DB 目錄: $DB_DIR"
  mkdir -p "$DB_DIR"
fi

# ----- Pull 新版本 -----
echo "📦 拉取 image: ${IMAGE_TAG}"
docker pull "$IMAGE_TAG"

# ----- 停止並移除舊 container（如果存在） -----
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}\$"; then
  echo "🛑 停止舊容器: ${CONTAINER_NAME}"
  docker stop "$CONTAINER_NAME" || true

  echo "🧹 移除舊容器: ${CONTAINER_NAME}"
  docker rm "$CONTAINER_NAME" || true
else
  echo "ℹ️ 找不到舊容器 ${CONTAINER_NAME}，跳過停止 / 移除步驟。"
fi

# ----- 啟動新版本 -----
echo "🐳 啟動新版本容器..."
docker run -d \
  --name "$CONTAINER_NAME" \
  -p ${HOST_PORT}:3067 \
  -v "${DB_DIR}:/app/social-scheduler-api/db" \
  --restart unless-stopped \
  $EXTRA_DOCKER_ARGS \
  "$IMAGE_TAG"

echo "✅ 更新完成！目前執行版本：${IMAGE_TAG}"
echo "➡️ 請在瀏覽器開啟： http://<這台伺服器IP>:${HOST_PORT}"
