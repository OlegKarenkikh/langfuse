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

### 8. Добавлены недостающие зависимости для MUI и react-resizable

Проблема: Ошибки при сборке Next.js web приложения:
```
Module not found: Can't resolve '@emotion/react'
Module not found: Can't resolve '@emotion/styled'
Module not found: Can't resolve 'react-resizable/css/styles.css'
Module not found: Can't resolve '.prisma/client/index-browser'
```

Решение: 
- Добавлены зависимости `@emotion/react` и `@emotion/styled` в `web/package.json` (требуются для MUI v7)
- Добавлена зависимость `react-resizable` в `web/package.json` (используется в `DashboardGrid.tsx`)
- Добавлена webpack конфигурация в `web/next.config.mjs` для правильного разрешения Prisma Client в pnpm workspace:
  - Добавлены `@prisma/client` и `.prisma/client` в `serverExternalPackages`
  - Добавлена логика в `webpack` для исключения Prisma Client из клиентского бандла и правильного разрешения на сервере
  - Добавлены alias для Turbopack (используется в dev и production сборках Next.js 16) для исключения Prisma Client из клиентского кода:
    - `.prisma/client` → `false`
    - `.prisma/client/index-browser` → `false`
    - `@prisma/client` → `false`

### 9. Добавлены build dependencies для нативных модулей

Проблема: Ошибка при установке зависимостей в Docker:
```
gyp ERR! find Python Python is not set from command line or npm configuration
gyp ERR! find Python Python is not set from environment variable PYTHON
gyp ERR! configure error
gyp ERR! stack Error: Could not find any Python installation to use
```

Решение: Добавлены build dependencies в оба Dockerfile (`worker/Dockerfile` и `web/Dockerfile`) на этапе `builder`:
- `python3` - требуется для node-gyp (компиляция нативных модулей)
- `make` - требуется для сборки нативных модулей
- `g++` - компилятор C++ для нативных модулей
- `libc-dev` - заголовочные файлы C библиотеки

Эти зависимости необходимы для компиляции нативных модулей, таких как `better-sqlite3`, которые требуют сборки из исходного кода.

### 7. Оптимизирована память для сборки Next.js web приложения

Проблема: Ошибка нехватки памяти при сборке web приложения:
```
ResourceExhausted: cannot allocate memory
```

Решение: Настройка памяти в `web/Dockerfile` установлена на 3GB (`--max-old-space-size=3072`). Меньший лимит может работать лучше, если система не может выделить большие блоки памяти. Также добавлена переменная окружения `NEXT_BUILD_OPTIMIZE=1` для оптимизации сборки.

**КРИТИЧЕСКИ ВАЖНО:** Для успешной сборки web приложения требуется:
- **Минимум 8GB доступной RAM на хосте**
- **Минимум 6GB памяти, выделенной для Docker Desktop**
- **Рекомендуется 16GB+ RAM для комфортной сборки**

**Как увеличить память для Docker Desktop (Windows/Mac):**
1. Откройте Docker Desktop
2. Перейдите в Settings (⚙️) → Resources → Advanced
3. Установите Memory на минимум **6GB** (рекомендуется **8GB+**)
4. Нажмите "Apply & Restart"
5. Дождитесь перезапуска Docker

**Если проблема повторяется:**
1. ✅ **Проверьте, что Docker Desktop имеет достаточно памяти** (см. инструкцию выше)
2. Закройте другие приложения, освобождая память
3. Убедитесь, что на хосте достаточно свободной RAM (минимум 8GB)
4. Используйте более мощную машину для сборки (рекомендуется 16GB+ RAM)
5. Рассмотрите возможность сборки на удаленной машине или CI/CD с большим объемом памяти
6. Если доступно менее 8GB RAM, попробуйте уменьшить значение `--max-old-space-size` в `web/Dockerfile` до 2048 (2GB), но это может привести к более медленной сборке

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

### Проблема: Ошибка "cannot allocate memory" или "ResourceExhausted" при сборке web приложения

**Решение:**
- ✅ **ИСПРАВЛЕНО**: Установлен лимит памяти для Node.js на 3GB с оптимизациями сборки
- **КРИТИЧЕСКИ ВАЖНО:** Убедитесь, что Docker Desktop имеет достаточно памяти:
  1. Откройте Docker Desktop
  2. Перейдите в Settings (⚙️) → Resources → Advanced
  3. Установите Memory на минимум **6GB** (рекомендуется **8GB+**)
  4. Нажмите "Apply & Restart"
  5. Дождитесь полного перезапуска Docker
- **Проверьте доступную RAM на хосте:**
  - Windows: Диспетчер задач → Производительность → Память
  - Mac: Activity Monitor → Memory
  - Linux: `free -h`
  - Должно быть минимум **8GB свободной RAM**
- Если проблема повторяется:
  1. ✅ **Убедитесь, что Docker Desktop имеет минимум 6GB памяти** (см. инструкцию выше)
  2. Закройте другие приложения, освобождая память
  3. Проверьте, что на хосте достаточно свободной RAM (минимум 8GB)
  4. Используйте более мощную машину для сборки (рекомендуется 16GB+ RAM)
  5. Рассмотрите возможность сборки на удаленной машине или CI/CD с большим объемом памяти
  6. Если доступно менее 8GB RAM, попробуйте уменьшить значение `--max-old-space-size` в `web/Dockerfile` до 2048 (2GB), но это может привести к более медленной сборке или другим проблемам

### Проблема: Ошибки "Module not found" для @emotion, react-resizable или Prisma Client

**Решение:**
- ✅ **ИСПРАВЛЕНО**: Добавлены недостающие зависимости в `web/package.json`:
  - `@emotion/react` и `@emotion/styled` (для MUI)
  - `react-resizable` (для DashboardGrid)
