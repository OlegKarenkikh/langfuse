#!/bin/bash

echo "=========================================="
echo "СТАТУС СБОРКИ ОБРАЗОВ"
echo "Время: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""

# Проверка сборки WEB
echo "📦 ОБРАЗ WEB: olegkarenkikh/langfuse_langfuse-web:4"
echo "----------------------------------------"
if [ -f /tmp/build-web-full.log ]; then
    WEB_STEP=$(strings /tmp/build-web-full.log 2>/dev/null | grep -o "Step [0-9]*/92" | tail -1 || tail -20 /tmp/build-web-full.log | grep -o "Step [0-9]*/92" | tail -1)
    echo "Текущий шаг: ${WEB_STEP:-определяется...}"
    echo "Последние строки:"
    tail -3 /tmp/build-web-full.log 2>/dev/null | strings 2>/dev/null | sed 's/^/  /' || tail -3 /tmp/build-web-full.log | sed 's/^/  /'
    WEB_SUCCESS=$(tail -50 /tmp/build-web-full.log 2>/dev/null | strings 2>/dev/null | grep -i "successfully built" | tail -1)
    WEB_ERROR=$(tail -50 /tmp/build-web-full.log 2>/dev/null | strings 2>/dev/null | grep -iE "(error|failed)" | tail -1)
    if [ -n "$WEB_SUCCESS" ]; then
        echo "  ✅ $WEB_SUCCESS"
    elif [ -n "$WEB_ERROR" ]; then
        echo "  ❌ Ошибка: $WEB_ERROR"
    fi
    echo ""
else
    echo "Лог файл не найден"
    echo ""
fi

# Проверка сборки WORKER
echo "📦 ОБРАЗ WORKER: olegkarenkikh/langfuse_langfuse-worker:4"
echo "----------------------------------------"
if [ -f /tmp/build-worker-full.log ]; then
    WORKER_STEP=$(grep -o "Step [0-9]*/[0-9]*" /tmp/build-worker-full.log | tail -1)
    WORKER_STATUS=$(tail -3 /tmp/build-worker-full.log | grep -E "(Successfully|ERROR|error|failed)" || echo "В процессе...")
    echo "Текущий шаг: $WORKER_STEP"
    echo "Последние строки:"
    tail -3 /tmp/build-worker-full.log | sed 's/^/  /'
    echo ""
else
    echo "Лог файл не найден"
    echo ""
fi

# Проверка процессов
echo "🔍 АКТИВНЫЕ ПРОЦЕССЫ СБОРКИ"
echo "----------------------------------------"
ps aux | grep "[d]ocker build" | wc -l | xargs echo "Количество процессов:"
echo ""

# Проверка собранных образов
echo "🖼️  СОБРАННЫЕ ОБРАЗЫ"
echo "----------------------------------------"
sudo docker images | grep -E "(langfuse|REPOSITORY)" || echo "Образы еще не собраны"
echo ""

echo "=========================================="
