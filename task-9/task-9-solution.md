# Домашнее задание 9

### Тема лекции
> "Базы данных ч. 2"

### Среда выполнения
> ВМ в YC на Ubuntu 24.04.2 LTS

### Задание

**Легенда:**

Ваш коллега стажер-аналитик для одной из своих задач настроил поставку данных из продуктовой базы PostgreSQL в ClickHouse и сделал дашборд поверх данных ClickHouse.
И благополучно ушел в отпуск. Ваши коллеги выкатили релиз, а кто-то из менеджеров решил открыть дашборд вашего коллеги. Дашборд не открывается.
Вам предлагается его починить.

Как решаем:
1) Настраиваем себе yc cli по инструкции https://yandex.cloud/ru/docs/cli/quickstart
2) Генерируем пару ssh-ключей, если у вас вдруг нет
3) Заводим себе сеть и сабнеты, после чего создаём себе виртуалку:

```bash
yc compute instance create --name <name>  --zone <your zone> --network-interface subnet-name=<your subnet name>,nat-ip-version=ipv4 --create-boot-disk image-id=fd8dhithmscqkra8qrmc,type=network-ssd --ssh-key /path/to/.ssh/id_rsa.pub --cores 2 --memory 4GB
```

На 80 порту живёт дашборд, логин/пароль dashboard/kit2025-db2-homework.
Сам код дашборда живёт в /opt/dashboard, запускается под systemd сервисом dashboard.service.
СУБД там локальная (и PostgreSQL, и ClickHouse).

**Ваша задача:**

Изменениями кода dashboard'а и минимально инвазивными изменениями в СУБД добиться того, чтобы dashboard открывался и работал с приемлимой скоростью.
Дропнуть все данные нельзя. Трогать PostgreSQL нельзя (и ходить в него из dashboard тоже).

**Как сдавать:**

От вас нужен архив с работающей версией dashboard (venv не нужен, только код самого dashboard) и sql-файлом с изменениями в ClickHouse.

### Решение

1. Удаляю старую ВМ

`yc compute instance delete vm_dz8`

2. Создаю новую ВМ

```bash
yc compute instance create --name vm_dz9  --zone ru-central1-a --network-interface subnet-name=my-yc-subnet-a,nat-ip-version=ipv4 --create-boot-disk image-id=fd8dhithmscqkra8qrmc,type=network-ssd --ssh-key /Users/devil_danil/.ssh/id_ed25519.pub --cores 2 --memory 4GB
```

3. Получили следующие данные для подключения:

```bash
one_to_one_nat:
        address: 84.201.174.80
        ip_version: IPV
```

Проверяю статус службы, управляющей дашбодом

`systemctl status dashboard.service`

