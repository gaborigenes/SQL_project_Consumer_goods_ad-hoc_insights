-- 1. Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.
SELECT DISTINCT market
FROM dim_customer
WHERE customer = 'Atliq Exclusive' AND region = 'APAC';

--2 What is the percentage of unique product increase in 2021 vs. 2020? The
-- final output contains these fields, unique_products_2020 unique_products_2021 percentage_chg
WITH
    unique_products_2020 AS (
        SELECT COUNT(DISTINCT m.product_code) AS count
        FROM fact_manufacturing_cost m
        WHERE m.cost_year =2020
    ),
    unique_products_2021 AS (
        SELECT COUNT(DISTINCT m.product_code) AS count
        FROM fact_manufacturing_cost m
        WHERE m.cost_year = 2021
    )
SELECT
	(SELECT count FROM unique_products_2020) AS unique_products_2020,
    (SELECT count FROM unique_products_2021) AS unique_products_2021,
    ROUND(
    ((SELECT count FROM unique_products_2021) - (SELECT count FROM unique_products_2020))*100.0/
    (SELECT count FROM unique_products_2020),2) AS percentage_chg;

--3. Provide a report with all the unique product counts for each segment and sort them in descending order of product counts. 
--The final output contains 2 fields: segment,product_count
SELECT    segment,
    COUNT(DISTINCT product_code) AS product_count
FROM dim_product
GROUP BY segment
ORDER BY product_count DESC;
--4. Follow-up: Which segment had the most increase in unique products in
--2021 vs 2020? The final output contains these fields:- segment- product_count_2020- product_count_2021- difference

WITH product_count_2020 AS(
      SELECT    segment,
        COUNT(DISTINCT p.product_code) AS count2020
      FROM dim_product p
      INNER JOIN fact_manufacturing_cost m ON p.product_code=m.product_code
      WHERE m.cost_year='2020'
      GROUP BY segment
    ),
    product_count_2021 AS(
      SELECT    segment,
        COUNT(DISTINCT p.product_code) AS count2021
      FROM dim_product p
      INNER JOIN fact_manufacturing_cost m ON p.product_code=m.product_code
      WHERE m.cost_year='2021'
      GROUP BY segment
    )

SELECT
	COALESCE(p2020.segment, p2021.segment) AS segment,
    p2020.count2020 AS product_count_2020,
    p2021.count2021 AS product_count_2021,
    (p2021.count2021-p2020.count2020) AS difference
FROM product_count_2020 p2020
FULL OUTER JOIN product_count_2021 p2021 ON p2020.segment = p2021.segment;

--5. Get the products that have the highest and lowest manufacturing costs.
--The final output should contain these fields: product_code, product, manufacturing_cost
  WITH highest AS(
      SELECT m.product_code, p.product, m.manufacturing_cost
      FROM fact_manufacturing_cost m
      JOIN dim_product p ON p.product_code = m.product_code
      WHERE manufacturing_cost = (SELECT max(manufacturing_cost) FROM fact_manufacturing_cost)
      ),

      lowest AS(
      SELECT m.product_code, p.product, m.manufacturing_cost
      FROM fact_manufacturing_cost m
      JOIN dim_product p ON p.product_code = m.product_code
      WHERE manufacturing_cost = (SELECT min(manufacturing_cost) FROM fact_manufacturing_cost)
      )

SELECT * from highest
UNION
SELECT * FROM LOWEST;

--6. Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct
--for the fiscal year 2021 and in the Indian market. The final output contains these fields:
--customer_code, customer, average_discount_percentage

SELECT TOP 5
        c.customer_code,
        c.customer,
        AVG(d.pre_invoice_discount_pct) AS average_discount_percentage
FROM fact_pre_invoice_deduction d
JOIN dim_customer c ON d.customer_code = c.customer_code
WHERE fiscal_year = '2021' AND market= 'india'
GROUP BY c.customer_code, c.customer
ORDER BY average_discount_percentage DESC;

--7. Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month.
--This analysis helps to get an idea of low and high-performing months and take strategic decisions.
--The final report contains these columns:Month,Year,Gross sales Amount

SELECT
        DATENAME(MONTH, s.date) AS month,
        YEAR(s.date) AS year,
        CONCAT((ROUND(SUM(s.sold_quantity * p.gross_price)/1000000,2)),' M') AS gross_sales_amount
FROM fact_sales_monthly s
JOIN fact_gross_price p ON s.product_code = p.product_code
JOIN dim_customer c ON c.customer_code = s.customer_code
WHERE c.customer = 'Atliq Exclusive'
GROUP BY YEAR(s.date), MONTH(s.date), DATENAME(MONTH, s.date)
ORDER BY year, MONTH(s.date);

--8. In which quarter of 2020, got the maximum total_sold_quantity?
--The finaloutput contains these fields sorted by the total_sold_quantity:
--Quarter
--total_sold_quantit

SELECT
        CASE
            WHEN date BETWEEN '2019-09-01' AND '2019-11-30' THEN 1
            WHEN date BETWEEN '2019-12-01' AND '2020-02-29' THEN 2
            WHEN date BETWEEN '2020-03-01' AND '2020-05-31' THEN 3
            WHEN date BETWEEN '2020-06-01' AND '2020-08-31' THEN 4
        END AS quarters,
        SUM(sold_quantity) AS total_sold_quantity
FROM fact_sales_monthly
WHERE fiscal_year = 2020
GROUP BY
       CASE
            WHEN date BETWEEN '2019-09-01' AND '2019-11-30' THEN 1
            WHEN date BETWEEN '2019-12-01' AND '2020-02-29' THEN 2
            WHEN date BETWEEN '2020-03-01' AND '2020-05-31' THEN 3
            WHEN date BETWEEN '2020-06-01' AND '2020-08-31' THEN 4
        END
ORDER BY quarters;

--9. Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution?
--The final output contains these fields: channel,gross_sales_mln,percentage


SELECT
	c.channel,
    SUM(s.sold_quantity*p.gross_price) AS gross_sale_mln,
    ROUND(SUM(s.sold_quantity*p.gross_price)/
		(SELECT SUM(s2.sold_quantity*p2.gross_price)
        FROM fact_sales_monthly s2
        JOIN fact_gross_price p2 ON s2.product_code = p2.product_code
        WHERE s2.fiscal_year='2021')*100,2) AS Percentage
FROM fact_sales_monthly s
JOIN fact_gross_price p ON s.product_code=p.product_code
JOIN dim_customer c ON c.customer_code=s.customer_code
WHERE s.fiscal_year='2021'
GROUP BY c.channel
ORDER BY Percentage DESC;


--10. Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021?
--The final output contains these fields: division,product_code,product,total_sold_quantity,rank_order

WITH product_sales AS(
	SELECT
		p.division,
		p.product_code,
		p.product,
		sum(CAST(s.sold_quantity AS INT)) AS total_sold_quantity,
		RANK () OVER (PARTITION BY p.division ORDER BY SUM(CAST(s.sold_quantity AS DECIMAL(18,2))) DESC) AS rank_order
    FROM dim_product p
    JOIN fact_sales_monthly s ON p.product_code = s.product_code
    WHERE fiscal_year=2021
    GROUP BY P.division, p.product_code, p.product
    )

SELECT
	division,
    product_code,
    product,
    total_sold_quantity,
    rank_order
FROM product_sales
WHERE rank_order <=3
ORDER BY division, rank_order;