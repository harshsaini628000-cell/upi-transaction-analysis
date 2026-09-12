# 📊 UPI Transactions & Failure Analysis (SQL Data Project)

## 📌 Project Overview
This project presents an end-to-end relational database investigation into Unified Payments Interface (UPI) transaction patterns, failure drivers, infrastructure latency, and banking corridor reliability. 

Using an enterprise-style dataset of **4,000 transactions**, this project leverages **MySQL** to evaluate system health, uncover technical vs. behavioral friction points, and rank payment application performance across major Indian metropolitan hubs.

---

## 🛠️ Technical Stack & Concepts Demonstrated
- **Database Engine:** MySQL 8.0+
- **Data Definition & Ingestion:** `CREATE TABLE`, data constraints, null-handling
- **Core Aggregations:** `COUNT(*)`, `SUM()`, `AVG()`, `ROUND()`, `GROUP BY`, `HAVING`
- **Conditional Logic:** Complex `CASE WHEN ... THEN ... ELSE ... END` statements
- **Common Table Expressions (CTEs):** Multi-step transformations using `WITH ... AS`
- **Advanced Window Functions:**
  - Ranking: `DENSE_RANK() OVER (...)`, `ROW_NUMBER() OVER (...)`
  - Moving Averages: `AVG() OVER (ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)`
  - Statistical Outlier Detection: `AVG() OVER (PARTITION BY ...)` & `STDDEV() OVER (PARTITION BY ...)`

---

## 📂 Database Schema

```sql
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
```

---

## 🔍 Query-by-Query Breakdown & Explanation

### **Q1. Overall Volume & Failure Overview**
* **Objective:** Establish executive baseline metrics: total transaction count, overall success vs. failure rates, and gross transaction value (INR).
* **SQL Highlights:**
  * Uses boolean aggregation `SUM(status = 'Success')` and `SUM(status = 'Failed')` to aggregate counts without subqueries.
  * Calculates percentage shares rounded to 2 decimal places.
  * Measures total circulating capital via `SUM(amount_inr)`.

---

### **Q2. Payment App Market Share**
* **Objective:** Determine market concentration across competing UPI platforms (e.g., Google Pay, PhonePe, Paytm, CRED, WhatsApp Pay).
* **SQL Highlights:**
  * Aggregates volume by `payment_app`.
  * Computes market share percentage dynamically against total transaction volume using an inline scalar subquery `(SELECT COUNT(*) FROM upi_transactions)`.
  * Sorts with `ORDER BY transaction_count DESC`.

---

### **Q3. Top 5 Failure Reasons & Financial Impact**
* **Objective:** Identify the primary root causes of transaction abandonment and check whether specific errors correlate with higher amounts.
* **SQL Highlights:**
  * Filters out successful records with `WHERE failure_reason IS NOT NULL`.
  * Aggregates frequency per error reason and computes `ROUND(AVG(amount_inr), 2)`.
  * Ranks and isolates the top 5 failure modes via `LIMIT 5`.

---

### **Q4. Device & Network Infrastructure Analysis**
* **Objective:** Pinpoint which operating system (`Android` vs. `iOS`) and telecommunication network (`5G`, `4G`, `3G`, `WiFi`) combination handles the highest traffic.
* **SQL Highlights:**
  * Multi-column grouping on `device_type` and `network_type`.
  * Orders descending by transaction volume to extract the highest frequency infrastructure profile.

---

### **Q5. Top 5 Cities by Financial Volume**
* **Objective:** Assess geographical revenue concentration and identify key regional transaction hubs.
* **SQL Highlights:**
  * Groups records by `city` and computes total monetary throughput (`SUM(amount_inr)`).
  * Sorts descending and limits to the top 5 regional markets.

---

### **Q6. Payment App Failure Rate Comparison**
* **Objective:** Evaluate the operational resilience of individual payment apps by computing their failure percentage.
* **SQL Highlights:**
  * Employs standard `CASE WHEN status = 'failed' THEN 1 ELSE 0 END` expressions inside `SUM()`.
  * Normalizes failed transactions over total app attempts to yield a comparative failure benchmark.

---

### **Q7. Bank Reliability Index (User-Induced vs. Technical Failures)**
* **Objective:** Identify the most failure-prone sender bank and distinguish between client-side issues (e.g., Insufficient Balance) versus institutional server crashes (e.g., Bank Server Down, NPCI Server Error).
* **SQL Highlights:**
  * Groups by `sender_bank` and calculates the overall failure rate.
  * Uses multi-condition `CASE` expressions to bifurcate failures into `user_induced` vs. `technical_failures`.
  * Orders by failure rate descending and isolates the worst-performing bank.

---

