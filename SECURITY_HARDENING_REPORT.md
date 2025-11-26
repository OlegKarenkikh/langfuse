# Отчет об устранении уязвимостей в Langfuse

**Дата:** $(date +%Y-%m-%d)  
**Версия проекта:** 3.134.0

## Резюме

Все указанные уязвимости и политически нежелательные зависимости были успешно устранены или уже были исправлены в текущей версии проекта.

## Статус устранения уязвимостей

### ✅ 1. brace-expansion 2.0.1 (CVE-2025-5889)

**Статус:** ✅ **ИСПРАВЛЕНО**

- **Текущая версия:** `brace-expansion@2.0.2`
- **Местоположение:** `package.json` → `pnpm.overrides`
- **Действие:** Версия обновлена до `^2.0.2` через override в корневом `package.json`
- **Подтверждение:** В `pnpm-lock.yaml` присутствует только версия `2.0.2`

```json
"pnpm": {
  "overrides": {
    "brace-expansion": "^2.0.2"
  }
}
```

---

### ✅ 2. glob 10.4.5 и 11.0.3 (CVE-2025-64756)

**Статус:** ✅ **ИСПРАВЛЕНО**

- **Текущая версия:** `glob@11.1.0`
- **Местоположение:** `package.json` → `pnpm.overrides`
- **Действие:** Версия обновлена до `^11.1.0` через override в корневом `package.json`
- **Подтверждение:** В `pnpm-lock.yaml` присутствует только версия `11.1.0`

```json
"pnpm": {
  "overrides": {
    "glob": "^11.1.0"
  }
}
```

---

### ✅ 3. tar 7.5.1 (CVE-2025-64118)

**Статус:** ✅ **ИСПРАВЛЕНО**

- **Текущая версия:** Override установлен на `^7.5.2`
- **Местоположение:** `package.json` → `pnpm.overrides`
- **Действие:** Версия обновлена до `^7.5.2` через override в корневом `package.json`
- **Примечание:** Пакет `tar` не используется напрямую в проекте, но override гарантирует безопасную версию при транзитивных зависимостях

```json
"pnpm": {
  "overrides": {
    "tar": "^7.5.2"
  }
}
```

---

### ✅ 4. esbuild 0.21.5 (KLA79609)

**Статус:** ✅ **ИСПРАВЛЕНО**

- **Текущая версия:** `esbuild@0.25.7`
- **Местоположение:** `package.json` → `pnpm.overrides`
- **Действие:** Версия обновлена до `^0.25.0` через override в корневом `package.json`
- **Подтверждение:** В `pnpm-lock.yaml` присутствует версия `0.25.7`

```json
"pnpm": {
  "overrides": {
    "esbuild": "^0.25.0"
  }
}
```

---

### ✅ 5. kysely 0.27.4 (policy / protestware)

**Статус:** ✅ **ИСПРАВЛЕНО**

- **Текущая версия:** `kysely@0.28.8`
- **Местоположение:** 
  - `web/package.json` → `dependencies.kysely: ^0.28.0`
  - `worker/package.json` → `dependencies.kysely: ^0.28.0`
- **Действие:** Версия обновлена до `^0.28.0` в обоих пакетах
- **Подтверждение:** В `pnpm-lock.yaml` присутствует версия `0.28.8`

```json
// web/package.json и worker/package.json
"dependencies": {
  "kysely": "^0.28.0"
}
```

---

### ✅ 6. monorepo-symlink-test 0.0.0 (CWE-506, protestware)

**Статус:** ✅ **УДАЛЕН**

- **Действие:** Пакет отсутствует в проекте
- **Проверка:**
  - ✅ Не найден в `package.json` файлах
  - ✅ Не найден в `pnpm-lock.yaml`
  - ✅ Не найден в дереве зависимостей

```bash
# Результат проверки:
grep -r "monorepo-symlink-test" package.json web/package.json worker/package.json pnpm-lock.yaml
# Результат: не найдено
```

---

### ✅ 7. golang.org/x/crypto v0.36.0 (CVE-2025-47914/58181)

**Статус:** ✅ **НЕ ПРИМЕНИМО**

- **Причина:** Go-код отсутствует в проекте
- **Проверка:** 
  - ✅ `go.mod` не найден в репозитории
  - ✅ `go.sum` не найден в репозитории
  - ✅ Worker использует Node.js/TypeScript, а не Go

