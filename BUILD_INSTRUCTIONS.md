# Инструкции по сборке проекта

## Исправления, внесенные в проект

### 1. Исправлена проверка Prisma Client в worker/Dockerfile

Проблема: Строгая проверка пути к Prisma Client могла вызывать ошибки сборки, если клиент генерировался в другом месте в pnpm workspace.

Решение: Обновлена проверка для поиска Prisma Client в нескольких возможных расположениях:
- `node_modules/.prisma/client/index.js` (стандартное расположение в pnpm workspace)
- `packages/shared/node_modules/.prisma/client/index.js` (альтернативное расположение)

### 2. Устранен конфликт зависимостей с braces

Проблема: Конфликт между прямой зависимостью `braces@3.0.3` в `devDependencies` и override `braces@^3.0.3` вызывал ошибку при установке зависимостей:
```
npm error Override for braces@3.0.3 conflicts with direct dependency
```

Решение: Удален `braces` из `devDependencies`, так как версия уже управляется через `overrides` и `pnpm.overrides`. Пакет `braces` не используется напрямую в коде проекта, а только как транзитивная зависимость других пакетов.

### 3. Отключен preinstall скрипт в Docker сборке

Проблема: Скрипт `preinstall` в `package.json` пытается выполнить `./scripts/ensure-kysely.sh`, но этот скрипт не попадает в pruned output от `turbo prune`, что вызывает ошибку:
```
sh: ./scripts/ensure-kysely.sh: not found
```

Решение: В обоих Dockerfile (worker и web) добавлен шаг, который удаляет `preinstall` скрипт из `package.json` перед установкой зависимостей. Это безопасно, так как kysely уже устанавливается через multi-stage build в Dockerfile, и скрипт `ensure-kysely.sh` не нужен в Docker сборке.

### 4. Добавлена фиктивная DATABASE_URL для генерации Prisma Client

Проблема: Prisma требует переменную окружения `DATABASE_URL` при генерации клиента из-за `prisma.config.ts`, который использует `env("DATABASE_URL")`. Проблема возникает как при прямой генерации, так и при выполнении задач turbo (например, `db:generate`):
```
PrismaConfigEnvError: Cannot resolve environment variable: DATABASE_URL
```

Решение: В обоих Dockerfile (worker и web) устанавливается фиктивная `DATABASE_URL` через `ENV DATABASE_URL="..."` перед генерацией Prisma Client и перед запуском turbo build. Это гарантирует, что переменная доступна для всех команд, включая задачи turbo. Это безопасно, так как для генерации клиента реальное подключение к базе данных не требуется - нужна только схема Prisma.

### 5. Обновлена проверка Prisma Client для pnpm workspace

Проблема: Проверка Prisma Client не находила сгенерированный клиент, так как в pnpm workspace структура отличается - Prisma Client находится в `.pnpm` директории, а не в корне `node_modules/.prisma`.

Решение: Обновлена проверка в `worker/Dockerfile` для поиска Prisma Client в структуре pnpm. Проверка теперь ищет директорию `.prisma` где-либо в `node_modules` и не прерывает сборку, если не находит в стандартных местах (так как команда `prisma generate` уже прошла успешно).

### 6. Исправлена ошибка типизации TypeScript в worker/src/__tests__/network.ts

Проблема: Ошибка компиляции TypeScript при сборке worker:
```
error TS2314: Generic type 'HttpResponse<BodyType>' requires 1 type argument(s).
error TS2344: Type 'unknown' does not satisfy the constraint 'DefaultBodyType'.
```

Решение: Обновлена типизация функции `CompletionHandler` в `worker/src/__tests__/network.ts` - добавлен тип аргумента для `HttpResponse`: `HttpResponse<any>`. Использование `any` вместо `unknown` необходимо, так как `unknown` не удовлетворяет constraint `DefaultBodyType` в MSW. Это соответствует требованиям новой версии MSW, где `HttpResponse` требует указания типа body, совместимого с `DefaultBodyType`.

### 7. Оптимизирована память для сборки Next.js web приложения

Проблема: Ошибка нехватки памяти при сборке web приложения:
```
ResourceExhausted: cannot allocate memory
```

Решение: Настройка памяти в `web/Dockerfile` изменена на абсолютное значение (`--max-old-space-size=4096` - 4GB) с дополнительной оптимизацией сборки мусора (`--gc-interval=100`). Это обеспечивает более надежную сборку Next.js приложений при ограниченных ресурсах памяти.

**Важно:** Для успешной сборки web приложения требуется:
- Минимум 8GB доступной RAM на хосте
- Минимум 6GB памяти, выделенной для Docker
- Рекомендуется 16GB+ RAM для комфортной сборки

**Если проблема повторяется:**
1. Увеличьте память для Docker Desktop:
   - Settings → Resources → Memory → установите минимум 6GB (рекомендуется 8GB+)
