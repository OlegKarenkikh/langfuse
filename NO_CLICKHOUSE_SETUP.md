# Конфигурация БЕЗ ClickHouse: Web + Worker + Postgres + Redis

## ⚠️ Важное предупреждение

**ClickHouse отключен в этой конфигурации.** Используются фиктивные значения для обхода валидации в entrypoint скриптах. 

**Обратите внимание:** Некоторые функции Langfuse могут не работать без ClickHouse, так как он используется для хранения аналитических данных (traces, observations, scores).

---

## Конкретные команды

### 1. Сборка langfuse-worker

```bash
# Способ 1: Через docker-compose (рекомендуется)
docker compose -f docker-compose.no-clickhouse.yml build langfuse-worker

# Способ 2: Прямая сборка
export NEXT_PUBLIC_BUILD_ID=$(git rev-parse --short HEAD)
docker build \
  -f ./worker/Dockerfile \
  -t langfuse-worker:no-clickhouse \
  --build-arg NEXT_PUBLIC_BUILD_ID=$NEXT_PUBLIC_BUILD_ID \
  .
```

### 2. Подготовка окружения

Файл `.env` не обязателен: все значения для режима без ClickHouse уже заданы
в `docker-compose.no-clickhouse.yml` через значения по умолчанию. Создайте
`.env` только если хотите переопределить переменные (например, пароли или порты).

### 3. Запуск всех сервисов

```bash
# Запуск postgres, redis, web, worker
docker compose -f docker-compose.no-clickhouse.yml up -d

# Ожидание инициализации
sleep 15
```

### 5. Тестирование worker

```bash
# Проверка health endpoint
curl -f http://localhost:3030/api/health

# Проверка статуса контейнера
docker compose -f docker-compose.no-clickhouse.yml ps langfuse-worker

# Просмотр логов
docker compose -f docker-compose.no-clickhouse.yml logs langfuse-worker

# Просмотр последних 50 строк логов
docker compose -f docker-compose.no-clickhouse.yml logs --tail=50 langfuse-worker
```

### 6. Тестирование web

```bash
# Проверка health endpoint
curl -f http://localhost:3000/api/public/health

# Проверка главной страницы
curl -I http://localhost:3000/

# Проверка статуса контейнера
docker compose -f docker-compose.no-clickhouse.yml ps langfuse-web

# Просмотр логов
docker compose -f docker-compose.no-clickhouse.yml logs langfuse-web

# Просмотр последних 50 строк логов
docker compose -f docker-compose.no-clickhouse.yml logs --tail=50 langfuse-web
```

### 7. Комплексная проверка обоих контейнеров

```bash
# Проверка отсутствия unhealthy статусов
if docker compose -f docker-compose.no-clickhouse.yml ps | grep -q "(unhealthy)"; then
    echo "❌ Есть unhealthy сервисы"
    docker compose -f docker-compose.no-clickhouse.yml ps
    docker compose -f docker-compose.no-clickhouse.yml logs --tail=100
else
    echo "✅ Все сервисы здоровы"
fi

# Проверка worker с таймаутом
echo "Проверка worker..."
timeout 15 bash -c 'until curl -f http://localhost:3030/api/health; do sleep 2; done' && echo "✅ Worker OK"

# Проверка web с таймаутом
echo "Проверка web..."
timeout 15 bash -c 'until curl -f http://localhost:3000/api/public/health; do sleep 2; done' && echo "✅ Web OK"
```

---

## Полный скрипт "все в одном"

```bash
#!/bin/bash
set -e

echo "🚀 Сборка и тестирование БЕЗ ClickHouse: worker + web + postgres + redis"

# 1. Подготовка
echo "📝 Подготовка конфигурации..."
if [ -f .env ]; then
    echo "✅ Используем существующий .env"
else
    echo "ℹ️  .env не найден — используются значения по умолчанию из docker-compose"
fi

# 2. Сборка worker
echo "🔨 Сборка langfuse-worker..."
export NEXT_PUBLIC_BUILD_ID=$(git rev-parse --short HEAD)
docker compose -f docker-compose.no-clickhouse.yml build langfuse-worker

# 4. Сборка web
echo "🔨 Сборка langfuse-web..."
docker compose -f docker-compose.no-clickhouse.yml build langfuse-web

# 5. Запуск
echo "▶️  Запуск сервисов..."
docker compose -f docker-compose.no-clickhouse.yml up -d

# 6. Ожидание
echo "⏳ Ожидание инициализации (20 секунд)..."
sleep 20

# 7. Проверка статусов
echo "🔍 Проверка статусов..."
docker compose -f docker-compose.no-clickhouse.yml ps

# 8. Проверка отсутствия unhealthy
if docker compose -f docker-compose.no-clickhouse.yml ps | grep -q "(unhealthy)"; then
    echo "❌ Есть unhealthy сервисы"
    docker compose -f docker-compose.no-clickhouse.yml ps
    docker compose -f docker-compose.no-clickhouse.yml logs --tail=100
    exit 1
fi

# 9. Тест worker
echo "🔧 Тестирование worker..."
if timeout 15 bash -c 'until curl -f http://localhost:3030/api/health; do sleep 2; done'; then
    echo "✅ Worker здоров"
else
    echo "❌ Worker не отвечает"
    docker compose -f docker-compose.no-clickhouse.yml logs --tail=50 langfuse-worker
    exit 1
fi

# 10. Тест web
echo "🌐 Тестирование web..."
if timeout 15 bash -c 'until curl -f http://localhost:3000/api/public/health; do sleep 2; done'; then
    echo "✅ Web здоров"
else
    echo "❌ Web не отвечает"
    docker compose -f docker-compose.no-clickhouse.yml logs --tail=50 langfuse-web
    exit 1
fi

echo "🎉 Все тесты пройдены успешно!"
```

