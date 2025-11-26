# Минимальная конфигурация: Web + Worker + Postgres + Redis

## ⚠️ Важное примечание

**ClickHouse обязателен для работы Langfuse!** 

У вас есть два варианта:
1. Использовать внешний ClickHouse (уже запущенный)
2. Добавить ClickHouse в docker-compose (рекомендуется для тестирования)

---

## Вариант 1: С внешним ClickHouse

### Шаг 1: Подготовка конфигурации

```bash
# Скопируйте минимальный .env файл
cp .env.minimal.example .env

# Отредактируйте .env и укажите адрес вашего внешнего ClickHouse:
# CLICKHOUSE_URL="http://your-clickhouse-host:8123"
# CLICKHOUSE_MIGRATION_URL="clickhouse://your-clickhouse-host:9000"
```

### Шаг 2: Сборка контейнеров

```bash
# Сборка web и worker
docker compose -f docker-compose.minimal.yml build

# Или только worker
docker compose -f docker-compose.minimal.yml build langfuse-worker

# Или только web
docker compose -f docker-compose.minimal.yml build langfuse-web
```

### Шаг 3: Запуск

```bash
# Запуск всех сервисов
docker compose -f docker-compose.minimal.yml up -d

# Ожидание инициализации
sleep 10
```

### Шаг 4: Тестирование

```bash
# Проверка worker
curl -f http://localhost:3030/api/health

# Проверка web
curl -f http://localhost:3000/api/public/health

# Проверка статусов
docker compose -f docker-compose.minimal.yml ps
```

---

## Вариант 2: С ClickHouse в docker-compose (рекомендуется)

### Шаг 1: Добавьте ClickHouse в docker-compose.minimal.yml

Добавьте сервис ClickHouse в файл `docker-compose.minimal.yml`:

```yaml
services:
  # ... существующие сервисы ...
  
  clickhouse:
    image: docker.io/clickhouse/clickhouse-server
    user: "101:101"
    environment:
      CLICKHOUSE_DB: default
      CLICKHOUSE_USER: clickhouse
      CLICKHOUSE_PASSWORD: clickhouse
    volumes:
      - langfuse_clickhouse_data:/var/lib/clickhouse
      - langfuse_clickhouse_logs:/var/log/clickhouse-server
    ports:
      - "8123:8123"
      - "9000:9000"
    healthcheck:
      test: wget --no-verbose --tries=1 --spider http://localhost:8123/ping || exit 1
      interval: 5s
      timeout: 5s
      retries: 10
      start_period: 1s

volumes:
  # ... существующие volumes ...
  langfuse_clickhouse_data:
    driver: local
  langfuse_clickhouse_logs:
    driver: local
```

И обновите зависимости:

```yaml
langfuse-web:
  depends_on:
    postgres:
      condition: service_healthy
    redis:
      condition: service_healthy
    clickhouse:
      condition: service_healthy

langfuse-worker:
  depends_on:
    postgres:
      condition: service_healthy
    redis:
      condition: service_healthy
    clickhouse:
      condition: service_healthy
```

### Шаг 2: Подготовка конфигурации

```bash
cp .env.minimal.example .env
```

### Шаг 3: Сборка и запуск

```bash
# Сборка
docker compose -f docker-compose.minimal.yml build

# Запуск
docker compose -f docker-compose.minimal.yml up -d

# Ожидание (ClickHouse может занять больше времени)
sleep 15
```

### Шаг 4: Тестирование

```bash
# Проверка всех сервисов
docker compose -f docker-compose.minimal.yml ps

# Проверка worker
curl -f http://localhost:3030/api/health

# Проверка web
curl -f http://localhost:3000/api/public/health

# Проверка ClickHouse
curl http://localhost:8123/ping
```

---

## Полный скрипт для сборки и тестирования

### Сборка langfuse-worker

```bash
# Способ 1: Через docker-compose
docker compose -f docker-compose.minimal.yml build langfuse-worker

# Способ 2: Прямая сборка
export NEXT_PUBLIC_BUILD_ID=$(git rev-parse --short HEAD)
docker build \
  -f ./worker/Dockerfile \
  -t langfuse-worker:minimal \
  --build-arg NEXT_PUBLIC_BUILD_ID=$NEXT_PUBLIC_BUILD_ID \
  .
```

### Тестирование worker

```bash
# Запуск worker
docker compose -f docker-compose.minimal.yml up -d langfuse-worker

# Ожидание
sleep 10

# Проверка health
curl -f http://localhost:3030/api/health

# Проверка логов
docker compose -f docker-compose.minimal.yml logs langfuse-worker

# Проверка статуса
docker compose -f docker-compose.minimal.yml ps langfuse-worker
```

### Тестирование web

