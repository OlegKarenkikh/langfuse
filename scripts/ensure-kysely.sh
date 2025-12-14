#!/usr/bin/env sh
set -eu

KYS_PATH="packages/kysely"
KYS_REPO="https://github.com/Olegkarenkikh/kysely.git"
KYS_COMMIT="64a12c470b1a5387b842acf09094e2aa1e4149b0"

# Проверка существующего package.json
if [ -f "$KYS_PATH/package.json" ]; then
  echo "✅ Kysely already present in $KYS_PATH"
  exit 0
fi

echo "📦 Fetching Kysely from $KYS_REPO at commit $KYS_COMMIT..."

# КРИТИЧНО: Полностью очистить директорию
rm -rf "$KYS_PATH"
mkdir -p "$(dirname "$KYS_PATH")"

# Клонирование с таймаутами и повторами
if ! git clone --depth 1 "$KYS_REPO" "$KYS_PATH"; then
  echo "❌ Failed to clone kysely repository"
  exit 1
fi

# Переключение на нужный коммит
if ! git -C "$KYS_PATH" fetch --depth 1 origin "$KYS_COMMIT"; then
  echo "❌ Failed to fetch commit $KYS_COMMIT"
  exit 1
fi

git -C "$KYS_PATH" checkout "$KYS_COMMIT"

# Удаление ненужных директорий, которые могут вызывать ошибки (например, невалидный package.json в site/)
echo "🧹 Cleaning up unnecessary directories..."
rm -rf "$KYS_PATH/site" "$KYS_PATH/example"

# Проверка успешности
if [ ! -f "$KYS_PATH/package.json" ]; then
  echo "❌ package.json not found after checkout!"
  exit 1
fi

echo "✅ Kysely successfully initialized"
