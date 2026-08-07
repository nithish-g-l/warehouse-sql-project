/*
--------------------------------------------------------------------------------
Quality Checks
--------------------------------------------------------------------------------

Script Purpose:
This script performs data quality validation after loading the Silver layer. 
The checks are designed to ensure data accuracy, consistency, and integrity by:

- Verifying surrogate keys in dimension tables.
- Identifying duplicate records across fact and dimension tables.
- Validating relationships and referential integrity within the data model.
- Ensuring the data is reliable and ready for reporting and analytical use.

Usage Notes:
- Execute these checks after the Silver layer data load is complete.
- Review and resolve any validation failures before proceeding to the Gold layer.
--------------------------------------------------------------------------------
*/

-- Check if any duplicates are created after joining
SELECT cst_id, Count(*) FROM
(
SELECT
	ci.cst_id,
	ci.cst_key,
	ci.cst_firstname,
	ci.cst_lastname,
	ci.cst_marital_status,
	ci.cst_gndr,
	ci.cst_create_date,
	ca.bdate,
	ca.gen,
	la.cntry
FROM silver.crm_cust_info AS ci LEFT JOIN silver.erp_cust_az12 AS ca
ON ci.cst_key = ca.cid LEFT JOIN silver.erp_loc_a101 la
ON ci.cst_key = la.cid) AS t
GROUP BY cst_id
HAVING COUNT(*) > 1;

--CHeck fot gender in ca and ci table matches
SELECT DISTINCT
	ci.cst_gndr,
	ca.gen
FROM silver.crm_cust_info AS ci LEFT JOIN silver.erp_cust_az12 AS ca
ON ci.cst_key = ca.cid LEFT JOIN silver.erp_loc_a101 la
ON ci.cst_key = la.cid
ORDER BY 1,2


SELECT DISTINCT
	ci.cst_gndr,
	ca.gen,
	CASE WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr  -- CRM is the master for gender info
	ELSE COALESCE(ca.gen, 'n/a')
	END AS new_gen
FROM silver.crm_cust_info AS ci LEFT JOIN silver.erp_cust_az12 AS ca
ON ci.cst_key = ca.cid LEFT JOIN silver.erp_loc_a101 la
ON ci.cst_key = la.cid
ORDER BY 1,2

--Check if any duplicatees are created after joing products
SELECT prd_key, COUNT(*) FROM
(
SELECT 
	pn.prd_id,
	pn.prd_key,
	pn.prd_nm,
	pn.prd_cost,
	pn.prd_line,
	pn.prd_start_dt,
	pc.cat,
	pc.subcat,
	pc.maintenance
FROM silver.crm_prd_info AS pn LEFT JOIN silver.erp_px_cat_g1v2 AS pc
ON pn.cat_id = pc.id
WHERE prd_end_dt IS NULL) AS t
GROUP BY prd_key
HAVING COUNT(*) > 1;

--Foreign Key Integrity (Dimension)
SELECT * 
FROM gold.fact_sales AS f LEFT JOIN gold.dim_customers AS c
ON c.customer_key = f.customer_key LEFT JOIN gold.dim_products AS p
ON p.product_key = f.product_key
WHERE p.product_key IS NULL;

SELECT * 
FROM gold.fact_sales AS f  LEFT JOIN gold.dim_products AS p
ON p.product_key = f.product_key
WHERE p.product_key IS NULL;
