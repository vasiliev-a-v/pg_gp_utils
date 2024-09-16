README

Утилиты:
csv_upload.sh
csv_to_adb.sh
customer_scripts.sh

SQL-скрипты:
check_data_skew_to_csv.sql
template_common.sql
template_pg_class.sql
template_pg_locks.sql
template_check_data_skew.sql


csv_upload.sh - данная утилита загружает файл в формате csv.gz, либо csv на сервер ADB через scp.
Также в csv_upload.sh можно задать атрибут на запуск утилиты csv_to_adb.sh

csv_to_adb.sh - данная утилита проводит такие действия:
  - создаёт базу данных,
  - создаёт таблицу,
  - копирует в таблицу данные из файла csv, csv.gz
  - вакуумирует и анализирует таблицу.

customer_scripts.sh - в этом файле собран набор команд для заказчика на получение данных из соответствующих системных таблиц.



check_data_skew_to_csv.sql - скрипт для получения таблицы перекосов данных.
Шаблон для заказчика описан в файле customer_scripts.sh.
Шаблон для csv_to_adb.sh - это файл template_check_data_skew.sql
Анализ перекосов описан в Knowledge Base:
https://arenadata.simpleone.ru/portal/record?table_name=article&record_id=168241524991310332


