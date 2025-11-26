# Инструкции по сборке и тестированию контейнеров Langfuse

## Содержание

1. [Сборка контейнера langfuse-worker](#сборка-контейнера-langfuse-worker)
2. [Сборка контейнера langfuse-web](#сборка-контейнера-langfuse-web)
3. [Тестирование собранных контейнеров](#тестирование-собранных-контейнеров)
4. [Ручное тестирование](#ручное-тестирование)
5. [Автоматическое тестирование через CI/CD](#автоматическое-тестирование-через-cicd)

---

## Сборка контейнера langfuse-worker

### Требования

- Docker и Docker Compose установлены
- Git репозиторий Langfuse склонирован
- Достаточно места на диске (образы могут быть большими)

### Способ 1: Сборка через Docker Compose (рекомендуется)

Используйте файл `docker-compose.build.yml` для сборки обоих контейнеров:

```bash
# Перейдите в корневую директорию репозитория
cd /workspace

# Соберите контейнеры
docker compose -f docker-compose.build.yml build

# Или соберите только worker
docker compose -f docker-compose.build.yml build langfuse-worker
```

### Способ 2: Прямая сборка через Docker

```bash
# Сборка из корня репозитория (важно!)
docker build \
  -f ./worker/Dockerfile \
  -t langfuse-worker:local \
  --build-arg NEXT_PUBLIC_BUILD_ID=$(git rev-parse --short HEAD) \
  .
```

**Важно:** Dockerfile должен запускаться из корня репозитория, так как он использует `turbo prune` для изоляции зависимостей.

### Параметры сборки

Контейнер worker поддерживает следующие build-аргументы:

- `NEXT_PUBLIC_BUILD_ID` - ID сборки (обычно git commit hash)
- `NEXT_PUBLIC_LANGFUSE_CLOUD_REGION` - Регион облака Langfuse (опционально)
- `TARGETPLATFORM` - Платформа сборки (например, `linux/amd64`, `linux/arm64`)
- `UID` / `GID` - UID/GID пользователя для запуска контейнера (по умолчанию 1001)

### Пример сборки с параметрами

```bash
docker build \
  -f ./worker/Dockerfile \
  -t langfuse-worker:custom \
  --build-arg NEXT_PUBLIC_BUILD_ID=$(git rev-parse --short HEAD) \
  --build-arg TARGETPLATFORM=linux/amd64 \
  --build-arg UID=1001 \
  --build-arg GID=1001 \
  .
```

---

## Сборка контейнера langfuse-web

### Способ 1: Через Docker Compose

```bash
docker compose -f docker-compose.build.yml build langfuse-web
```

### Способ 2: Прямая сборка через Docker

```bash
docker build \
  -f ./web/Dockerfile \
  -t langfuse-web:local \
  --build-arg NEXT_PUBLIC_BUILD_ID=$(git rev-parse --short HEAD) \
  .
```

### Дополнительные параметры для web-контейнера

Web-контейнер поддерживает дополнительные build-аргументы:

- `NEXT_PUBLIC_PLAIN_APP_ID`
- `NEXT_PUBLIC_DEMO_ORG_ID`
- `NEXT_PUBLIC_DEMO_PROJECT_ID`
- `NEXT_PUBLIC_POSTHOG_KEY`
- `NEXT_PUBLIC_POSTHOG_HOST`
- `NEXT_PUBLIC_SIGN_UP_DISABLED`
- `SENTRY_AUTH_TOKEN`, `SENTRY_ORG`, `SENTRY_PROJECT` (для production сборок)

---

## Тестирование собранных контейнеров

### Предварительные требования

Перед тестированием убедитесь, что запущены все зависимости:

1. **PostgreSQL** (порт 5432)
2. **ClickHouse** (порты 8123, 9000)
3. **Redis** (порт 6379)
4. **MinIO** (порт 9000)

### Быстрый старт зависимостей

```bash
# Запустите инфраструктуру для разработки
pnpm run infra:dev:up

# Или через docker-compose напрямую
docker compose -f docker-compose.dev.yml up -d
```

### Проверка здоровья зависимостей

```bash
# Проверьте статус всех сервисов
docker compose ps

# Убедитесь, что нет unhealthy сервисов
docker compose ps | grep unhealthy
# Если команда ничего не выводит - все сервисы здоровы
```

---

## Ручное тестирование

### Шаг 1: Подготовка окружения

```bash
# Скопируйте пример конфигурации
cp .env.dev.example .env

# При необходимости отредактируйте .env файл
```

### Шаг 2: Запуск контейнеров через docker-compose.build.yml

```bash
# Соберите и запустите контейнеры
docker compose -f docker-compose.build.yml up -d

# Подождите несколько секунд для инициализации
sleep 5
```

### Шаг 3: Проверка здоровья контейнеров

#### Проверка worker

```bash
# Проверка health endpoint worker
curl -f http://localhost:3030/api/health

# Ожидаемый ответ: {"status":"ok"} или подобный JSON
```

#### Проверка web

```bash
# Проверка health endpoint web
curl -f http://localhost:3000/api/public/health

# Ожидаемый ответ: {"status":"ok"} или подобный JSON
```

### Шаг 4: Проверка статуса через Docker

```bash
# Проверьте статус всех контейнеров
docker compose -f docker-compose.build.yml ps

# Проверьте логи worker
docker compose -f docker-compose.build.yml logs langfuse-worker

# Проверьте логи web
docker compose -f docker-compose.build.yml logs langfuse-web
```

### Шаг 5: Проверка отсутствия unhealthy статусов

```bash
# Скрипт для проверки
if docker compose -f docker-compose.build.yml ps | grep -q "(unhealthy)"; then
    echo "❌ Один или несколько сервисов имеют статус unhealthy"
    docker compose -f docker-compose.build.yml ps
    exit 1
else
    echo "✅ Все сервисы здоровы"
fi
```

### Шаг 6: Функциональное тестирование

#### Тест worker

```bash
# Проверка доступности API worker
curl http://localhost:3030/api/health

# Проверка обработки задач (если есть соответствующие endpoints)
```

#### Тест web

```bash
# Проверка главной страницы
curl http://localhost:3000/

# Проверка API endpoints
curl http://localhost:3000/api/public/health
```

### Шаг 7: Остановка контейнеров

```bash
# Остановите и удалите контейнеры
docker compose -f docker-compose.build.yml down

# Или остановите без удаления
docker compose -f docker-compose.build.yml stop
```

---

## Автоматическое тестирование через CI/CD

Проект использует GitHub Actions для автоматического тестирования контейнеров. Процесс описан в `.github/workflows/pipeline.yml`.

### Job: test-docker-build

Этот job автоматически:

1. **Собирает контейнеры** через `docker-compose.build.yml`
2. **Запускает их** с зависимостями
3. **Проверяет здоровье** обоих сервисов
4. **Валидирует** отсутствие unhealthy статусов

### Локальный запуск тестов CI/CD

Вы можете воспроизвести процесс CI/CD локально:

```bash
# 1. Установите зависимости (если еще не установлены)
pnpm install

# 2. Установите переменную окружения BUILD_ID
export NEXT_PUBLIC_BUILD_ID=$(git rev-parse --short HEAD)

# 3. Соберите контейнеры
docker compose --progress plain --verbose -f docker-compose.build.yml build --print > /tmp/bake.json
docker buildx bake -f /tmp/bake.json

# 4. Запустите контейнеры
docker compose --progress plain -f docker-compose.build.yml up -d

# 5. Подождите инициализации
sleep 5

# 6. Проверьте отсутствие unhealthy статусов
if docker compose -f docker-compose.build.yml ps | grep "(unhealthy)"; then
    echo "Один или несколько сервисов unhealthy"
    exit 1
else
    echo "Все сервисы здоровы"
fi

# 7. Проверьте health endpoints
timeout 10 bash -c 'until curl -f http://localhost:3030/api/health; do sleep 2; done'
timeout 10 bash -c 'until curl -f http://localhost:3000/api/public/health; do sleep 2; done'

# 8. Остановите контейнеры
docker compose -f docker-compose.build.yml down
```

---

## Устранение неполадок

### Проблема: Контейнер не запускается

**Решение:**
1. Проверьте логи: `docker compose logs <service-name>`
2. Убедитесь, что все зависимости запущены и здоровы
3. Проверьте переменные окружения в `.env` файле
4. Убедитесь, что порты не заняты другими процессами

### Проблема: Health check не проходит

**Решение:**
1. Подождите больше времени (миграции БД могут занять время)
2. Проверьте подключение к базе данных
3. Проверьте логи контейнера на наличие ошибок
4. Убедитесь, что ClickHouse миграции выполнены успешно

### Проблема: Ошибки при сборке

**Решение:**
1. Убедитесь, что сборка запускается из корня репозитория
2. Проверьте, что все зависимости установлены (`pnpm install`)
3. Очистите кэш Docker: `docker builder prune`
4. Пересоберите без кэша: `docker build --no-cache ...`

### Проблема: Контейнер worker не обрабатывает задачи

**Решение:**
1. Проверьте подключение к Redis
2. Убедитесь, что Redis пароль настроен правильно
3. Проверьте логи worker на наличие ошибок подключения
4. Убедитесь, что очереди BullMQ настроены корректно

---

## Дополнительные ресурсы

- [Dockerfile worker](./worker/Dockerfile)
- [Dockerfile web](./web/Dockerfile)
- [docker-compose.build.yml](./docker-compose.build.yml)
- [CI/CD pipeline](./.github/workflows/pipeline.yml)
- [README проекта](./README.md)

---

## Быстрая справка

### Сборка worker
```bash
docker compose -f docker-compose.build.yml build langfuse-worker
```

### Сборка web
```bash
docker compose -f docker-compose.build.yml build langfuse-web
```

### Запуск и тестирование
```bash
docker compose -f docker-compose.build.yml up -d
sleep 5
curl -f http://localhost:3030/api/health
curl -f http://localhost:3000/api/public/health
```

### Остановка
```bash
docker compose -f docker-compose.build.yml down
```
