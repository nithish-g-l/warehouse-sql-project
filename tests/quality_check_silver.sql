/*
====================================================================
Data Quality Validation Checks
====================================================================

Purpose:
    This script performs a series of data quality validation checks on
    the Silver layer to ensure data accuracy, consistency, and
    integrity before it is used for reporting and analytics.

Validation Checks:
    - Detects null or duplicate primary keys.
    - Identifies leading and trailing whitespace in text fields.
    - Verifies data standardization and consistency.
    - Validates date values and chronological order.
    - Checks consistency across related columns and business rules.

Usage:
    - Execute after loading data into the Silver layer.
    - Review and resolve any data quality issues identified by the checks.

====================================================================
*/

-- silver.crm_cust_info checks
--Check For Nulls and Duplicates in Primary Key
--Expectation : No Result 

SELECT cst_id, COUNT(*)
FROM silver.crm_cust_info
GROUP BY  cst_id
HAVING COUNT(*) >1 or cst_id IS NULL;

--Check For Unwanted Spaces
--Expectation: No Results

SELECT cst_firstname
FROM silver.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname);

SELECT cst_lastname
FROM silver.crm_cust_info
WHERE cst_lastname != TRIM(cst_lastname);

SELECT cst_gndr
FROM silver.crm_cust_info
WHERE cst_gndr != TRIM(cst_gndr);

--Data Standardization & Consistency
SELECT DISTINCT cst_gndr
FROM silver.crm_cust_info;

SELECT DISTINCT cst_marital_status
FROM silver.crm_cust_info;
/*==========================================================*/
--silver.crm_prd_info Checks
--Check For Nulls and Duplicates in Primary Key
--Expectation : No Result 
--broze
SELECT prd_id, COUNT(*)
FROM bronze.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL;

--Silver
SELECT prd_id, COUNT(*)
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL;

--Check For Unwanted Spaces
--Expectation: No Results
SELECT prd_nm
FROM  bronze.crm_prd_info
WHERE prd_nm != TRIM(prd_nm);

SELECT prd_nm
FROM  silver.crm_prd_info
WHERE prd_nm != TRIM(prd_nm);

--Check for NULL's and Negative Numbers
--Expectation: No Results
SELECT prd_cost
FROM  bronze.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL;

SELECT prd_cost
FROM  silver.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL;

--Data Standardization & Consistency
SELECT DISTINCT prd_line
FROM bronze.crm_prd_info;

SELECT DISTINCT prd_line
FROM silver.crm_prd_info;

--Check For Invalid Date Orders
SELECT *
FROM bronze.crm_prd_info
WHERE prd_end_dt < prd_start_dt;

SELECT *
FROM silver.crm_prd_info
WHERE prd_end_dt < prd_start_dt;

/*==========================================================*/
-- silver.crm_sales_details checks
--Check for Invalid dates
SELECT sls_order_dt
FROM bronze.crm_sales_details
WHERE sls_order_dt <= 0 
OR LEN(sls_order_dt) != 8
OR sls_order_dt > 20500101
OR sls_order_dt < 19000101;

--Check Data Consistency: Between Sales, Qunatity and Price
-- Sales = quantity * Price
-- Values must not be null, zero or negative

SELECT 
sls_sales,
sls_quantity,
sls_price
FROM bronze.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0
ORDER BY sls_sales,  sls_quantity, sls_price;

/*==========================================================*/
--silver.erp_cust_az12 checks
--Identify Out-of-Range date

SELECT DISTINCT bdate
FROM bronze.erp_cust_az12
WHERE bdate < '1924-01-01' OR bdate > GETDATE();

--Data standardization and Consistency
SELECT DISTINCT gen
FROM bronze.erp_cust_az12;

/*==========================================================*/
--sales.erp_loc_a101 checks
--Data  Standardization & Consistency
SELECT DISTINCT cntry
FROM bronze.erp_loc_a101
ORDER BY cntry;

/*==========================================================*/
silver.erp_px_cat_g1v2
-- Check for unwanted spaces
SELECT *
FROM bronze.erp_px_cat_g1v2
WHERE cat != TRIM(cat) OR subcat != TRIM(subcat) OR maintenance != TRIM(maintenance);



