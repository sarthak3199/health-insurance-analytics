#1- Create Database
create database health_insurance;

#2- Use Database
use health_insurance;

select * from insurer_clean;
select * from hospital_clean;
select * from customer_clean;
select * from renewal_clean;
select * from claims_clean;
select * from overseas_clean;
select * from policy_clean;

#3- describe tables
DESCRIBE insurer_clean;
DESCRIBE hospital_clean;
DESCRIBE customer_clean;
DESCRIBE renewal_clean;
DESCRIBE policy_clean;
DESCRIBE overseas_clean;
DESCRIBE claims_clean;

#4- Correcting Data types

#4.1- INSURER TABLE
ALTER TABLE insurer_clean
MODIFY INSURER_ID VARCHAR(20) NOT NULL,
MODIFY Insurer VARCHAR(100);

ALTER TABLE insurer_clean
ADD PRIMARY KEY (INSURER_ID);

#4.2- HOSPITAL TABLE
ALTER TABLE hospital_clean
MODIFY Hospital_ID VARCHAR(20) NOT NULL,
MODIFY Hospital_Name VARCHAR(150);

ALTER TABLE hospital_clean
ADD PRIMARY KEY (Hospital_ID);

#4.3- CUSTOMER TABLE
ALTER TABLE customer_clean
MODIFY Customer_ID VARCHAR(20) NOT NULL,
MODIFY Age INT,
MODIFY City VARCHAR(50),
MODIFY Gender VARCHAR(10),
MODIFY Occupation VARCHAR(50),
MODIFY Annual_Income DECIMAL(12,2),
MODIFY Smoking_Status VARCHAR(20),
MODIFY Pre_Existing_Disease VARCHAR(10),
MODIFY Customer_Segment VARCHAR(30);

ALTER TABLE customer_clean
ADD PRIMARY KEY (Customer_ID);

#4.4- POLICY TABLE
    
 ALTER TABLE policy_clean
MODIFY Policy_Number VARCHAR(20) NOT NULL,
MODIFY Customer_ID VARCHAR(20),
MODIFY Insurer_ID VARCHAR(20),
MODIFY Policy_Type VARCHAR(50),
MODIFY Premium_Amount DECIMAL(12,2),
MODIFY Start_Date DATE,
MODIFY End_Date DATE,
MODIFY Sum_Insured DECIMAL(15,2),
MODIFY Plan_Name VARCHAR(100),
MODIFY No_Claim_Year VARCHAR(5),
MODIFY NCB_Percentage DECIMAL(5,2),
MODIFY NCB_Amount DECIMAL(12,2),
MODIFY Is_TopUp_Policy VARCHAR(5),
MODIFY Linked_Base_Policy VARCHAR(20),
MODIFY TopUp_Deductible DECIMAL(12,2),
MODIFY TopUp_Coverage DECIMAL(15,2);

ALTER TABLE policy_clean
ADD PRIMARY KEY (Policy_Number);

#4.5- CLAIMS TABLE

ALTER TABLE claims_clean
MODIFY Claim_ID VARCHAR(20) NOT NULL,
MODIFY Policy_Number VARCHAR(20),
MODIFY Hospital_ID VARCHAR(20),
MODIFY Claim_Date DATE,
MODIFY Claim_Amount_Requested DECIMAL(12,2),
MODIFY Claim_Amount_Approved DECIMAL(12,2),
MODIFY Claim_Status VARCHAR(20),
MODIFY Processing_Days INT;
ALTER TABLE claims_clean
ADD PRIMARY KEY (Claim_ID);

#4.6- OVERSEAS TABLE

ALTER TABLE overseas_clean
MODIFY Overseas_ID VARCHAR(20) NOT NULL,
MODIFY Policy_Number VARCHAR(20),
MODIFY Travel_Country VARCHAR(50),
MODIFY Visa_Type VARCHAR(30),
MODIFY Travel_Start_Date DATE,
MODIFY Travel_End_Date DATE,
MODIFY Overseas_Coverage_Amount DECIMAL(15,2),
MODIFY Currency VARCHAR(10),
MODIFY Pre_Travel_Medical_Required VARCHAR(5);
ALTER TABLE overseas_clean
ADD PRIMARY KEY (Overseas_ID);

