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