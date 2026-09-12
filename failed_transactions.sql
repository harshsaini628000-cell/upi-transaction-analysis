create database tb9;
use tb9;

CREATE TABLE upi_transactions (
    transaction_id VARCHAR(50) PRIMARY KEY,
    date DATE,
    time TIME,
    payment_app VARCHAR(50),
    transaction_type VARCHAR(10),
    category VARCHAR(50),
    amount_inr DECIMAL(10, 2),
    sender_bank VARCHAR(100),
    receiver_bank VARCHAR(100),
    device_type VARCHAR(20),
    network_type VARCHAR(20),
    city VARCHAR(100),
    status VARCHAR(20),
    failure_reason VARCHAR(150),
    retry_attempted VARCHAR(10),
    response_time_ms INT
);



select * from upi_transactions
limit 10;


-- Basic & Exploratory Queries


-- Q1 . Volume & Failure Overview: What is the overall transaction success rate versus failure rate, and
 -- what is the total monetary volume (INR) processed across all transactions?
 
 SELECT
    COUNT(*) AS total_transactions,

    SUM(status = 'Success') AS successful_transactions,

    SUM(status = 'Failed') AS failed_transactions,

    ROUND(
        SUM(status = 'Success') * 100.0 / COUNT(*), 2
    ) AS success_rate,

    ROUND(
        SUM(status = 'Failed') * 100.0 / COUNT(*), 2
    ) AS failure_rate,

    SUM(amount_inr) AS total_volume_inr

FROM upi_transactions;



-- Q2. App Market Share: How many transactions were processed by each payment_app, and 
-- what percentage of total transactions does each app represent?


SELECT
    payment_app,
    COUNT(*) AS transaction_count,
    ROUND(
        COUNT(*) * 100.0 / (SELECT COUNT(*) FROM upi_transactions),
        2
    ) AS transaction_percentage
FROM upi_transactions
GROUP BY payment_app
ORDER BY transaction_count DESC;


-- Q3. Top Failure Reasons: What are the top 5 most frequent failure_reason entries, 
-- and what is the average transaction amount for each of these failure types?

select failure_reason,
       count(*) as failure_count,
       round(avg(amount_inr),2) as avg_amount
       from upi_transactions
       where failure_reason is not null
       group by failure_reason
       order by failure_count desc
       limit 5;
       
       
-- Q4. Device & Network Breakdown: Which combination of device_type (Android vs. iOS) 
-- and network_type (5G, 4G, 3G, WiFi) accounts for the highest transaction count?

select device_type,
       network_type,
       count(*) as total_tc
from upi_transactions
group by device_type,network_type
order by total_tc desc
limit 1;


-- Q5. City-Level Volume: Which top 5 cities have the highest total transaction amounts in INR?

select city,
       sum(amount_inr) as total_tc
from upi_transactions
group by city
order by total_tc desc
limit 5;       

-- Q6.App Failure Rate: Calculate the failure rate percentage for each payment_app using CASE
-- expressions:\text{Failure Rate} = \frac{\text{Failed Transactions}}{\text{Total Transactions}} \times 100

select 
      payment_app,
      count(*) as total_transactions,
      
sum(
          CASE
             when status = 'failed' then 1
             else 0
             end
             ) as failed_transactions,
             
round(  
       sum(
             case 
                 when status = 'failed' then 1
                 else 0
                 end
             ) * 100.0 / count(*),2
              ) as transactions_failure_rate
              
FROM upi_transactions
GROUP BY payment_app
ORDER BY transactions_failure_rate DESC;


-- Q7. Bank Reliability Index: Which sender_bank has the highest failure rate, and what is the breakdown
--  between user-induced failures (e.g., Insufficient Balance) vs. technical failures (e.g., Bank Server Down, NPCI Server Error)?

select 
	 sender_bank,
     count(*) as total_transactions,

sum(
     CASE
         WHEN status = 'failed'THEN 1
         ELSE 0
         END
) AS failed_transactions,

ROUND(  
       SUM(
             CASE 
                 WHEN status = 'failed' THEN 1
                 ELSE 0
                 END
             ) * 100.0 / count(*),2
              ) AS failure_rate,
              
SUM(
     CASE 
        WHEN status = 'failed'
         AND failure_reason = 'Insufficient Balance' THEN 1
         ELSE 0
         END
         ) AS user_induced,
  
SUM(
     CASE 
		WHEN status = 'failed'
         AND failure_reason IN ( 'Bank Server Down', 'NPCI Server Error')
          THEN 1
          ELSE 0
          END
          ) AS technical_failures
       
FROM upi_transactions
GROUP BY sender_bank
ORDER BY failure_rate DESC
LIMIT 1;
  
 -- Q8. Peak Hour Latency Analysis: Extract the hour from time to determine which hour of the day experiences
--   the highest transaction volume, and compare the average response_time_ms during peak hours versus off-peak hours.            

 WITH hourly_volume AS (
    SELECT
        HOUR(time) AS transaction_hour,
        COUNT(*) AS transaction_volume,
        DENSE_RANK() OVER (ORDER BY COUNT(*) DESC) AS rnk
    FROM upi_transactions
    GROUP BY HOUR(time)
)
SELECT
    CASE
        WHEN p.rnk = 1 THEN 'Peak Hour'
        ELSE 'Off-Peak'
    END AS hour_type,
    COUNT(*) AS transaction_count,
    ROUND(AVG(u.response_time_ms), 2) AS avg_response_time_ms
FROM upi_transactions u
JOIN hourly_volume p ON HOUR(u.time) = p.transaction_hour
GROUP BY hour_type;             


