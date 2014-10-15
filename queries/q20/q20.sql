--Customer segmentation for return analysis: Customers are separated
--along the following dimensions: return frequency, return order ratio (total num-
--ber of orders partially or fully returned versus the total number of orders),
--return item ratio (total number of items returned versus the number of items
--purchased), return amount ration (total monetary amount of items returned ver-
--sus the amount purchased), return order ratio. Consider the store returns during
--a given year for the computation.

-- Resources

------ create input table for mahout --------------------------------------
--keep result human readable
set hive.exec.compress.output=false;
set hive.exec.compress.output;

DROP TABLE IF EXISTS ${hiveconf:TEMP_TABLE};
CREATE TABLE ${hiveconf:TEMP_TABLE} (
  cid            INT,
  r_order_ratio  DOUBLE,
  r_item_ratio   DOUBLE,
  r_amount_ratio DOUBLE,
  r_freq         INT
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ' ' LINES TERMINATED BY '\n'
STORED AS TEXTFILE LOCATION '${hiveconf:TEMP_DIR}';


INSERT INTO TABLE ${hiveconf:TEMP_TABLE}
SELECT
  cid,
  100.0 * COUNT(distinct (CASE WHEN r_date IS NOT NULL THEN oid ELSE 0 END)) / COUNT(distinct oid) AS r_order_ratio,
  SUM(CASE WHEN r_date IS NOT NULL THEN 1 ELSE 0 END) / COUNT(item) * 100 AS r_item_ratio,
  CASE WHEN SUM(s_amount)=0.0 THEN 0.0 ELSE (SUM(CASE WHEN r_date IS NOT NULL THEN r_amount ELSE 0.0 END) / SUM(s_amount) * 100) END AS r_amount_ratio,
  COUNT(distinct (CASE WHEN r_date IS NOT NULL THEN r_date ELSE 0 END)) AS r_freq
FROM (
  SELECT --s.ss_sold_date_sk AS s_date, --
    r.sr_returned_date_sk AS r_date,
    s.ss_item_sk AS item,
    s.ss_ticket_number AS oid,
    s.ss_net_paid AS s_amount,
    CASE WHEN r.sr_return_amt IS NULL THEN 0.0 ELSE r.sr_return_amt END AS r_amount,
    (CASE WHEN s.ss_customer_sk  IS NULL THEN r.sr_customer_sk ELSE s.ss_customer_sk END) AS cid
    --s.ss_customer_sk AS s_cid,
    --sr_customer_sk AS r_cid
  FROM store_sales s
  --LEFT JOIN = LEFT OUTER JOIN
  LEFT OUTER JOIN store_returns r ON (
    r.sr_item_sk = s.ss_item_sk
    AND r.sr_ticket_number = s.ss_ticket_number
    AND s.ss_sold_date_sk IS NOT NULL
  )
) q20_sales_returns

WHERE cid IS NOT NULL
--Hive does not support GROUP BY 1 (any)
GROUP BY cid
--(below) error in data: returns NULL
--HAVING COUNT(distinct (CASE WHEN r_date IS NOT NULL THEN r_date ELSE NULL END)) > 1
;

------- Cleanup --------------------------------------