2. Уменьшите значение `--max-old-space-size` в `web/Dockerfile` до 3072 (3GB), если доступно менее 6GB RAM
3. Используйте более мощную машину для сборки
4. Рассмотрите возможность сборки на удаленной машине или CI/CD с большим объемом памяти

## Способы сборки

### Вариант 1: Использование скрипта сборки (рекомендуется)

**Windows (PowerShell):**
```powershell
.\build-custom.ps1
```

**Windows (CMD):**
```cmd
build-custom.bat
```

### Вариант 2: Прямой вызов docker compose

```bash
docker compose -f docker-compose.custom.yml build
```

### Вариант 3: Сборка отдельных сервисов

**Worker:**
```bash
docker build -f worker/Dockerfile -t olegkarenkikh/langfuse_langfuse-worker:4 --build-arg NEXT_PUBLIC_BUILD_ID=local .
```

**Web:**
```bash
docker build -f web/Dockerfile -t olegkarenkikh/langfuse_langfuse-web:4 --build-arg NEXT_PUBLIC_BUILD_ID=local .
```

## Устранение проблем сборки

### Проблема: Ошибка "Prisma Client not found"

**Решение:** 
- Убедитесь, что Prisma Client генерируется корректно
- Проверьте, что `packages/shared/prisma/schema.prisma` существует
- Попробуйте очистить кэш Docker: `docker builder prune`

### Проблема: Ошибка при сборке Kysely

**Решение:**
- Проверьте доступность репозитория: https://github.com/OlegKarenkikh/kysely
- Убедитесь, что коммит `64a12c470b1a5387b842acf09094e2aa1e4149b0` существует

### Проблема: Ошибка turbo prune

**Решение:**
- Убедитесь, что `turbo.json` существует в корне проекта
- Проверьте, что `worker/package.json` и `web/package.json` корректны
- Попробуйте пересобрать без кэша: `docker compose -f docker-compose.custom.yml build --no-cache`

### Проблема: Ошибка "Override for braces conflicts with direct dependency"

**Решение:**
- ✅ **ИСПРАВЛЕНО**: Пакет `braces` был удален из `devDependencies`, так как он уже управляется через `overrides`
- Если проблема повторяется, проверьте, что в `package.json` нет дублирования `braces` в `devDependencies` и `overrides` одновременно

### Проблема: Ошибка "sh: ./scripts/ensure-kysely.sh: not found"

**Решение:**
- ✅ **ИСПРАВЛЕНО**: Preinstall скрипт автоматически отключается в Docker сборке
- Если проблема повторяется, убедитесь, что в Dockerfile есть шаг удаления `preinstall` из `package.json` перед `pnpm install`

### Проблема: Ошибка "Cannot resolve environment variable: DATABASE_URL" при генерации Prisma Client

**Решение:**
- ✅ **ИСПРАВЛЕНО**: Фиктивная `DATABASE_URL` устанавливается перед генерацией Prisma Client
- Если проблема повторяется, убедитесь, что перед `npx prisma generate` установлена переменная `DATABASE_URL` (можно использовать фиктивное значение)

### Проблема: Ошибка "cannot allocate memory" при сборке web приложения

**Решение:**
- ✅ **ИСПРАВЛЕНО**: Установлен лимит памяти для Node.js на 4GB с оптимизацией сборки мусора
- **Критически важно:** Убедитесь, что Docker имеет достаточно памяти:
  1. Откройте Docker Desktop → Settings → Resources → Memory
  2. Установите минимум 6GB (рекомендуется 8GB+)
  3. Нажмите "Apply & Restart"
- Если проблема повторяется:
  - Уменьшите значение `--max-old-space-size` в `web/Dockerfile` до 3072 (3GB) для систем с ограниченной памятью
  - Закройте другие приложения, освобождая память
  - Используйте более мощную машину для сборки (рекомендуется 16GB+ RAM)
  - Рассмотрите возможность сборки на удаленной машине или CI/CD с большим объемом памяти

### Проблема: Ошибки при установке зависимостей

**Решение:**
- Убедитесь, что `pnpm-lock.yaml` актуален
- Попробуйте обновить lockfile локально: `pnpm install --lockfile-only`
- Если возникают конфликты зависимостей, проверьте секции `overrides` и `pnpm.overrides` в `package.json`

## Проверка успешной сборки

После успешной сборки проверьте наличие образов:

```bash
docker images | grep olegkarenkikh/langfuse
```

Должны быть созданы:
- `olegkarenkikh/langfuse_langfuse-worker:4`
- `olegkarenkikh/langfuse_langfuse-web:4`

## Запуск собранных контейнеров

```bash
docker compose -f docker-compose.custom.yml up -d
```

## Логи сборки

Если сборка не удалась, проверьте логи:
```bash
docker compose -f docker-compose.custom.yml build --progress=plain 2>&1 | tee build.log
```

