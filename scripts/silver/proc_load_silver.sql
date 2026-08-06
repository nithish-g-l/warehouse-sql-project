/*
====================================================================
Stored Procedure: Load Silver Layer (Bronze → Silver)
====================================================================

Purpose:
    This stored procedure loads data from the Bronze layer into the
    Silver layer by applying data cleansing, validation, and
    transformation rules. It ensures that the Silver tables contain
    clean, consistent, and standardized data for downstream processing.

Operations Performed:
    - Truncates the existing Silver tables.
    - Extracts data from the Bronze layer.
    - Cleanses and transforms the data.
    - Loads the processed data into the Silver tables.
    - Captures execution time and reports any errors encountered.

Parameters:
    None.

Returns:
    This stored procedure does not accept any input parameters and
    does not return any values.

Example:
    EXEC silver.load_silver;

====================================================================
*/

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
	DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME;
BEGIN TRY
	
	-- Inserting Data into silver.crm_cust_info
	SET @batch_start_time = GETDATE();
    PRINT '--------------------------';
    PRINT 'Loading Silver Layer';
    PRINT '--------------------------';

    PRINT '==========================';
    PRINT 'Loading CRM Table'
    PRINT '==========================';

    SET @start_time = GETDATE();
	PRINT '>>Truncating Table: silver.crm_cust_info';
	TRUNCATE TABLE silver.crm_cust_info;

	PRINT '>>Inserting Data Into: silver.crm_cust_info';
	INSERT INTO silver.crm_cust_info(
			cst_id,
			cst_key,
			cst_firstname,
			cst_lastname,
			cst_marital_status,
			cst_gndr,
			cst_create_date
	)

	SELECT 
	cst_id,
	cst_key,
	TRIM(cst_firstname) AS cst_firstname,
	TRIM(cst_lastname) AS cst_lastname,

	CASE
		WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
		WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
		ELSE 'n/a'
	END AS cst_marital_status, --Normalize marital status values to readable format
	CASE WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
				  WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
				  ELSE 'n/a'
				  END AS cst_gndr, --Normalize gender to values to readable format
	cst_create_date
	FROM(
	SELECT *, ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC) as  flag_last
	FROM bronze.crm_cust_info
	WHERE cst_id IS NOT NULL) AS T
	WHERE flag_last = 1;--Select the most recent record per customer
	SET @end_time = GETDATE();
    PRINT '>>LOAD DIFFERENCE: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
	--SELECT * FROM silver.crm_cust_info;

	-- Inserting Data into silver.crm_prd_info 
	SET @start_time = GETDATE();
    PRINT '>>Truncating Table: silver.crm_prd_info';
	TRUNCATE TABLE silver.crm_prd_info;

	PRINT '>>Inserting Data Into: silver.crm_prd_info';
	INSERT INTO silver.crm_prd_info(
			prd_id,
			cat_id,
			prd_key,
			prd_nm,
			prd_cost,
			prd_line,
			prd_start_dt,
			prd_end_dt
	)

	SELECT prd_id,
	REPLACE(SUBSTRING(prd_key,1,5), '-','_') AS cat_id, -- Extracted category ID as cat_id from prd_key (Derived Column)
	SUBSTRING(prd_key,7,LEN(prd_key)) AS prd_key,		-- Extracted category ID as prd_key from prd_key (Derived Column)
	prd_nm,
	ISNULL(prd_cost,0) AS prd_cost, --Null values to 0
	CASE
		 WHEN UPPER(TRIM(prd_line)) = 'M' THEN 'MOUNTAIN'
		 WHEN UPPER(TRIM(prd_line)) = 'R' THEN 'Road'
		 WHEN UPPER(TRIM(prd_line)) = 'S' THEN 'Other sales'
		 WHEN UPPER(TRIM(prd_line)) = 'T' THEN 'Touring'
		 ELSE 'n/a'

	END AS prd_line, --Map product line codes to descriptive values (Data Normalization)
	CAST(prd_start_dt AS DATE) AS prd_start_dt, --(Data type casting)
	CAST(LEAD(prd_start_dt) OVER(PARTITION BY prd_key ORDER BY prd_start_dt) - 1 AS DATE) AS prd_end_dt --Calculate end date as  one day before  the next start date (Data enrichment - producing new values)
	FROM bronze.crm_prd_info;
	 SET @end_time = GETDATE();
    PRINT '>>LOAD DIFFERENCE: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';

	--SELECT * 
	--FROM silver.crm_prd_info;

	-- Inserting Data into silver.crm_sales_details
	SET @start_time = GETDATE();
    PRINT '>>Truncating Table: silver.crm_sales_details';
	TRUNCATE TABLE silver.crm_sales_details;

	PRINT '>>Inserting Data Into: silver.crm_sales_details';
	INSERT INTO silver.crm_sales_details(
		sls_ord_num,
		sls_prd_key,
		sls_cust_id,
		sls_order_dt,
		sls_ship_dt,
		sls_due_dt,
		sls_sales,
		sls_quantity,
		sls_price
	)


	SELECT 
	sls_ord_num,
	sls_prd_key,
	sls_cust_id,
	CASE WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
		 ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
	END AS sls_order_dt,
	CASE WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL
		 ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
	END AS sls_ship_dt,
	CASE WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL
		 ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
	END AS sls_due_dt,

	CASE WHEN sls_sales IS NULL OR sls_sales <=0 OR sls_sales != sls_quantity * ABS(sls_price)
		 THEN sls_quantity * ABS(sls_price)
		 ELSE sls_sales
	END AS sls_sales,
	sls_quantity,
	CASE WHEN sls_price is NULL OR sls_price <=0 
		 THEN sls_sales / NULLIF(sls_quantity,0)
		 ELSE sls_price
	END AS sls_price
	FROM bronze.crm_sales_details;
	    SET @end_time = GETDATE();
    PRINT '>>LOAD DIFFERENCE: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
	--SELECT *
	--FROM silver.crm_sales_details;

	PRINT '==========================';
    PRINT 'Loading ERP Table'
    PRINT '==========================';


	-- Inserting data into silver.erp_cust_az12
	SET @start_time = GETDATE();
    PRINT '>>Truncating Table: silver.erp_cust_az12';
	TRUNCATE TABLE silver.erp_cust_az12;

	PRINT '>>Inserting Data Into: silver.erp_cust_az12';
	INSERT INTO silver.erp_cust_az12(
		cid,
		bdate,
		gen)

	SELECT
	CASE 
		WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid,4,LEN(cid))  -- Remove 'NAS' prefix if present
		ELSE cid
	END AS cid,
	CASE 
		WHEN bdate > GETDATE() THEN NULL 
		ELSE bdate
	END AS bdate, -- Set Future Bday to NULl
	CASE WHEN UPPER(TRIM(gen)) IN ('F','FEMALE') THEN 'Female'
		 WHEN UPPER(TRIM(gen)) IN ('M','MALE') THEN 'MALE'
		 ELSE 'n/a'
	END AS gen -- Normalize gender values and handle unkown cases
	FROM bronze.erp_cust_az12;
	SET @end_time = GETDATE();
    PRINT '>>LOAD DIFFERENCE: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';

	-- Inserting data into silver.erp_loc_a101

	SET @start_time = GETDATE();
    PRINT '>>Truncating Table: silver.erp_loc_a101';
	TRUNCATE TABLE silver.erp_loc_a101;
	INSERT INTO silver.erp_loc_a101(cid,cntry)

	SELECT
	REPLACE(cid, '-','')cid,
	CASE WHEN TRIM(cntry) =  'DE' THEN 'Germany'
		 WHEN TRIM(cntry) IN ('US','USA') THEN 'United States'
		 WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
		 ELSE TRIM(cntry)
	END As cntry -- Normalize and handle missing or blank conuntry codes
	FROM  bronze.erp_loc_a101;
	SET @end_time = GETDATE();
    PRINT '>>LOAD DIFFERENCE: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';

	-- SELECT * FROM silver.erp_loc_a101;

	--Inserting data into silver.erp_px_cat_g1v2

	SET @start_time = GETDATE();
    PRINT '>>Truncating Table: silver.erp_px_cat_g1v2';
	TRUNCATE TABLE silver.erp_px_cat_g1v2;

	PRINT '>>Inserting Data Into: silver.erp_px_cat_g1v2';
	INSERT INTO silver.erp_px_cat_g1v2(
		id,
		cat,
		subcat,
		maintenance
	)

	SELECT id
		,cat
		,subcat
		,maintenance
	FROM bronze.erp_px_cat_g1v2;
	SET @end_time = GETDATE();
    PRINT '>>LOAD DIFFERENCE: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';

	-- SELECT * FROM silver.erp_px_cat_g1v2;

	PRINT ' --------------------'
    SET @batch_end_time = GETDATE();
    PRINT ' -Total Load Duration: ' + CAST(DATEDIFF(second, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
    END TRY
    BEGIN CATCH
        PRINT '========================';
        PRINT 'ERROR OCCURED DURING LOADING SILVER LAYER';
        PRINT 'ERROR MESSAGE' + CAST(ERROR_MESSAGE() AS NVARCHAR);
        PRINT 'ERROR MESSAGE' + CAST(ERROR_STATE() AS NVARCHAR);
        PRINT '========================';
    END CATCH
END
