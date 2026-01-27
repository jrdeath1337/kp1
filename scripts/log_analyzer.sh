#!/bin/bash

# Проверяем, передан ли путь к файлу
if [ -z "$1" ]; then
    echo "Использование: $0 /путь/к/файлу.log"
    exit 1
fi

LOG_FILE="$1"

# Проверяем существование файла
if [ ! -f "$LOG_FILE" ]; then
    echo "Ошибка: файл '$LOG_FILE' не найден"
    exit 1
fi

# Читаем файл, убираем пустые строки
LOG_DATA=$(grep -v '^$' "$LOG_FILE")

# Общее количество запросов
TOTAL=$(echo "$LOG_DATA" | wc -l)

# Общее количество 200 ответов
TOTAL_200=$(grep -E ' 200$' "$LOG_FILE" | wc -l)
echo "Total 200 responses: $TOTAL_200"

# Топ 3 IP
TOP_IPS=$(echo "$LOG_DATA" | awk '{print $1}' | sort | uniq -c | sort -rn | head -3)

# Выводим результат
echo "Анализ лог-файла: $LOG_FILE"
echo "=================================="
echo "Общее количество запросов: $TOTAL"
echo ""
echo "Статистика по методам:"
echo "$TOTAL_200"
echo ""
echo "Топ 3 IP адреса:"
echo "$TOP_IPS"
