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

# Конфигурация PostgreSQL
DB_NAME="log_analysis"
DB_USER="postgres"  # Используем стандартного пользователя postgres
DB_HOST="localhost"
DB_PORT="5432"
TABLE_NAME="log_stats"

# Используем .pgpass для аутентификации
export PGPASSFILE="/home/jrdeath/.pgpass"

# Функция для выполнения SQL запроса
execute_sql() {
    local sql="$1"
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "$sql" -t
}

# Создаем таблицу если она не существует
#CREATE_TABLE_SQL="
#CREATE TABLE IF NOT EXISTS $TABLE_NAME (
#    id SERIAL PRIMARY KEY,
#    ip VARCHAR(45) NOT NULL,
#    requests_count INTEGER NOT NULL,
#    created_at DATE DEFAULT CURRENT_DATE,
#    log_date DATE NOT NULL DEFAULT CURRENT_DATE,
#    UNIQUE(ip, log_date)
#);
#"

# Проверяем подключение к БД
if ! execute_sql "SELECT 1;" > /dev/null 2>&1; then
    echo "Ошибка: не удалось подключиться к базе данных"
    echo "Проверьте настройки PostgreSQL и файл ~/.pgpass"
    exit 1
fi

execute_sql "$CREATE_TABLE_SQL"

# Получаем текущую дату
CURRENT_DATE=$(date +"%Y-%m-%d")

# Анализируем лог-файл
echo "[$(date)] Анализ лог-файла: $LOG_FILE"
echo "=================================="

# Используем временный файл для данных
TEMP_FILE=$(mktemp)

# Подсчитываем количество запросов для каждого IP
awk '{print $1}' "$LOG_FILE" | sort | uniq -c > "$TEMP_FILE"

# Обрабатываем каждый IP
while read -r count ip; do
    if [ -n "$ip" ]; then
        # Используем INSERT ... ON CONFLICT для обновления или вставки
        INSERT_SQL="INSERT INTO $TABLE_NAME (ip, requests_count, log_date) 
                    VALUES ('$ip', $count, '$CURRENT_DATE')
                    ON CONFLICT (ip, log_date) 
                    DO UPDATE SET requests_count = EXCLUDED.requests_count;"
        
        if execute_sql "$INSERT_SQL" > /dev/null 2>&1; then
            echo "Обработан IP: $ip (запросов: $count)"
        else
            echo "Ошибка при обработке IP: $ip"
        fi
    fi
done < "$TEMP_FILE"

# Удаляем временный файл
rm -f "$TEMP_FILE"

# Выводим статистику
echo "=================================="
echo "Статистика за $CURRENT_DATE:"

STATS_SQL="
SELECT 
    COUNT(DISTINCT ip) as unique_ips,
    SUM(requests_count) as total_requests,
    AVG(requests_count) as avg_per_ip
FROM $TABLE_NAME 
WHERE log_date = '$CURRENT_DATE';
"

execute_sql "$STATS_SQL"

echo ""
echo "Топ 5 IP за сегодня:"
TOP_IPS_SQL="
SELECT ip, requests_count 
FROM $TABLE_NAME 
WHERE log_date = '$CURRENT_DATE'
ORDER BY requests_count DESC 
LIMIT 5;
"

execute_sql "$TOP_IPS_SQL"

echo ""
echo "[$(date)] Анализ завершен"
