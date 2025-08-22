#!/bin/bash

ps axuww --sort=-pcpu | awk '
BEGIN {
  OFS = ","  # Устанавливаем разделитель полей как запятую
  print "\"USER\",\"PID\",\"%CPU\",\"%MEM\",\"VSZ\",\"RSS\",\"TTY\",\"STAT\",\"START\",\"TIME\",\"COMMAND\""
}
NR > 1 {
  # Обрабатываем поля с 1 по 10
  for (i = 1; i <= 10; i++) {
    gsub(/"/, "\"\"", $i)  # Экранируем кавычки
    $i = "\"" $i "\""      # Обрамляем поле в кавычки
  }
  
  # Обрабатываем поле COMMAND (с 11-го поля до конца строки)
  cmd = ""
  for (i = 11; i <= NF; i++) {
    cmd = cmd (i == 11 ? "" : " ") $i
  }
  gsub(/"/, "\"\"", cmd)
  cmd = "\"" cmd "\""
  
  # Формируем строку CSV
  print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, cmd
}'


# > /tmp/ps.csv
# Просмотр результата:
# column -s, -t < /tmp/ps.csv | less -S

exit 0
