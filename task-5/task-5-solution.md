# Домашнее задание 5

### Тема лекции
> "Как починить интернет"

### Среда выполнения
> 2 ВМ на Debian 12

### Решение

> Дополнение: для исследования используйте передачу файла размером 10Mb.

#### Подготовка

**Latency (задержка)** и **packet loss (потеря пакетов)** - это два важных показателя сетевого соединения, влияющих на качество связи между клиентом и сервером. Задержка измеряет время, необходимое пакету данных для прохождения от источника к пункту назначения и обратно, в то время как потеря пакетов - это процент пакетов, которые не дошли до адресата.

Пробую на vm0 проверить, включены ли в ядре модуль эмуляции сети и TCP BBR.

![screenshot_1](https://github.com/devil-danil/kit/blob/main/task-5/screenshots/screenshot_1.png)

Debian по умолчанию не кладёт сжатый конфиг в /proc. Вместо него всегда есть файл в /boot.

![screenshot_2](https://github.com/devil-danil/kit/blob/main/task-5/screenshots/screenshot_2.png)

Проверяю, активность модулей и подгружаю их вручную.

![screenshot_3](https://github.com/devil-danil/kit/blob/main/task-5/screenshots/screenshot_3.png)

> На vm1 делаю то же самое

Для передачи статического файла с vm1 на vm0, устанвлю на vm1 nginx.

`sudo apt install nginx`

`sudo systemctl start nginx`

Проверяю статус сервера.

![screenshot_4](https://github.com/devil-danil/kit/blob/main/task-5/screenshots/screenshot_4.png)

По-умолчанию используется протокол HTTP 1.1 и прослушивается порт 80.

Сгенерируем файл с размером 10 Мб, заполенный случайными данными.

`head -c 10M /dev/urandom > file_10m`

Скопирую созданный файл в корень сервера nginx.

`cp /home/debian/dz5/file_10m /var/www/html/`

На vm0 проверяю, доступен ли файл file_10m.

![screenshot_5](https://github.com/devil-danil/kit/blob/main/task-5/screenshots/screenshot_5.png)

Проверяю на vm1 текущий профиль «каналов»:

`tc qdisc show dev enp0s1`

```bash
qdisc fq_codel 0: root refcnt 2 limit 10240p flows 1024 quantum 1514 target 5ms interval 100ms memory_limit 32Mb ecn drop_batch 64
```

> Текущий профиль - без задержек (до настройки tc qdisc)

TCP CC ― алгоритм, который управляет скоростью отправки пакетов, стараясь не «забить» сеть и при этом использовать её полосу максимально эффективно.

Применим данные алгоритмы на обеих машинах (vm0 — клиент, vm1 — сервер).

Проверим текущий алгоритм на сервере:

`sysctl net.ipv4.tcp_available_congestion_control`

> net.ipv4.tcp_available_congestion_control = reno cubic bbr

Комбинации TCP CC:

| Клиент (vm0) | Сервер (vm1) |
| ------------ | ------------ |
| Reno         | Reno         |
| Reno         | BBR          |
| BBR          | Reno         |
| BBR          | BBR          |

# на vm1
sudo sysctl -w net.ipv4.tcp_congestion_control=reno   # или bbr
sudo tc qdisc change dev enp0s1 root netem delay 50ms loss 2%

# на vm0
sudo sysctl -w net.ipv4.tcp_congestion_control=bbr    # или reno
sudo tcpdump -i enp0s1 -s0 -w vm0_bbr-vm1_reno_50_2.pcap &
PID=$!
curl -o /dev/null http://192.168.64.3/file_10m
sudo kill -INT $PID

Устанавливаю на vm0 и vm1 ethtool для проверки "улучшайзеров" на интерфейсе:

`apt install ethtool`

Проверяю командой:

`ethtool -k enp0s1`

> GRO (generic-receive-offload) = on, нужно отключить, т.к. ядро склеивает входящие сегменты.

На двух ВМ вывод одинаковый, так что отключаю следующий параметр на обеих командой:

`ethtool -K enp0s1 tso off gso off gro off lro off`

---

reno - reno 0

sudo tcpdump -i enp0s1 -s0 -w vm0_reno-vm1_reno_0.pcap &
PID=$!
curl -o /dev/null http://192.168.64.2/file_10m
sudo kill -INT $PID

---
Применим следующий фильтр в Wireshark

>ip.addr == 192.168.64.2 && ip.addr == 192.168.64.3

График I/O без настроек.

![screenshot_6](https://github.com/devil-danil/kit/blob/main/task-5/screenshots/screenshot_6.png)

Получился не очень информативный график, но из очевидного:
- Файл отдан за ~1.5 с; пик ≈ 700 pkt/s.
- Повторов практически нет → сеть без потерь, Reno не «проседает».
- Длинный хвост трафика пустой — нужно резать или строить график на меньшем диапазоне.

Попробуем улучшить читаемость графика:
- Заменим в Y-Axis на Packets на Bits
- Уменьшим масштаб
- Оставим фильтрацию по tcp и выбранным ip

![screenshot_7](https://github.com/devil-danil/kit/blob/main/task-5/screenshots/screenshot_7.png)

### reno - bbr 0

на vm1 

`sudo sysctl -w net.ipv4.tcp_congestion_control=bbr`

на vm0:

```bash
sudo tcpdump -i enp0s1 -s0 -w vm0_reno-vm1_bbr_0.pcap &
PID=$!
curl -o /dev/null http://192.168.64.2/file_10m
sudo kill -INT $PID
```

tc qdisc show dev enp0s1

tc qdisc del dev enp0s1 root netem

sudo tc qdisc replace dev enp0s1 root netem delay 10ms loss 0%
sudo tc qdisc replace dev enp0s1 root netem delay 100ms loss 0%
sudo tc qdisc replace dev enp0s1 root netem delay 10ms loss 2%
sudo tc qdisc replace dev enp0s1 root netem delay 50ms loss 2%
sudo tc qdisc replace dev enp0s1 root netem delay 100ms loss 2%
sudo tc qdisc replace dev enp0s1 root netem delay 10ms loss 6%