-- =====================================================================
-- Superstore Sales Analysis - SQL queries
-- Database : superstore.db (SQLite), created by sales_analysis.ipynb
-- Tables   : orders   (one row = one product line inside an order)
--            returns  (one row = one order ID that the customer returned)
--
-- Part 1 (Q1-Q8)  : core business questions  - GROUP BY, HAVING, ORDER BY
-- Part 2 (Q9-Q14) : deeper analysis          - CTEs, window functions,
--                                              JOINs, CASE WHEN
--
-- The notebook splits this file on the semicolon character and runs the
-- queries in order, so keep exactly one semicolon at the end of each query
-- (and none inside comments).
-- =====================================================================


-- Q1: Top 5 products by total profit
-- Group every order line by product, add up its profit, keep the best 5.
SELECT
    product_name,
    category,
    ROUND(SUM(sales), 2)  AS total_sales,
    ROUND(SUM(profit), 2) AS total_profit
FROM orders
GROUP BY product_name, category
ORDER BY total_profit DESC
LIMIT 5;


-- Q2: Profit by region (the first row is the top region)
-- Profit margin = profit / sales, shown as a percentage.
SELECT
    region,
    ROUND(SUM(sales), 2)                      AS total_sales,
    ROUND(SUM(profit), 2)                     AS total_profit,
    ROUND(100.0 * SUM(profit) / SUM(sales), 1) AS profit_margin_pct
FROM orders
GROUP BY region
ORDER BY total_profit DESC;


-- Q3: Profit by category (the three top-level product groups)
SELECT
    category,
    ROUND(SUM(sales), 2)                      AS total_sales,
    ROUND(SUM(profit), 2)                     AS total_profit,
    ROUND(100.0 * SUM(profit) / SUM(sales), 1) AS profit_margin_pct
FROM orders
GROUP BY category
ORDER BY total_profit DESC;


-- Q4: Profit by sub-category (used for the "profit by category" chart)
SELECT
    category,
    sub_category,
    ROUND(SUM(profit), 2) AS total_profit
FROM orders
GROUP BY category, sub_category
ORDER BY total_profit DESC;


-- Q5: Loss-making categories
-- No top-level category loses money overall, so we look one level deeper.
-- HAVING filters AFTER grouping (WHERE would filter single rows before it).
SELECT
    category,
    sub_category,
    ROUND(SUM(sales), 2)  AS total_sales,
    ROUND(SUM(profit), 2) AS total_profit
FROM orders
GROUP BY category, sub_category
HAVING SUM(profit) < 0
ORDER BY total_profit ASC;


-- Q6: Monthly sales trend
-- strftime('%Y-%m', date) turns a date like 2017-11-08 into '2017-11'.
SELECT
    strftime('%Y-%m', order_date) AS month,
    COUNT(DISTINCT order_id)      AS orders,
    ROUND(SUM(sales), 2)          AS total_sales,
    ROUND(SUM(profit), 2)         AS total_profit
FROM orders
GROUP BY month
ORDER BY month;


-- Q7: Discount vs profit
-- For each discount level: how many order lines, and the average profit per line.
SELECT
    discount,
    COUNT(*)              AS order_lines,
    ROUND(AVG(profit), 2) AS avg_profit_per_line,
    ROUND(SUM(profit), 2) AS total_profit
FROM orders
GROUP BY discount
ORDER BY discount;


-- Q8: Top 10 customers by total sales
SELECT
    customer_name,
    segment,
    COUNT(DISTINCT order_id) AS orders,
    ROUND(SUM(sales), 2)     AS total_sales,
    ROUND(SUM(profit), 2)    AS total_profit
FROM orders
GROUP BY customer_id, customer_name, segment
ORDER BY total_sales DESC
LIMIT 10;


-- =====================================================================
-- PART 2 - Deeper analysis
-- =====================================================================


-- Q9: Year-over-year sales growth
-- CTE: "WITH yearly AS (...)" builds a temporary result we can query
--      like a table. It keeps the main query short and readable.
-- LAG(x) OVER (ORDER BY year) looks at the value of x in the PREVIOUS row,
--      so each year can be compared with the year before it.
--      The first year has no previous row, so its growth is NULL.
WITH yearly AS (
    SELECT
        strftime('%Y', order_date) AS year,
        SUM(sales)                 AS total_sales,
        SUM(profit)                AS total_profit
    FROM orders
    GROUP BY year
)
SELECT
    year,
    ROUND(total_sales, 2)                                   AS total_sales,
    ROUND(LAG(total_sales) OVER (ORDER BY year), 2)         AS previous_year_sales,
    ROUND(100.0 * (total_sales - LAG(total_sales) OVER (ORDER BY year))
          / LAG(total_sales) OVER (ORDER BY year), 1)       AS sales_growth_pct,
    ROUND(100.0 * total_profit / total_sales, 1)            AS profit_margin_pct