![screenshot_1](https://github.com/devil-danil/kit/blob/main/task-9/screenshots/screen_1.jpg)

> Служба активна

4. Пробуем проверить зайти на страничку с дашбордом. Вводим наш IP и порт 84.201.174.80:80

![screenshot_2](https://github.com/devil-danil/kit/blob/main/task-9/screenshots/screen_2.jpg)

> Видим, что инофрмация недоступна, данные не могут загрузиться, также утекает память при работе дашборда

Посмотрим логи службы dashboard

`sudo journalctl -u dashboard.service -n 50 --no-pager`

![screenshot_3](https://github.com/devil-danil/kit/blob/main/task-9/screenshots/screen_3.jpg)

5. Вынесу SQL-скрипт в отдельный файл, чтобы агрегировать остатки по каждой категории товаров

**/opt/dashboard/stock_by_category.sql**

```sql
/* ----------------  stock_by_category.sql  ------------------
   Строим ежедневные дельты остатков по категориям
   ----------------------------------------------------------- */

--------------------------
-- 1. Остаток «на вчера»
--------------------------
SELECT
    c.name                       AS category,
    sum(pos.product_count)       AS delta,
    toDate(today() - 1)          AS event_date
FROM data.products_on_shelves    AS pos
JOIN data.product_categories     AS pc  ON pc.product_id  = pos.product_id
JOIN data.categories             AS c   ON c.category_id  = pc.category_id
GROUP BY category

UNION ALL

--------------------------
-- 2. Продажи (checks)
--------------------------
SELECT
    c.name                       AS category,
    sum(pp.product_count)        AS delta,           -- знак «+»
    toDate(ch.issue_date)        AS event_date
FROM data.checks                 AS ch          -- ← проверьте имя ключа (check_id / id)
JOIN data.product_check_positions pp ON pp.check_id   = ch.check_id
JOIN data.product_categories     AS pc  ON pc.product_id  = pp.product_id
JOIN data.categories             AS c   ON c.category_id  = pc.category_id
GROUP BY category, event_date

UNION ALL

--------------------------
-- 3. Внешние поставки
--------------------------
SELECT
    c.name                       AS category,
   -sum(ep.product_count)        AS delta,           -- знак «–»
    toDate(es.finish_date)       AS event_date
FROM data.external_supplies      AS es
JOIN data.external_supplies_products ep
     ON  ep.ext_supply_id = es.ext_supply_id         -- ← ваши реальные поля
JOIN data.product_categories     AS pc
     ON  pc.product_id  = ep.product_id
JOIN data.categories             AS c
     ON  c.category_id = pc.category_id
GROUP BY category, event_date

/*  Если нужны внутренние supplies  — вставьте сюда аналогичный SELECT  */

ORDER BY event_date, category
```

6. Также обновлю конфиг службы /etc/systemd/system/dashboard.service. Чтобы минимизировать утечку памяти и чтобы сервер не падал

```ini
[Unit]
Description=Streamlit Dashboard (stocks by category)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/dashboard
ExecStart=/opt/dashboard/venv/bin/streamlit run \
          --server.port 8000 \
          --server.headless true \
          --browser.gatherUsageStats false \
          dashboard.py

#    Ограничения памяти сняты до отладки (иначе OOM-kill)
#    Верните лимиты, когда удостоверитесь, что процесс стабилен.
MemoryHigh=0
MemoryMax=0

Restart=always
RestartSec=5s

# Опционально — логирование прямо в journald
StandardOutput=journal
StandardError=inherit

[Install]
WantedBy=multi-user.target
```

7. Файл /opt/dashboard/dashboard.py выглядит следующим образом

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Streamlit-дашборд «Остатки по категориям»
Работает поверх ClickHouse, выдаёт area-chart.
"""

import pandas as pd
import streamlit as st
import clickhouse_connect
from pathlib import Path

###############################
# 1. Конфигурация
###############################
CK_HOST = "localhost"
CK_PORT = 8123
CK_USER = "default"
CK_PASS = ""                 # или возьмите из переменных окружения
SQL_FILE = Path(__file__).with_name("stock_by_category.sql")

###############################
# 2. Подключение к БД (кэшируем ресурс)
###############################
@st.cache_resource(show_spinner=False)
def get_client():
    return clickhouse_connect.get_client(
        host=CK_HOST, port=CK_PORT,
        username=CK_USER, password=CK_PASS)

###############################
# 3. Получение датафрейма (кэшируем данные)
###############################
@st.cache_data(ttl=3600, show_spinner="Загружаем данные из ClickHouse…")
def load_data() -> pd.DataFrame:
    sql = SQL_FILE.read_text(encoding="utf-8")
    df  = get_client().query_df(sql)

    # event_date | category | delta  →  pivot + cumsum
    df = (df
          .groupby(["event_date", "category"])["delta"]
          .sum()
          .unstack(fill_value=0)
          .sort_index()        # по возрастанию даты
          .cumsum())
    return df

###############################
# 4. UI
###############################
st.set_page_config(page_title="Склад-Store Dashboard", layout="wide")
st.title("Остатки товаров по категориям")

data = load_data()
st.area_chart(data)

st.caption(
    "Данные обновляются раз в час · "
    "ClickHouse → Streamlit → area-chart"
)
```

8. В результате исправленного скрипта и SQL-запроса, вынесенного в отдельный файл, рисуется следующий дашборд

![screenshot_4](https://github.com/devil-danil/kit/blob/main/task-9/screenshots/screen_4.jpg)

> Бабочки тоже не плохо! Увы не хватило времени довести до ума