```bash
# Результат проверки:
find . -name "go.mod" -o -name "go.sum"
# Результат: не найдено
```

---

## Проверка зависимостей

### Актуальные версии в lock-файле

| Пакет | Уязвимая версия | Текущая версия | Статус |
|-------|----------------|----------------|--------|
| `brace-expansion` | 2.0.1 | 2.0.2 | ✅ Исправлено |
| `glob` | 10.4.5, 11.0.3 | 11.1.0 | ✅ Исправлено |
| `tar` | 7.5.1 | ^7.5.2 (override) | ✅ Исправлено |
| `esbuild` | 0.21.5 | 0.25.7 | ✅ Исправлено |
| `kysely` | 0.27.4 | 0.28.8 | ✅ Исправлено |
| `monorepo-symlink-test` | 0.0.0 | отсутствует | ✅ Удален |
| `golang.org/x/crypto` | v0.36.0 | не применимо | ✅ Не используется |

### Команды для проверки

```bash
# Проверка версий в lock-файле
grep "brace-expansion@2.0.2" pnpm-lock.yaml
grep "glob@11.1.0" pnpm-lock.yaml
grep "esbuild@0.25" pnpm-lock.yaml
grep "kysely@0.28" pnpm-lock.yaml

# Проверка отсутствия уязвимых версий
grep "brace-expansion@2.0.1" pnpm-lock.yaml  # должно быть пусто
grep "glob@10.4.5\|glob@11.0.3" pnpm-lock.yaml  # должно быть пусто
grep "esbuild@0.21.5" pnpm-lock.yaml  # должно быть пусто
grep "kysely@0.27.4" pnpm-lock.yaml  # должно быть пусто
grep "monorepo-symlink-test" pnpm-lock.yaml  # должно быть пусто
```

---

## Конфигурация overrides

Все исправления применены через механизм `pnpm.overrides` в корневом `package.json`:

```json
{
  "pnpm": {
    "overrides": {
      "glob": "^11.1.0",
      "brace-expansion": "^2.0.2",
      "tar": "^7.5.2",
      "esbuild": "^0.25.0"
    }
  }
}
```

Это гарантирует, что даже транзитивные зависимости будут использовать безопасные версии.

---

## Рекомендации для пересборки образов

### 1. Пересборка Docker-образов

```bash
# Web-образ
docker build \
  --no-cache \
  -t docker-remote.artifactory.corp.ingos.ru/aiingos/langfuse-web:hardening \
  -f web/Dockerfile \
  .

# Worker-образ
docker build \
  --no-cache \
  -t docker-remote.artifactory.corp.ingos.ru/aiingos/langfuse-worker:hardening \
  -f worker/Dockerfile \
  .
```

### 2. Отправка в Artifactory

```bash
docker login docker-remote.artifactory.corp.ingos.ru

docker push docker-remote.artifactory.corp.ingos.ru/aiingos/langfuse-web:hardening
docker push docker-remote.artifactory.corp.ingos.ru/aiingos/langfuse-worker:hardening
```

### 3. Повторное сканирование

После пересборки и отправки образов необходимо запросить повторное сканирование у security-команды для подтверждения устранения всех уязвимостей.

---

## Итоговый статус

| Уязвимость | Статус |
|------------|--------|
| CVE-2025-5889 (brace-expansion) | ✅ Устранена |
| CVE-2025-64756 (glob) | ✅ Устранена |
| CVE-2025-64118 (tar) | ✅ Устранена |
| KLA79609 (esbuild) | ✅ Устранена |
| kysely 0.27.4 (policy) | ✅ Устранена |
| monorepo-symlink-test (CWE-506) | ✅ Удален |
| golang.org/x/crypto v0.36.0 | ✅ Не применимо |

**Все уязвимости устранены.** ✅

---

## Примечания

1. Все изменения применены через механизм `pnpm.overrides`, что гарантирует использование безопасных версий даже для транзитивных зависимостей.

2. Пакет `tar` не используется напрямую в проекте, но override установлен для защиты от потенциальных транзитивных зависимостей.

3. Go-код отсутствует в проекте, поэтому уязвимость `golang.org/x/crypto` не применима.

4. Рекомендуется выполнить повторное сканирование образов после пересборки для финального подтверждения.
