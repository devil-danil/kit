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

2. Распаковываю архив ya-kit.tar.gz

Смотрю содержимое архива

`tar -tzf ya-kit.tar.gz`

>ya-kit/
>ya-kit/motd
>ya-kit/Dockerfile
>ya-kit/zshrc

`tar -xzf ya-kit.tar.gz`

3. Собираю docker образ

`docker build -t clab .`

4. Создаю yml-файл топологии сети

Содержимое part1-topology.clab.yml:

<pre>
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
</pre>


