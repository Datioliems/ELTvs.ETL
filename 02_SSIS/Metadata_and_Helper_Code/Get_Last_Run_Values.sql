/*
  SSIS helper for Sakila_DW incremental variables.
  Review the target database before execution.
*/

USE Sakila_DW;
GO

IF SCHEMA_ID(N'dw') IS NULL
    EXEC(N'CREATE SCHEMA dw');
GO

IF OBJECT_ID(N'dw.ETL_Log', N'U') IS NULL
BEGIN
    CREATE TABLE dw.ETL_Log
    (
        table_name sysname NOT NULL
            CONSTRAINT PK_ETL_Log PRIMARY KEY,
        last_run datetime2(0) NOT NULL
            CONSTRAINT DF_ETL_Log_last_run DEFAULT ('2000-01-01')
    );
END;
GO

MERGE dw.ETL_Log AS target
USING (VALUES
    (N'Dim_Customer'),
    (N'Dim_Product'),
    (N'Dim_Staff'),
    (N'Dim_Geography_Store'),
    (N'Fact_Sale'),
    (N'Dim_Date')
) AS source(table_name)
ON target.table_name = source.table_name
WHEN NOT MATCHED THEN
    INSERT (table_name, last_run)
    VALUES (source.table_name, CONVERT(datetime2(0), '2000-01-01'));
GO

/* Query used by the SSIS Execute SQL Task. */
SELECT table_name, last_run
FROM dw.ETL_Log
ORDER BY table_name;
GO

/* Mapping expected by the Script Task. */
SELECT
    table_name,
    last_run,
    CASE table_name
        WHEN N'Dim_Customer'        THEN N'User::LastRun_Customer'
        WHEN N'Dim_Product'         THEN N'User::LastRun_Product'
        WHEN N'Dim_Staff'           THEN N'User::LastRun_Staff'
        WHEN N'Dim_Geography_Store' THEN N'User::LastRun_Store'
        WHEN N'Fact_Sale'           THEN N'User::LastRun_FactSale'
        WHEN N'Dim_Date'            THEN N'(no dedicated LastRun variable)'
    END AS ssis_variable
FROM dw.ETL_Log
ORDER BY table_name;
GO

/*
  The package updates last_run after a successful load using CurrentRunTime.
  Keep this statement disabled for inspection-only use.

DECLARE @CurrentRunTime datetime2(0) = SYSDATETIME();

UPDATE dw.ETL_Log
SET last_run = @CurrentRunTime
WHERE table_name IN
(
    N'Dim_Customer', N'Dim_Product', N'Dim_Staff',
    N'Dim_Geography_Store', N'Fact_Sale', N'Dim_Date'
);
*/
