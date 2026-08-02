/*Creating DataBase and Schemas*/

/* 
Script Purpose:
This script creates the 'DataWarehouse' database if it does not already exist. If an existing database with the same name is 
found, it is dropped and recreated to ensure a clean environment. The script also initializes the required schemas: 'bronze', 
'silver', and 'gold', which represent the different layers of the data warehouse architecture.
*/

USE master;
GO

  -- Drop and recreate the 'datawarehouse' database
  IF EXISTS (SELECT 1 
              FROM sys.databases 
              WHERE name='DataWarehouse'
  )
  BEGIN 
    ALTER DATABASE DataWarehouse 
    SET SINGLE_USER 
    WITH ROLLBACK IMMEDIATE;
END;
GO

  --Creating database 
CREATE DATABASE DataWarehouse;

USE DataWarehouse;

--Creating Warehouse
CREATE SCHEMA bronze;
GO
CREATE SCHEMA silver;
GO
CREATE SCHEMA gold;
GO
