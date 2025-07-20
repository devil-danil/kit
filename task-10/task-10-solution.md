# Домашнее задание 10

### Тема лекции
> "Траблшутинг распределенных систем"

### Среда выполнения
> ВМ в YC на Ubuntu 24.04.2 LTS

### Задание

**Легенда:**
Ваша компания планирует инвестировать в перспективный vibe-coding стартап с оценкой 3 млрд долларов. Продукт этого стартапа: key-value СУБД, целиком и полностью написанная современной LLM, которая никогда* не теряет данные (никогда - при ненарушении модели отказа).
Разработчики постулируют, что временная недоступность одной из нод не является превышением модели отказа.

Ваше руководство ставит вам задачу доказать, что это действительно так. Если база всё таки данные теряет при непревышении модели отказа, то компания инвестирует в покупку сырков на кофепоинты.

**Как решаем:**
1) Настраиваем себе yc cli по инструкции https://yandex.cloud/ru/docs/cli/quickstart
2) Генерируем пару ssh-ключей, если у вас вдруг нет
3) Заводим себе сеть и сабнеты, после чего создаём себе виртуалку:

```bash
yc compute instance create --name <name>  --zone <your zone> --network-interface subnet-name=<your subnet name>,nat-ip-version=ipv4 --create-boot-disk image-id=fd8e2o5cobk5dhqvh1ap,type=network-ssd --ssh-key /path/to/.ssh/id_rsa.pub --cores 2 --memory 4GB
```

4) Внутри есть 3 ноды СУБД, писать можно, например, так:

`curl -L --post302 -X POST http://localhost:8080/keys/key1 -d value1`

5) Читать так:

`curl -L -X GET http://localhost:8080/keys/key1`

6) Выключить одну ноду можно, например, так: systemctl stop database1.service
7) Запустить назад так: systemctl start database1.service

**Ваша задача:** написать воспроизводимый тест, который демонстрирует, что в каких-то случаях эта СУБД может потерять успешно записанный ключ (т.е. мы на POST получили 2xx, а потом GET'ом свой ключ достать не можем).
Тест при этом не должен превышать модель отказа, декларируемую разработчиками.

### Решение

1. Удаляю старую ВМ

`yc compute instance delete vm_dz9`

2. Создаю новую ВМ

```bash
yc compute instance create --name vm_dz10  --zone ru-central1-a --network-interface subnet-name=my-yc-subnet-a,nat-ip-version=ipv4 --create-boot-disk image-id=fd8e2o5cobk5dhqvh1ap,type=network-ssd --ssh-key /Users/devil_danil/.ssh/id_ed25519.pub --cores 2 --memory 4GB
```

3. Получили следующие данные для подключения:

```bash
one_to_one_nat:
        address: 158.160.41.5
        ip_version: IPV4
```
4. Подключаемся к ВМ и проверяем запущенные сервисы БД

`systemctl list-units | grep database`

![screenshot_1](https://github.com/devil-danil/kit/blob/main/task-10/screenshots/screen_1.png)

> Службы работаеют корректно

5. Проверяем, проходят ли запросы

![screenshot_2](https://github.com/devil-danil/kit/blob/main/task-10/screenshots/screen_2.png)

6. Подготовил следующий скрипт для тестирования отказоустройчивости БД - **kv_loss_repro.sh**

Получаю следующий вывод:

```bash
$ sudo ./kv_loss_repro.sh && echo "без потери (код=$?)" || echo "ключ потерян (код=$?)"
Front=database1   Victim=database2
Step A  stop database2
Step B  POST lost_20250721_110352
Step C  start database2
Step D  stop database1 (front)
Step E  GET lost_20250721_110352
ключ потерян! ожидали 'value_37412', получили ''

Архив сформирован: evidence_20250721_110352.tar.gz
── pre ──
db1: value_37412
db2: ABSENT
db3: ABSENT
── post ──
db1: ABSENT
db2: ABSENT
db3: ABSENT

ключ потерян (код=42)
```

Структура собранного архива (можно убедиться tree evidence_*):

```bash
evidence_20250721_110352/
├── cluster.log               ← журналы трёх нод за последние ~8 мин
├── pre/
│   ├── db1.json              ← checkpoint db1 (ключ есть)
│   ├── db1_wal.log
│   ├── db1.ls                ← ls-listing каталога /opt/data1
│   └── … db2/db3 анал.
└── post/
    ├── db1.json              ← checkpoint после падения лидера (обычно NO_CHECKPOINT)
    ├── db1_wal.log
    └── … db2/db3 …
```

#### Что было сделано

Мы нашли, что фронтовой порт 8080 держит только одна из трёх нод (database1–3). При записи лидер отвечает 200 OK даже тогда, когда запись оказалась лишь у него; позже он делает snapshot и обнуляет WAL. Если в этот момент любой follower был off-line, а потом мы перезапускаем лидера, — ключ пропадает при допущенной модели «падает максимум одна нода».

Логика скрипта kv_loss_repro.sh:

1)	Определяет сервис, реально слушающий 8080 (front).
2)	Останавливает другую ноду-follower.
3)	Делает POST ключа → лидер возвращает 2xx.
4)	Поднимает follower, затем гасит front/лидера.
5)	Делает GET: если пусто — фиксирует потерю и выходит с кодом 42.
6)	До и после собирает checkpoint/WAL/dir-listing и журналы всех трёх нод; сохраняет их в архив evidence_<timestamp>.tar.gz.

