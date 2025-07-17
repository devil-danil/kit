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