### **Q8. Peak Hour Latency Analysis**
* **Objective:** Dynamically identify the single highest-volume hour of the day and contrast its API latency against off-peak hours.
* **SQL Highlights:**
  * **CTE 1 (`hourly_volume`):** Extracts hour components using `HOUR(time)` and ranks hourly volume with `DENSE_RANK() OVER (ORDER BY COUNT(*) DESC)`.
  * **Main Query:** Categorizes transaction rows into `'Peak Hour'` vs. `'Off-Peak'` via a join on transaction hour and calculates `ROUND(AVG(response_time_ms), 2)` to quantify peak traffic latency degradation.

---

### **Q9. Network Latency & Status Distribution (Median & Average)**
* **Objective:** Determine how network types (5G, 4G, 3G, WiFi) affect response times across both successful and failed transactions, computing both average and exact median latency.
* **SQL Highlights:**
  * Employs window functions `ROW_NUMBER() OVER (...)` and `COUNT(*) OVER (...)` partitioned by `(network_type, status)` to determine rank order.
  * Calculates the true mathematical median by interpolating middle rows (`FLOOR` and `CEIL` boundaries), preventing skew from extreme network lag spikes.

---

### **Q10. Retry Behavior & Root-Cause Attribution**
* **Objective:** Analyze user retry behavior to discover which failure categories prompt customers to re-attempt payments.
* **SQL Highlights:**
  * Filters specifically for records where `retry_attempted = 'Yes'`.
  * Computes relative proportion percentages across failure reasons against the total retry population using a scoped subquery.

---

### **Q11. City-Level Payment App Rankings**
* **Objective:** Rank payment applications within each city based on cumulative transaction value (INR).
* **SQL Highlights:**
  * Evaluates multi-level groups: `GROUP BY payment_app, city`.
  * Applies the window ranking function `DENSE_RANK() OVER (PARTITION BY city ORDER BY SUM(amount_inr) DESC)` to produce localized competitive rankings.

---

### **Q12. High-Failure Inter-Bank Corridors**
* **Objective:** Identify high-friction sender-to-receiver bank settlement routes that frequently fail under real-world conditions.
* **SQL Highlights:**
  * Groups by the composite bank corridor `(sender_bank, receiver_bank)`.
  * Applies a statistical significance filter using `HAVING COUNT(*) >= 30` to exclude low-sample noise.
  * Ranks the top 5 corridors with the highest failure rates.

---

### **Q13. 7-Day Rolling Average Failure Trend**
* **Objective:** Smooth daily failure volatility into a rolling 7-day trendline to observe time-series degradation or improvement.
* **SQL Highlights:**
  * **CTE (`daily_failures`):** Aggregates daily failure counts by `date`.
  * **Window Framing:** Uses `AVG(daily_failure_count) OVER (ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)` to generate a 7-day trailing moving average.

---

### **Q14. Transaction Size Segmentation vs. Performance**
* **Objective:** Classify transactions into distinct monetary brackets to see if high-value transactions encounter elevated failure rates or longer authorization times.
* **SQL Highlights:**
  * Segments values into 5 buckets (`< ₹100`, `₹100–₹500`, `₹501–₹2,000`, `₹2,001–₹5,000`, `> ₹5,000`) using non-overlapping inequality logic.
  * Computes total volume, failure rate, and mean response latency per bucket.
  * Implements custom sort order using a `CASE` expression in the `ORDER BY` clause.

---

### **Q16. Latency Outlier Detection via Statistical Dispersion**
* **Objective:** Detect abnormal system delays exceeding 2 standard deviations ($\mu + 2\sigma$) above the mean for each specific transaction category.
* **SQL Highlights:**
  * Calculates category-level baseline statistics using window functions:
    - $\mu = 	ext{avg\_latency} = 	ext{AVG}(response\_time\_ms) 	ext{ OVER (PARTITION BY } category	ext{)}$
    - $\sigma = 	ext{std\_latency} = 	ext{STDDEV}(response\_time\_ms) 	ext{ OVER (PARTITION BY } category	ext{)}$
  * Flags each row dynamically as `'Outlier'` or `'Normal'` using conditional threshold logic.

---

## 🚀 How to Run This Project Locally

1. **Clone the Repository:**
   ```bash
   git clone https://github.com/harshsaini628000-cell/upi-transaction-analysis.git
cd upi-transaction-analysis
   ```

2. **Database Setup & Data Import (MySQL):**
   ```sql
   CREATE DATABASE tb9;
   USE tb9;
   ```
   * Import the dataset `upi_failed_transactions_dataset.csv` into table `upi_transactions` via MySQL Workbench Import Wizard or Python.

3. **Execute Analysis Script:**
   * Open and execute `failed_transactions_2.sql` to reproduce all outputs.
