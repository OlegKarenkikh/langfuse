#!/bin/bash
set -e

echo "🔨 Сборка контейнеров БЕЗ ClickHouse"

# 1. Подготовка entrypoint файлов
echo "📝 Подготовка модифицированных entrypoint файлов..."
cp web/entrypoint.no-clickhouse.sh web/entrypoint.sh
chmod +x web/entrypoint.sh

# 2. Подготовка конфигурации
if [ ! -f .env ]; then
    echo "📝 Создание .env файла..."
    cp .env.no-clickhouse.example .env
fi

# 3. Установка BUILD_ID
export NEXT_PUBLIC_BUILD_ID=${NEXT_PUBLIC_BUILD_ID:-$(git rev-parse --short HEAD 2>/dev/null || echo "local")}

# 4. Сборка worker
echo "🔨 Сборка langfuse-worker..."
docker build \
  -f ./worker/Dockerfile \
  -t langfuse-worker:no-clickhouse \
  --build-arg NEXT_PUBLIC_BUILD_ID=$NEXT_PUBLIC_BUILD_ID \
  .

# 5. Сборка web
echo "🔨 Сборка langfuse-web..."
docker build \
  -f ./web/Dockerfile \
  -t langfuse-web:no-clickhouse \
  --build-arg NEXT_PUBLIC_BUILD_ID=$NEXT_PUBLIC_BUILD_ID \
  .

echo "✅ Сборка завершена!"
echo ""
echo "Запуск контейнеров:"
echo "  docker compose -f docker-compose.no-clickhouse.yml up -d"
echo ""
echo "Тестирование:"
echo "  curl -f http://localhost:3030/api/health  # worker"
echo "  curl -f http://localhost:3000/api/public/health  # web"