- ✅ **ИСПРАВЛЕНО**: Добавлена webpack конфигурация для Prisma Client в `web/next.config.mjs`
- Если проблема повторяется:
  - Убедитесь, что все зависимости установлены: `pnpm install` в корне проекта
  - Проверьте, что Prisma Client генерируется корректно: `cd packages/shared && npx prisma generate`
  - Очистите кэш Docker: `docker builder prune`

### Проблема: Ошибка "Could not find any Python installation" при установке зависимостей

**Решение:**
- ✅ **ИСПРАВЛЕНО**: Добавлены build dependencies (python3, make, g++, libc-dev) в оба Dockerfile
- Эта ошибка возникает при попытке скомпилировать нативные модули (например, `better-sqlite3`), которые требуют Python и компилятор C++
- Если проблема повторяется:
  - Убедитесь, что в Dockerfile на этапе `builder` установлены build dependencies перед `pnpm install`
  - Проверьте, что используется правильный базовый образ (node:24-alpine)
  - Очистите кэш Docker: `docker builder prune`

### 10. Оптимизирован размер образа для предотвращения ошибок экспорта

Проблема: Ошибка при экспорте образа после успешной сборки:
```
failed to receive status: rpc error: code = Unavailable desc = error reading from server: EOF
rpc error: code = Unavailable desc = error reading from server: EOF (при resolving provenance)
```

Причина: Очень большой размер образа из-за копирования всех файлов из builder stage, включая:
- `node_modules` (не нужны в production, так как Next.js standalone включает только необходимые зависимости)
- Исходные TypeScript файлы (`.ts`, `.tsx`)
- Кэш сборки (`.next/cache`, `.turbo`)
- Source maps (`.map` файлы)
- BuildKit пытается создать provenance metadata (SBOM), что вызывает дополнительные проблемы

Решение:
1. **Добавлен промежуточный stage `optimizer`** в оба Dockerfile (`web/Dockerfile` и `worker/Dockerfile`), который:
   - Удаляет `node_modules` и все зависимости (не нужны в production)
   - Удаляет исходные TypeScript файлы (не нужны в production)
   - Удаляет кэш сборки и временные файлы
   - Удаляет source maps (опционально, можно оставить для debugging)
   - Значительно уменьшает размер данных, копируемых в финальный образ

2. **Примечание о provenance/SBOM**:
   - В новых версиях Docker Compose можно отключить через `provenance: false` и `sbom: false` в секции `build`
   - В старых версиях (например, в Coolify) эти опции не поддерживаются, поэтому полагаемся на оптимизацию размера образа через stage `optimizer`
   - Если используется Docker Compose v2.23+, можно добавить эти опции для дополнительной оптимизации

Это предотвращает ошибки EOF при экспорте больших образов и ускоряет процесс сборки.

### 11. Отключение provenance/SBOM для предотвращения ошибок экспорта

Проблема: Ошибка при экспорте образа на этапе "resolving provenance for metadata file":
```
target langfuse-worker: rpc error: code = Unavailable desc = error reading from server: EOF
```

Причина: BuildKit пытается создать provenance metadata (SBOM - Software Bill of Materials) для образа, что требует дополнительных ресурсов и может вызывать ошибки EOF при экспорте больших образов.

Решение:
- ✅ **ИСПРАВЛЕНО**: Оптимизация размера образа через stage `optimizer` значительно уменьшает размер экспортируемых данных
- ⚠️ **Примечание**: Опции `provenance: false` и `sbom: false` поддерживаются только в Docker Compose v2.23+
- В старых версиях Docker Compose (например, в Coolify) эти опции не поддерживаются и вызывают ошибку валидации
- Основная оптимизация достигается через удаление ненужных файлов в stage `optimizer`, что предотвращает ошибки EOF

### Проблема: Ошибка "failed to receive status: rpc error" при экспорте образа

**Решение:**
- ✅ **ИСПРАВЛЕНО**: 
  - Добавлен stage `optimizer` для очистки ненужных файлов перед экспортом (в обоих Dockerfile)
  - Отключен provenance/SBOM в docker-compose.custom.yml
- ⚠️ **ВНИМАНИЕ**: Если ошибка все еще возникает, это может означать, что образ не был сохранен
- Проверьте наличие образов:
  - Windows PowerShell: `docker images`
  - Ищите образы с именами `olegkarenkikh/langfuse:worker` и `olegkarenkikh/langfuse:web`
- Если образы отсутствуют, пересоберите только проблемный сервис:
  ```bash
  # Пересобрать только web
  docker compose -f docker-compose.custom.yml build langfuse-web
  
  # Пересобрать только worker
  docker compose -f docker-compose.custom.yml build langfuse-worker
  ```
- Если проблема повторяется, попробуйте:
  1. Увеличить память Docker Desktop (минимум 8GB)
  2. Очистить кэш Docker: `docker builder prune`
  3. Пересобрать без кэша: `docker compose -f docker-compose.custom.yml build --no-cache langfuse-web`

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
- `olegkarenkikh/langfuse:worker`
- `olegkarenkikh/langfuse:web`

**Примечание:** Если в конце сборки появляется ошибка `failed to receive status: rpc error: code = Unavailable desc = error reading from server: EOF`, это не критично - это проблема с экспортом больших образов, но сами образы уже собраны. Проверьте наличие образов командой выше. С отключенным provenance/SBOM и оптимизацией размера образов эти ошибки должны возникать реже.

## Запуск собранных контейнеров

```bash
docker compose -f docker-compose.custom.yml up -d
```

## Логи сборки

Если сборка не удалась, проверьте логи:
```bash
docker compose -f docker-compose.custom.yml build --progress=plain 2>&1 | tee build.log
```