#4.7- RENEWAL TABLE

ALTER TABLE renewal_clean
MODIFY Renewal_ID VARCHAR(20) NOT NULL,
MODIFY Policy_Number VARCHAR(20),
MODIFY Renewal_Due_Date DATE,
MODIFY Renewal_Status VARCHAR(20),
MODIFY Renewal_Amount DECIMAL(12,2),
MODIFY Last_Contacted_Date DATE,
MODIFY Pending_Days INT,
MODIFY Renewal_Channel VARCHAR(30);

ALTER TABLE renewal_clean
ADD PRIMARY KEY (Renewal_ID);



#5- CREATE FOREIGN KEYS (Data Modeling)

SHOW TABLES;

ALTER TABLE policy_clean
ADD FOREIGN KEY (Customer_ID) REFERENCES customer_clean(Customer_ID),
ADD FOREIGN KEY (Insurer_ID) REFERENCES insurer_clean(INSURER_ID);

ALTER TABLE claims_clean
ADD FOREIGN KEY (Policy_Number) REFERENCES policy_clean(Policy_Number),
ADD FOREIGN KEY (Hospital_ID) REFERENCES hospital_clean(Hospital_ID);

ALTER TABLE renewal_clean
ADD FOREIGN KEY (Policy_Number) REFERENCES policy_clean(Policy_Number);

ALTER TABLE overseas_clean
ADD FOREIGN KEY (Policy_Number) REFERENCES policy_clean(Policy_Number);

#6- High Premium Concentration by Policy Type
SELECT 
    Policy_Type,
    COUNT(*) AS total_policies,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 
        2
    ) AS policy_type_pct
FROM policy_clean
GROUP BY Policy_Type
ORDER BY total_policies DESC;

#7- High-Value Premium Policies (Above Average)
SELECT Policy_Number, Premium_Amount
FROM policy_clean
WHERE Premium_Amount > (
    SELECT AVG(Premium_Amount) FROM policy_clean
)
ORDER BY Premium_Amount DESC;

#8- Revenue Exposure by Insurer
SELECT 
    i.Insurer,
    ROUND(SUM(p.Premium_Amount), 2) AS total_premium,
    COUNT(DISTINCT p.Policy_Number) AS total_policies
FROM policy_clean p
JOIN insurer_clean i 
    ON p.Insurer_ID = i.INSURER_ID
GROUP BY i.Insurer
ORDER BY total_premium DESC;

#9- Bottleneck Identification – High Claim Delay
SELECT 
    Claim_Status,
    COUNT(*) AS total_claims,
    ROUND(AVG(Processing_Days), 2) AS avg_processing_days
FROM claims_clean
WHERE Processing_Days > 10
GROUP BY Claim_Status;

#10- Top 5 Cities by Claim Risk (Window Function)
SELECT *
FROM (
    SELECT 
        c.City,
        ROUND(SUM(cl.Claim_Amount_Approved), 2) AS total_claim_amount,
        RANK() OVER (ORDER BY SUM(cl.Claim_Amount_Approved) DESC) AS risk_rank
    FROM claims_clean cl
    JOIN policy_clean p 
        ON cl.Policy_Number = p.Policy_Number
    JOIN customer_clean c 
        ON p.Customer_ID = c.Customer_ID
    GROUP BY c.City
) t
WHERE risk_rank <= 5;