FROM yearly
ORDER BY year;


-- Q10: Top 3 most profitable products in each region
-- RANK() OVER (PARTITION BY region ORDER BY total_profit DESC)
--      restarts the ranking at 1 for every region (PARTITION BY = "per group").
-- A window function can't be used inside WHERE, so we rank in one CTE
--      and filter on the rank in the final SELECT.
WITH product_profit AS (
    SELECT
        region,
        product_name,
        SUM(profit) AS total_profit
    FROM orders
    GROUP BY region, product_name
),
ranked AS (
    SELECT
        region,
        product_name,
        ROUND(total_profit, 2) AS total_profit,
        RANK() OVER (PARTITION BY region ORDER BY total_profit DESC) AS profit_rank
    FROM product_profit
)
SELECT region, profit_rank, product_name, total_profit
FROM ranked
WHERE profit_rank <= 3
ORDER BY region, profit_rank;


-- Q11: Running total of sales through each year (year-to-date)
-- SUM(...) OVER (PARTITION BY year ORDER BY month) adds up every month so far
--      inside the same year, then starts again from zero in January.
WITH monthly AS (
    SELECT
        strftime('%Y', order_date)    AS year,
        strftime('%Y-%m', order_date) AS month,
        SUM(sales)                    AS monthly_sales
    FROM orders
    GROUP BY year, month
)
SELECT
    month,
    ROUND(monthly_sales, 2) AS monthly_sales,
    ROUND(SUM(monthly_sales) OVER (PARTITION BY year ORDER BY month), 2) AS sales_year_to_date
FROM monthly
ORDER BY month;


-- Q12: Return rate by region
-- LEFT JOIN keeps EVERY order, even ones with no match in returns.
--      For orders that were not returned, r.order_id is NULL.
-- COUNT(DISTINCT r.order_id) skips NULLs, so it counts only returned orders.
-- (An INNER JOIN would keep only returned orders, so we couldn't get a rate.)
SELECT
    o.region,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT r.order_id) AS returned_orders,
    ROUND(100.0 * COUNT(DISTINCT r.order_id) / COUNT(DISTINCT o.order_id), 1) AS return_rate_pct
FROM orders AS o
LEFT JOIN returns AS r
    ON o.order_id = r.order_id
GROUP BY o.region
ORDER BY return_rate_pct DESC;


-- Q13: Returns by sub-category (share of order lines returned, and their sales value)
-- CASE WHEN ... THEN 1 ELSE 0 END turns "was it returned?" into 1 or 0,
--      so SUM() of it counts the returned lines.
SELECT
    o.sub_category,
    COUNT(*) AS order_lines,
    SUM(CASE WHEN r.order_id IS NOT NULL THEN 1 ELSE 0 END) AS returned_lines,
    ROUND(100.0 * SUM(CASE WHEN r.order_id IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 1)
        AS return_rate_pct,
    ROUND(SUM(CASE WHEN r.order_id IS NOT NULL THEN o.sales ELSE 0 END), 2)
        AS returned_sales
FROM orders AS o
LEFT JOIN returns AS r
    ON o.order_id = r.order_id
GROUP BY o.sub_category
ORDER BY return_rate_pct DESC;


-- Q14: Is it the discount or the product? Margin by discount band within each sub-category
-- Q7 showed that big discounts lose money. But maybe products that already lose
-- money just get discounted more. To check, we compare the SAME sub-category at
-- different discount levels. If margin still drops as discount rises, the
-- discount itself is the problem.
-- CASE WHEN sorts every line into one of three bands (the numbers keep them in order).
SELECT
    sub_category,
    CASE
        WHEN discount = 0    THEN '1. No discount'
        WHEN discount <= 0.2 THEN '2. 1-20%'
        ELSE                      '3. Over 20%'
    END AS discount_band,
    COUNT(*) AS order_lines,
    ROUND(100.0 * SUM(profit) / SUM(sales), 1) AS profit_margin_pct
FROM orders
GROUP BY sub_category, discount_band
ORDER BY sub_category, discount_band;
