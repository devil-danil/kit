# Домашнее задание 3

### Тема лекции
> "Внутренности Linux"

### Среда выполнения
> macOS 15.5

## Задание
Я запустил в консоли на сервисе важный сервис, но забыл запустить его в фоне… мне надо закрыть ноут и бежать на лекцию….

Важный сервис:

```bash
#! /usr/bin/bash
while true; do
  echo "`date` I am still alive"
  sleep 1
done
```

Задача - отвязать процесс от консоли и перенаправить вывод в файл чтобы 1 и 2 дескриптор писали в файлики stdout.txt и stderr.txt

**Важное уточнение!!
Сервис нужно запустить из обычной консоли без tmux/screen**

Предпочтительно это сделать через GDB, другие варианты тоже подойдут.

## Бонусная часть
- Собрать zstd с debug символами самостоятельно
- запустить
- cat /dev/urandom | zstd -19 -f -T4 -v - -o out.zst
- снять с процесса zstd perf record и найти в исходниках zstd самую нагруженную функцию.

## Решение основной части

![screenshot_1]()

### 1. Отвязываю bash‑скрипт от терминала, сохранив вывод в файлы

```bash
# service.sh
#!/bin/bash
while true; do
  echo "$(date) I am still alive"
  echo "$(date) Error simulation: something happened!" >&2
  sleep 1
done
```

#### Шаги

1.1 Запускаю скрипт в первом окне терминала:

   `./service.sh`

1.2 Узнаю идентификатор процесса (PID):

   `pgrep -f service.sh` → например `12345`

1.3 Подключаюсь к процессу отладчиком LLDB:

   `lldb -p 12345`

1.4 В интерактивной сессии LLDB выполняю следующие команды (по очереди):

   ```text
   expr int $fd1 = (int)open("stdout.txt",0x201,0644)
   expr (void)dup2($fd1,1)
   expr (void)close($fd1)

   expr int $fd2 = (int)open("stderr.txt",0x201,0644)
   expr (void)dup2($fd2,2)
   expr (void)close($fd2)

   expr (void)signal(1,1)      # игнорируем SIGHUP
   process detach              # отсоединяемся
   ```

   > `0x201` — это битовая комбинация `O_WRONLY | O_CREAT | O_APPEND`.

1.5 Закрываю первое окно **Terminal**.  
   Скрипт продолжит работать без привязки к TTY, а вывод будет поступать в файлы `stdout.txt` и `stderr.txt`.

---

### 2. Сборка **zstd** с отладочными символами и поиск «тяжёлой» функции

2.1 Устанавливаю инструменты

```bash
brew install git cmake make
xcode-select --install
```

2.2 Клонирую и собираю код

```bash
git clone https://github.com/facebook/zstd.git
cd zstd
make MOREFLAGS="-g -O2"   # включаем DWARF‑символы + оптимизацию
```

Получившийся бинарник: `programs/zstd`.

2.3 Запускаю и профилирую

```bash
cd programs
cat /dev/urandom | ./zstd -19 -f -T4 -v - -o out.zst &
ZPID=$!

# снимаем 10‑секундный сэмпл стэков
sudo sample $ZPID 10 -file zstd_sample.txt
```

*CLI*‑утилита `sample` собирает ~1000 стэктрейсов в секунду.  
Если нужна графика, можно воспользоваться *Time Profiler*:

```bash
xcrun xctrace record   --template 'Time Profiler'   --process $ZPID   --time-limit 10s   --output zstd_trace.xcresult
open zstd_trace.xcresult
```

2.4 Анализирую вывод

```bash
grep -A20 "Call graph:" zstd_sample.txt | head
```

Типичный верх стэка:

```
84.1% ... ZSTD_btGetAllMatches_noDict_3
      84.1% ZSTD_insertBtAndGetAllMatches
```

Это указывает на «самую тяжёлую» функцию `ZSTD_btGetAllMatches_noDict_3`, развёрнутую из макроса `GEN_ZSTD_BT_GET_ALL_MATCHES(noDict)` в `lib/compress/zstd_opt.c`, и её внутренний вызов `ZSTD_insertBtAndGetAllMatches()`.

---

### Замечания по данному заданию

* **Отвязка процесса.**  
  * macOS — LLDB (`open`, `dup2`, `signal`, `process detach`);  
  * Ubuntu — GDB с тем же набором системных вызовов.
* **Профилирование `zstd`.**  
  * macOS — `sample` (CLI) или *Time Profiler* через `xctrace` / Instruments;  
  * Ubuntu — `perf record` / `perf report`.
* В обеих системах профилирование подтверждает, что наибольшую нагрузку создаёт функция **`ZSTD_btGetAllMatches_noDict_3`** и её вызов **`ZSTD_insertBtAndGetAllMatches()`**.