#11- Worker-Type Equivalent → Top 5 High Claim Customers
SELECT *
FROM (
    SELECT 
        c.Customer_ID,
        ROUND(SUM(cl.Claim_Amount_Approved), 2) AS total_claims,
        DENSE_RANK() OVER (ORDER BY SUM(cl.Claim_Amount_Approved) DESC) AS rnk
    FROM claims_clean cl
    JOIN policy_clean p 
        ON cl.Policy_Number = p.Policy_Number
    JOIN customer_clean c 
        ON p.Customer_ID = c.Customer_ID
    GROUP BY c.Customer_ID
) t
WHERE rnk <= 5;

#12- Customer Premium Efficiency Score
SELECT *
FROM (
    SELECT 
        c.Customer_ID,
        ROUND(
            SUM(cl.Claim_Amount_Approved) / SUM(p.Premium_Amount), 
        2) AS claim_to_premium_ratio,
        RANK() OVER (
            ORDER BY SUM(cl.Claim_Amount_Approved) / SUM(p.Premium_Amount) DESC
        ) AS risk_rank
    FROM customer_clean c
    JOIN policy_clean p 
        ON c.Customer_ID = p.Customer_ID
    JOIN claims_clean cl 
        ON p.Policy_Number = cl.Policy_Number
    GROUP BY c.Customer_ID
) t
WHERE risk_rank <= 5;

#13- Monthly Premium Trend (CTE)
WITH monthly_premium AS (
    SELECT 
        DATE_FORMAT(Start_Date, '%Y-%m') AS month,
        SUM(Premium_Amount) AS total_premium
    FROM policy_clean
    GROUP BY DATE_FORMAT(Start_Date, '%Y-%m')
)

SELECT 
    month,
    total_premium,
    LAG(total_premium) OVER (ORDER BY month) AS previous_month,
    ROUND(
        (total_premium - LAG(total_premium) OVER (ORDER BY month)) 
        / LAG(total_premium) OVER (ORDER BY month) * 100,
    2) AS mom_growth
FROM monthly_premium;

#14- Renewal Risk Segmentation
SELECT 
    Renewal_Channel,
    COUNT(*) AS total_renewals,
    SUM(CASE WHEN Renewal_Status = 'Not Renewed' THEN 1 ELSE 0 END) AS churn_count,
    ROUND(
        SUM(CASE WHEN Renewal_Status = 'Not Renewed' THEN 1 ELSE 0 END) 
        * 100.0 / COUNT(*),
    2) AS churn_rate_pct
FROM renewal_clean
GROUP BY Renewal_Channel;

#15 - Overseas Coverage Exposure by Country
SELECT 
    Travel_Country,
    ROUND(SUM(Overseas_Coverage_Amount), 2) AS total_coverage,
    RANK() OVER (ORDER BY SUM(Overseas_Coverage_Amount) DESC) AS coverage_rank
FROM overseas_clean
GROUP BY Travel_Country;

#16- Analytics View 

 CREATE VIEW vw_claim_risk_analysis AS
SELECT 
    cl.Claim_ID,
    c.Customer_ID,
    c.City,
    p.Policy_Type,
    cl.Claim_Amount_Approved,
    cl.Processing_Days
FROM claims_clean cl
JOIN policy_clean p 
    ON cl.Policy_Number = p.Policy_Number
JOIN customer_clean c 
    ON p.Customer_ID = c.Customer_ID;
    
    SELECT *
FROM vw_claim_risk_analysis
WHERE Processing_Days > 15;

#17- Rolling 3-Month Premium Trend (Window Function)
SELECT 
    DATE_FORMAT(Start_Date, '%Y-%m') AS Month,
    SUM(Premium_Amount) AS Monthly_Premium,
    SUM(SUM(Premium_Amount)) OVER (
        ORDER BY DATE_FORMAT(Start_Date, '%Y-%m')
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS Rolling_3_Month_Total
FROM policy_clean
GROUP BY Month;

#18- City-wise Premium Collection
SELECT c.City,
       SUM(f.Premium_Amount) AS Total_Premium
FROM policy_clean f
JOIN customer_clean c
ON f.Customer_ID = c.Customer_ID
GROUP BY c.City
ORDER BY Total_Premium DESC;