-- Q9. Network Latency Impact: Does network type correlate with latency? 
-- Calculate the average and median response_time_ms for each network_type, split by status (SUCCESS vs. FAILED).

WITH ranked_data AS (
    SELECT
        network_type,
        status,
        response_time_ms,
        ROW_NUMBER() OVER (
            PARTITION BY network_type, status
            ORDER BY response_time_ms
        ) AS rn,
        COUNT(*) OVER (
            PARTITION BY network_type, status
        ) AS total_rows
    FROM upi_transactions
)
SELECT
    network_type,
    status,
    ROUND(AVG(response_time_ms), 2) AS avg_response_time_ms,
    ROUND(AVG(
        CASE
            WHEN rn IN (
                FLOOR((total_rows + 1) / 2),
                CEIL((total_rows + 1) / 2)
            )
            THEN response_time_ms
        END
    ), 2) AS median_response_time_ms
FROM ranked_data
GROUP BY network_type, status
ORDER BY network_type, status;



-- Q10. Retry Behavior: For transactions 
-- where retry_attempted = 'Yes', what proportion are associated with each specific failure_reason?

SELECT
    failure_reason,
    COUNT(*) AS retry_count,
    ROUND(
        COUNT(*) * 100.0 /
        (SELECT COUNT(*)
         FROM upi_transactions
         WHERE retry_attempted = 'Yes'),
        2
    ) AS proportion_percentage
FROM upi_transactions
WHERE retry_attempted = 'Yes'
GROUP BY failure_reason
ORDER BY proportion_percentage DESC;



-- Q11. City-Level App Rankings: Using DENSE_RANK(), rank the payment_app 
-- options within each city based on total transaction volume (amount_inr).

select payment_app,
       city,
       sum(amount_inr) as total_tc_volume,
       dense_rank() over(partition by  city
                    order by sum(amount_inr) desc) as app_rank
       from upi_transactions
       group by payment_app,city
       order by city,app_rank;
       
       
-- Q12. High-Failure Bank Corridors: Identify the top 5 sender-receiver bank pairs
-- (sender_bank to receiver_bank) with the worst failure rates, filtering only for pairs with at least 30 total transactions.


select sender_bank,
       receiver_bank,
       count(*) as total_transactions,
sum(
     case
         when status = 'failed' then 1
         else 0
         end) as failed_transactions,
round(
       sum(   
             case
         when status = 'failed' then 1
         else 0
         end) * 100.0/count(*),2
             ) as failure_rate
from upi_transactions
GROUP BY sender_bank, receiver_bank
HAVING COUNT(*) >= 30
ORDER BY failure_rate DESC
LIMIT 5;             

-- Q13. Rolling Failure Trends: Using a Common Table Expression (CTE) and window functions, 
-- calculate the 7-day rolling average of daily transaction failures over time.

WITH daily_failures AS (
    SELECT
        date,
        SUM(
            CASE
                WHEN status = 'failed' THEN 1
                ELSE 0
            END
        ) AS daily_failure_count
    FROM upi_transactions
    GROUP BY date
)

SELECT
    date,
    daily_failure_count,
    ROUND(
        AVG(daily_failure_count) OVER (
            ORDER BY date
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ),
        2
    ) AS rolling_7_day_avg
FROM daily_failures
ORDER BY date;


-- Q14. Transaction Size Segmentation: Group transactions into tiers (< ₹100, ₹100–₹500, ₹501–₹2,000, ₹2,001–₹5,000, > ₹5,000) 
-- and determine if larger transactions suffer from higher failure rates or slower response times

SELECT
     CASE
    WHEN amount_inr < 100 THEN '< ₹100'
    WHEN amount_inr < 500 THEN '₹100–₹500'
    WHEN amount_inr < 2000 THEN '₹501–₹2,000'
    WHEN amount_inr < 5000 THEN '₹2,001–₹5,000'
    ELSE '> ₹5,000'
        END AS transaction_tier,

    COUNT(*) AS total_transactions,

    SUM(
        CASE
            WHEN status = 'failed' THEN 1
            ELSE 0
        END
    ) AS failed_transactions,

    ROUND(
        SUM(
            CASE
                WHEN status = 'failed' THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS failure_rate,

    ROUND(AVG(response_time_ms), 2) AS avg_response_time_ms

FROM upi_transactions

GROUP BY transaction_tier

ORDER BY
    CASE
        WHEN transaction_tier = '< ₹100' THEN 1
        WHEN transaction_tier = '₹100–₹500' THEN 2
        WHEN transaction_tier = '₹501–₹2,000' THEN 3
        WHEN transaction_tier = '₹2,001–₹5,000' THEN 4
        WHEN transaction_tier = '> ₹5,000' THEN 5
    END;
    
    
    
-- Q16. Latency Outlier Detection: Use AVG() and STDDEV() window functions to flag transactions 
-- whose response_time_ms is more than two standard deviations above the average for their specific category.

WITH latency_stats AS (
    SELECT
        transaction_id,
        category,
        response_time_ms,

        AVG(response_time_ms) OVER (
            PARTITION BY category
        ) AS avg_latency,

        STDDEV(response_time_ms) OVER (
            PARTITION BY category
        ) AS std_latency

    FROM upi_transactions
)

SELECT
    transaction_id,
    category,
    response_time_ms,
    ROUND(avg_latency, 2) AS avg_latency,
    ROUND(std_latency, 2) AS std_latency,

    CASE
        WHEN response_time_ms > avg_latency + (2 * std_latency)
        THEN 'Outlier'
        ELSE 'Normal'
    END AS latency_flag

FROM latency_stats
ORDER BY category, response_time_ms DESC;