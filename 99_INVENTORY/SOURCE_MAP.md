# Bản đồ nguồn của FINALE

| Nội dung đích | Nguồn chính |
|---|---|
| `01_SQL/01_Sakila_Original` | `D:\2026.DW\2026.KHODULIEU\mysql-sakila-*`, `sakila_origin_*` và `D:\2026.DW\sakila-database\mysql-sakila-db` |
| `01_SQL/02_Phan_He/Current_Root_SQL` | Các file `sakila_crm`, `sakila_hrm`, `sakila_inventory`, `sakila_sales`, `crm_sql_server` tại `D:\2026.DW` |
| `01_SQL/02_Phan_He/phan_he` | `D:\2026.DW\2026.KHODULIEU\Sakila_4_PhanHe_FINAL\phan_he` |
| `01_SQL/02_Phan_He/DB_mySQL`, `DB_SQLserver` | `D:\2026.DW\Finale_kho` |
| `01_SQL/03_DW_Schema_ETL/Root_Final_SQL` | Script schema, Dim_Date, aggregate, sửa lỗi và test tại `D:\2026.DW` |
| `01_SQL/03_DW_Schema_ETL/etl_sakila_dw` | `D:\2026.DW\2026.KHODULIEU\etl_sakila_dw` |
| `01_SQL/03_DW_Schema_ETL/etl_sakila_dw_ssis` | `D:\2026.DW\2026.KHODULIEU\etl_sakila_dw_SSIS_READY\etl_sakila_dw_ssis` |
| `01_SQL/03_DW_Schema_ETL/DWH_Variants` | Các file `sakila_dwh*.sql` trong `D:\2026.DW\2026.KHODULIEU` |
| `01_SQL/04_Stored_Procedures` | `etl_sakila_StoredProc_FINAL\etl_sakila_sp` và `SSDT\etl_fixed` |
| `01_SQL/05_Report_Queries` | Truy vấn Câu 3/Câu 4, aggregate, insert fact và `TKCSDL.sql` |
| `01_SQL/06_Database_Backup/sakila_dw.bak` | `D:\2026.DW\sakila_dw.bak` |
| `02_SSIS/Sakila_DW_Optimized` | `D:\2026.DW\Sakila_DW_opti\Sakila_DW - Copy` |
| `03_AIRBYTE/airbyte_home_snapshot` | Nội dung `C:\Users\ADMIN\.airbyte` khi Docker Desktop đang dừng |
| `04_DBT/sakila_dw_project` | `D:\sakila_dw`, loại trừ `.venv` |
| `04_DBT/user_dbt_config` | `C:\Users\ADMIN\.dbt` |
| `05_REPORT/Nhom9.THI.docx` | `D:\2026.DW\Nhom9.THI.docx` |

Lưu ý: một số SQL có nhiều phiên bản hoặc bản sao với hậu tố như `(1)`, `Final`, `sau_final`. Chúng được giữ để tránh mất lịch sử; README chỉ định nhóm file nên ưu tiên, không khẳng định mọi biến thể đều chạy nối tiếp nhau.