```bash
# Запуск web
docker compose -f docker-compose.minimal.yml up -d langfuse-web

# Ожидание
sleep 10

# Проверка health
curl -f http://localhost:3000/api/public/health

# Проверка главной страницы
curl -I http://localhost:3000/

# Проверка логов
docker compose -f docker-compose.minimal.yml logs langfuse-web

# Проверка статуса
docker compose -f docker-compose.minimal.yml ps langfuse-web
```

### Комплексное тестирование обоих контейнеров

```bash
#!/bin/bash
set -e

echo "🚀 Сборка и тестирование минимальной конфигурации"

# 1. Подготовка
echo "📝 Подготовка конфигурации..."
if [ ! -f .env ]; then
    cp .env.minimal.example .env
    echo "⚠️  ВАЖНО: Настройте CLICKHOUSE_URL в .env файле!"
fi

# 2. Сборка
echo "🔨 Сборка контейнеров..."
export NEXT_PUBLIC_BUILD_ID=$(git rev-parse --short HEAD)
docker compose -f docker-compose.minimal.yml build

# 3. Запуск
echo "▶️  Запуск сервисов..."
docker compose -f docker-compose.minimal.yml up -d

# 4. Ожидание
echo "⏳ Ожидание инициализации (20 секунд)..."
sleep 20

# 5. Проверка статусов
echo "🔍 Проверка статусов..."
if docker compose -f docker-compose.minimal.yml ps | grep -q "(unhealthy)"; then
    echo "❌ Один или несколько сервисов unhealthy"
    docker compose -f docker-compose.minimal.yml ps
    exit 1
fi

# 6. Проверка worker
echo "🔧 Тестирование worker..."
if timeout 15 bash -c 'until curl -f http://localhost:3030/api/health; do sleep 2; done'; then
    echo "✅ Worker здоров"
else
    echo "❌ Worker не отвечает"
    docker compose -f docker-compose.minimal.yml logs --tail=50 langfuse-worker
    exit 1
fi

# 7. Проверка web
echo "🌐 Тестирование web..."
if timeout 15 bash -c 'until curl -f http://localhost:3000/api/public/health; do sleep 2; done'; then
    echo "✅ Web здоров"
else
    echo "❌ Web не отвечает"
    docker compose -f docker-compose.minimal.yml logs --tail=50 langfuse-web
    exit 1
fi

echo "🎉 Все тесты пройдены успешно!"
```

---

## Быстрые команды

### Сборка worker
```bash
docker compose -f docker-compose.minimal.yml build langfuse-worker
```

### Запуск всех сервисов
```bash
docker compose -f docker-compose.minimal.yml up -d
```

### Тест worker
```bash
docker compose -f docker-compose.minimal.yml up -d && sleep 10 && curl -f http://localhost:3030/api/health
```

### Тест web
```bash
docker compose -f docker-compose.minimal.yml up -d && sleep 10 && curl -f http://localhost:3000/api/public/health
```

### Просмотр логов
```bash
# Worker
docker compose -f docker-compose.minimal.yml logs -f langfuse-worker

# Web
docker compose -f docker-compose.minimal.yml logs -f langfuse-web

# Все сервисы
docker compose -f docker-compose.minimal.yml logs -f
```

### Остановка
```bash
docker compose -f docker-compose.minimal.yml down
```

### Остановка с удалением volumes
```bash
docker compose -f docker-compose.minimal.yml down -v
```

---

## Структура минимальной конфигурации

```
docker-compose.minimal.yml
├── langfuse-web (порт 3000)
├── langfuse-worker (порт 3030)
├── postgres (порт 5432)
└── redis (порт 6379)
```

**Зависимости:**
- Web и Worker зависят от: Postgres, Redis
- ClickHouse должен быть настроен отдельно (внешний или добавлен в compose)

---

## Устранение неполадок

### Проблема: ClickHouse connection error

**Решение:**
1. Убедитесь, что ClickHouse запущен и доступен
2. Проверьте переменные `CLICKHOUSE_URL` и `CLICKHOUSE_MIGRATION_URL` в `.env`
3. Если используете внешний ClickHouse, проверьте сетевую доступность

### Проблема: Worker не обрабатывает задачи

**Решение:**
1. Проверьте подключение к Redis: `docker compose -f docker-compose.minimal.yml exec redis redis-cli ping`
2. Убедитесь, что `REDIS_AUTH` совпадает в `.env` и команде Redis
3. Проверьте логи worker на ошибки подключения

### Проблема: Web не запускается

**Решение:**
1. Проверьте логи: `docker compose -f docker-compose.minimal.yml logs langfuse-web`
2. Убедитесь, что миграции PostgreSQL выполнены
3. Проверьте переменные окружения в `.env`