---

## Быстрые команды (копировать и выполнять)

### Только сборка worker:
```bash
docker compose -f docker-compose.no-clickhouse.yml build langfuse-worker
```

### Быстрый тест worker:
```bash
docker compose -f docker-compose.no-clickhouse.yml up -d langfuse-worker && sleep 10 && curl -f http://localhost:3030/api/health
```

### Быстрый тест web:
```bash
docker compose -f docker-compose.no-clickhouse.yml up -d langfuse-web && sleep 10 && curl -f http://localhost:3000/api/public/health
```

### Полный тест:
```bash
docker compose -f docker-compose.no-clickhouse.yml build && \
docker compose -f docker-compose.no-clickhouse.yml up -d && \
sleep 20 && \
curl -f http://localhost:3030/api/health && \
curl -f http://localhost:3000/api/public/health && \
echo "✅ Все проверки пройдены"
```

### Просмотр логов:
```bash
# Worker
docker compose -f docker-compose.no-clickhouse.yml logs -f langfuse-worker

# Web
docker compose -f docker-compose.no-clickhouse.yml logs -f langfuse-web

# Все сервисы
docker compose -f docker-compose.no-clickhouse.yml logs -f
```

### Остановка:
```bash
docker compose -f docker-compose.no-clickhouse.yml down
```

### Остановка с удалением volumes:
```bash
docker compose -f docker-compose.no-clickhouse.yml down -v
```

---

## Структура конфигурации

```
docker-compose.no-clickhouse.yml
├── langfuse-web (порт 3000)
├── langfuse-worker (порт 3030)
├── postgres (порт 5432)
└── redis (порт 6379)

НЕТ ClickHouse!
```

---

## Устранение неполадок

### Проблема: Entrypoint требует ClickHouse

**Решение:**
1. Используйте модифицированный entrypoint: `web/entrypoint.no-clickhouse.sh`
2. Скопируйте его: `cp web/entrypoint.no-clickhouse.sh web/entrypoint.sh`
3. Или модифицируйте Dockerfile чтобы использовать модифицированный entrypoint

### Проблема: Приложение не запускается из-за ClickHouse

**Решение:**
1. Убедитесь, что в `.env` установлены фиктивные значения ClickHouse
2. Установите `LANGFUSE_AUTO_CLICKHOUSE_MIGRATION_DISABLED=true`
3. Проверьте логи на наличие ошибок подключения к ClickHouse

### Проблема: Worker не обрабатывает задачи

**Решение:**
1. Проверьте подключение к Redis: 
   ```bash
   docker compose -f docker-compose.no-clickhouse.yml exec redis redis-cli -a myredissecret ping
   ```
2. Убедитесь, что `REDIS_AUTH` совпадает в `.env` и команде Redis
3. Проверьте логи worker на ошибки подключения

### Проблема: Web не запускается

**Решение:**
1. Проверьте логи: `docker compose -f docker-compose.no-clickhouse.yml logs langfuse-web`
2. Убедитесь, что миграции PostgreSQL выполнены
3. Проверьте переменные окружения в `.env`

---

## Ограничения без ClickHouse

Без ClickHouse следующие функции могут не работать или работать ограниченно:

- ❌ Хранение traces (трейсов)
- ❌ Хранение observations (наблюдений)
- ❌ Хранение scores (оценок)
- ❌ Аналитика и метрики
- ❌ Исторические данные

Работают:
- ✅ API endpoints
- ✅ Health checks
- ✅ Базовая функциональность приложения
- ✅ PostgreSQL операции

---

## Файлы конфигурации

- `docker-compose.no-clickhouse.yml` - docker-compose без ClickHouse
- `.env` (опционально) - локальные переопределения переменных окружения
- `web/entrypoint.no-clickhouse.sh` - модифицированный entrypoint для web
- `worker/entrypoint.no-clickhouse.sh` - модифицированный entrypoint для worker
