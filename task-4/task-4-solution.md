# Домашнее задание 4

### Тема лекции
> "Основы интернета - IP"

### Среда выполнения
> Debian 12

## Часть 1 - настройка

> Знакомство с Containerlab и базовая настройка сети.

![screenshot_1](https://github.com/devil-danil/kit/blob/main/task-4/screenshots/screenshot_1.png)

---

### Задание

Прочитать гайд https://containerlab.dev/quickstart/

Собрать топологию выше, используя Containerlab и Linux контейнеры.

Dockerfile и файлы для образа с лекции можно взять по ссылке:

https://disk.yandex.ru/d/iMDH0kQPvMOGtA. Архив docker-ya-kit.tar.gz.

---

### Условия

Между всеми компьютерами есть IP связность (проверяем ping-ом).

---

### Выполнение

В качестве решения приложить файл топологии и все вспомогательные файлы.
Если собирали свой контейнер, то приложить Dockerfile.

## Решение части 1

1. Устанавливаю containerlab

`curl -sL https://containerlab.dev/setup | sudo -E bash -s "all"`

2. Смотрю содержимое архива

`tar -tzf ya-kit.tar.gz`

```
ya-kit/
ya-kit/motd
ya-kit/Dockerfile
ya-kit/zshrc
```

3. Распаковываю архив ya-kit.tar.gz

`tar -xzf ya-kit.tar.gz`

4. Собираю docker образ

`docker build -t clab .`

Внутри образа:

- Универсальная среда для отладки сети: все популярные CLI-утилиты диагностики, трассировки, захвата и генерации трафика.
- Мини-маршрутизатор: Bird 2 позволяет поднять BGP, OSPF, RIP или static routing прямо внутри контейнера (нужно только смонтировать конфиг и открыть capabilities, если требуется raw-сокеты).
- Комфортная оболочка: Oh My Zsh + Powerlevel10k с автодополнениями, кастомным .zshrc и приветствием.
- Готовая среда Python для сетевых скриптов (IPython + Scapy).
- SSH-доступ (если прокинуть 22/tcp и настроить ключи).

5. Создаю yml-файл топологии сети part1-topology.clab.yml

```yaml
name: part1-topology

topology:
  defaults:
    kind: linux
    image: clab
    cap-add: [ NET_ADMIN, NET_RAW ]
    network-mode: none

  nodes:
    br192:
      kind: bridge
    br172:
      kind: bridge

    r1:
      env: { HOSTNAME: r1 }
      exec:
        - ip addr add 192.168.100.1/24 dev eth1
        - ip addr add 172.16.100.1/24 dev eth2
        - sysctl -w net.ipv4.ip_forward=1

    # ------- subnet 192.168.100.0/24 -------
    pc1:
      env: { HOSTNAME: pc1 }
      exec:
        - ip addr add 192.168.100.10/24 dev eth1
        - ip route add default via 192.168.100.1

    pc3:
      env: { HOSTNAME: pc3 }
      exec:
        - ip addr add 192.168.100.20/24 dev eth1
        - ip route add default via 192.168.100.1

    # ------- subnet 172.16.100.0/24 -------
    pc2:
      env: { HOSTNAME: pc2 }
      exec:
        - ip addr add 172.16.100.10/24 dev eth1
        - ip route add default via 172.16.100.1

    pc4:
      env: { HOSTNAME: pc4 }
      exec:
        - ip addr add 172.16.100.20/24 dev eth1
        - ip route add default via 172.16.100.1

  links:
    # ---- 192.168.100.0/24 ----
    - endpoints: [ "pc1:eth1", "br192:pc1" ]
    - endpoints: [ "pc3:eth1", "br192:pc3" ]
    - endpoints: [ "r1:eth1",  "br192:r1_192" ]

    # ---- 172.16.100.0/24 ----
    - endpoints: [ "pc2:eth1", "br172:pc2" ]
    - endpoints: [ "pc4:eth1", "br172:pc4" ]
    - endpoints: [ "r1:eth2",  "br172:r1_172" ]
```

6. Развёртываем нашу сетевую лабораторию в соответсвии с yml-файлом

`sudo clab deploy  -t part1-topology.clab.yml`

![screenshot_2](https://github.com/devil-danil/kit/blob/main/task-4/screenshots/screenshot_2.png)

![screenshot_3](https://github.com/devil-danil/kit/blob/main/task-4/screenshots/screenshot_3.png)

7. Проверяю, что контейнеры с нашими ПК поднялись

`docker ps`

![screenshot_4](https://github.com/devil-danil/kit/blob/main/task-4/screenshots/screenshot_4.png)

8. Проверяю IP связность между компьютерами

> Захожу в bash-оболочку контейнера clab-part1-topology-pc1 и делаю ping к другим ПК

![screenshot_5](https://github.com/devil-danil/kit/blob/main/task-4/screenshots/screenshot_5.png)

## Часть 2 - траблшутинг

Нужно починить сеть. В ней есть несколько багов, которые мешают работать.

![screenshot_6](https://github.com/devil-danil/kit/blob/main/task-4/screenshots/screenshot_6.png)

---

### Задание

По ссылке https://disk.yandex.ru/d/iMDH0kQPvMOGtA скачать архив с лабой.

Файл docker-ya-kit.tar.gz.

Запустить лабу в Containerlab. Для запуска/остановки через скрипты start , stop
понадобится мультиплексор терминалов tmux, но запустить и подключаться к хостам
можно и вручную.

При помощи материала лекции попробовать найти все сломанные места. 
Пригодятся следующие утилиты:
- ip route [get|show]
- ip address show
- ip link show
- ip neigh show | arp
- mtr
- Wireshark | tcpdump

На всех хостах есть файлик /etc/hosts, так что к ним можно обращаться по имени.
Например pc2# ping pc1.

На всех хостах настроен ssh server и используется общая пара ключей.

---

## Условия

Между всеми компьютерами есть IP связность (проверяем ping-ом).

Между всеми компьютерами можно выполнить команду scp pcX:/test . - т.е. по
SSH(SFTP) скачать блоб test. Где X - номер хоста. 
Например `pc2# scp pc1:/test . && scp pc3:/test . && scp pc4:/test` и т.д.

---

### Выполнение

- Указать баги, которые были найдены.
- Описать процесс поиска багов, включая ошибочные гипотезы.
- Описать методы исправления найденных багов.
- Написать пару слов про то, почему такая топология сети плохо работает и так лучше
не делать.

---

### Подсказки

Все ошибки лежат в плоскости L2, L3 и касаются исключительно неправильной
конфигурации.

## Решение части 2

1. Распаковываем архив homework2.tar.gz

`tar -xzf homework2.tar.gz`

Содержимое архива:

![screenshot_7](https://github.com/devil-danil/kit/blob/main/task-4/screenshots/screenshot_7.png)

2. Устанавливаем tmux

`sudo apt install -y tmux`

![screenshot_8](https://github.com/devil-danil/kit/blob/main/task-4/screenshots/screenshot_8.png)

2. Переходим в директорию homework2 и откроем новый сеанс tmux

`tmux new -s lab`

3. Запустим скрипт start.sh, чтобы развернуть нашу сеть через clab, и через tmux разбить наш теринал на 4 окна

`./start.sh`

![screenshot_9](https://github.com/devil-danil/kit/blob/main/task-4/screenshots/screenshot_9.png)

Далее вводим `exit`, чтобы попасть в одну из панелей.



