# Sakila Data Warehouse — FINALE

Thư mục này là bản tổng hợp dự án Sakila Data Warehouse theo hai hướng triển khai:

- **ETL:** các CSDL nghiệp vụ → SSIS → `Sakila_DW`.
- **ELT:** các CSDL nghiệp vụ → Airbyte → các schema `raw_*` trong `DW_AIRBYTE` → dbt → schema `dw`.

Bản tổng hợp được tạo ngày **27/06/2026** bằng cách **sao chép**, không di chuyển hoặc xóa dữ liệu gốc.

## Cấu trúc thư mục

```text
FINALE/
├── 01_SQL/
│   ├── 01_Sakila_Original/       # Schema và dữ liệu Sakila gốc
│   ├── 02_Phan_He/               # CRM, HRM, Sales, Inventory và script chia 4 phân hệ
│   ├── 03_DW_Schema_ETL/         # Tạo DW, nạp dimension/fact, aggregate, test và bản SSIS-ready
│   ├── 04_Stored_Procedures/      # Stored procedure ETL
│   ├── 05_Report_Queries/         # Truy vấn báo cáo/kiểm tra
│   └── 06_Database_Backup/        # sakila_dw.bak
├── 02_SSIS/
│   ├── Sakila_DW_Optimized/      # Bản sao dự án SSIS được chỉ định
│   └── Metadata_and_Helper_Code/ # Biến, SQL, code Script Task và bản SSIS đã làm sạch để chia sẻ
├── 03_AIRBYTE/
│   ├── airbyte_home_snapshot/    # Snapshot nội dung C:\Users\ADMIN\.airbyte
│   └── README_AIRBYTE.md
├── 04_DBT/
│   ├── sakila_dw_project/        # Dự án dbt, target và log; không gồm .venv
│   └── user_dbt_config/          # profiles.yml và log cấu hình người dùng
├── 05_REPORT/
│   └── Nhom9.THI.docx
└── 99_INVENTORY/
    ├── SOURCE_MAP.md
    └── MANIFEST_SHA256.csv
```

## Thứ tự sử dụng đề xuất

### 1. Chuẩn bị dữ liệu nguồn

Chọn **một** bộ Sakila phù hợp, không chạy tất cả các bản trùng nhau:

1. MySQL: dùng `01_SQL/01_Sakila_Original/mysql-sakila-schema.sql`, sau đó `mysql-sakila-insert-data.sql`.
2. Các biến thể đối chiếu nằm trong `mysql-sakila-db/` và các file `sakila_origin_*`.
3. Tạo/chia các phân hệ CRM, HRM, Sales, Inventory bằng file đúng hệ quản trị trong `01_SQL/02_Phan_He/`.

Tên file có `mysql`, `SQLserver` hoặc tên thư mục `DB_mySQL`, `DB_SQLserver` cho biết hệ quản trị mục tiêu. Không chạy script của MySQL trực tiếp trong SQL Server và ngược lại.

### 2A. Chạy nhánh ETL bằng SSIS

1. Mở `02_SSIS/Sakila_DW_Optimized/Sakila_DW.slnx` bằng Visual Studio có extension **SQL Server Integration Services Projects**.
2. Kiểm tra lại 5 connection manager trong thư mục dự án:
   - `CM_SS_DW` → SQL Server database `Sakila_DW`.
   - `CM_SS_HRM` → SQL Server database `Sakila_HRM`.
   - `CM_SS_Sales` → SQL Server database `Sakila_Sales`.
   - `MySQL_CRM_ODBC` → DSN `CRM_ODBC`.
   - `MySQL_Inventory_ODBC` → DSN `MySQL_Inventory_ODBC`.
3. `Project.params` hiện không khai báo project parameter; các giá trị incremental nằm trong package variables.
4. Chuẩn bị bảng `dw.ETL_Log` và kiểm tra giá trị incremental bằng `02_SSIS/Metadata_and_Helper_Code/Get_Last_Run_Values.sql`.
5. Chạy package chính `Sakila_DW/Package.dtsx`. Bản build sẵn nằm tại `Sakila_DW/bin/Development/Sakila_DW.ispac`.

Các file `Package.dtsx` và `Sakila_DW.dtproj` nguyên bản chỉ có trong bản lưu cục bộ vì chúng chứa cấu hình kết nối. GitHub chỉ chứa bản đã thay server/database/DSN/password bằng placeholder tại `02_SSIS/Metadata_and_Helper_Code/Public_Sanitized/`.

Các script dựng DW, nạp dimension/fact và stored procedure nằm trong `01_SQL/03_DW_Schema_ETL/` và `01_SQL/04_Stored_Procedures/`. Nên thử trên database test trước khi chạy script cleanup, truncate hoặc full-load.

### 2B. Chạy nhánh ELT bằng Airbyte + dbt

Airbyte đổ dữ liệu vào database `DW_AIRBYTE` theo các schema mà `models/sources.yml` đang tham chiếu:

- `raw_crm`: customer, address, city, country.
- `raw_hrm`: staff, store, address, city, country.
- `raw_sales`: rental, payment.
- `raw_mysql_inventory`: film, inventory, actor, film_actor, film_category, category, language.

Snapshot Airbyte là dữ liệu vận hành của `abctl`, gồm metadata PostgreSQL, kubeconfig và log job. Xem hướng dẫn/cảnh báo tại `03_AIRBYTE/README_AIRBYTE.md`.

Với dbt:

1. Kiểm tra `04_DBT/user_dbt_config/profiles.yml`, đặc biệt server, database, tài khoản và mật khẩu.
2. Chép/cập nhật file này vào `%USERPROFILE%\.dbt\profiles.yml` nếu phục hồi trên máy khác.
3. Tạo lại môi trường Python vì `.venv` không được sao lưu:

```powershell
py -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install dbt-core dbt-sqlserver
```

4. Từ `04_DBT/sakila_dw_project`, chạy:

```powershell
dbt debug
dbt run --select staging.*
dbt run --select marts.*
dbt test
dbt docs generate
dbt docs serve
```

Log lịch sử ghi nhận `dbt 1.11.11`, adapter `sqlserver 1.9.1`, 12 models và 18 sources. Các lần chạy thành công lẫn log xử lý lỗi cũ đều được giữ lại để đối chiếu.

## Biến incremental trong SSIS

| Biến | Kiểu | Giá trị/biểu thức ban đầu | Vai trò |
|---|---:|---|---|
| `User::CurrentRunTime` | DateTime | `(DT_DBTIMESTAMP) GETDATE()` | Mốc thời gian kết thúc lượt chạy |
| `User::LastRunObject` | Object | Result set từ `dw.ETL_Log` | Chứa toàn bộ `table_name`, `last_run` |
| `User::LastRun_Customer` | DateTime | `2000-01-01` | Incremental cho customer |
| `User::LastRun_FactSale` | DateTime | `2000-01-01` | Incremental cho fact sale |
| `User::LastRun_Product` | DateTime | `2000-01-01` | Incremental cho product |
| `User::LastRun_Staff` | DateTime | `2000-01-01` | Incremental cho staff |
| `User::LastRun_Staff1` | DateTime | `2000-01-01` | Biến staff bổ sung; chưa thấy được Script Task ghi |
| `User::LastRun_Store` | DateTime | `2000-01-01` | Incremental cho store |
| `User::NoMatchCount` | Int32 | `0` | Đếm bản ghi không match |
| `User::Variable` | Int32 | `0` | Biến chung/đang để mặc định |

Package chạy câu lệnh:

```sql
SELECT table_name, last_run
FROM dw.ETL_Log
ORDER BY table_name;
```

Kết quả được đưa vào `User::LastRunObject`, sau đó Script Task ghi sang các biến `LastRun_*`. Mã nguồn VSTA gốc không tồn tại dưới dạng file `.cs` riêng trong thư mục dự án; file `ScriptMain_LastRunVariables.cs` là bản tái dựng có chú thích để tham khảo hoặc dán lại vào Script Task.

## Log và artifact đã giữ

- SSIS: `obj/Development/BuildLog.xml`, package build trong `obj`, và `bin/Development/Sakila_DW.ispac`.
- Airbyte: toàn bộ `job-logging` và metadata database trong snapshot `.airbyte`.
- dbt: `logs/dbt.log`, `target/manifest.json`, `run_results.json`, compiled SQL và trang docs `target/index.html`.
- SSMS/SQL Server: các script `.sql` và backup `sakila_dw.bak`; không tìm thấy solution `.ssmssln` riêng.

## Cảnh báo bảo mật

`03_AIRBYTE/airbyte_home_snapshot`, các file `.conmgr`, `abctl.kubeconfig` và `04_DBT/user_dbt_config/profiles.yml` có thể chứa thông tin kết nối hoặc chứng thư. **Không đưa toàn bộ FINALE lên GitHub/public drive trước khi xóa hoặc thay thế secret.**

## Ghi chú về sao lưu và GitHub

- `D:\sakila_dw\.venv` bị loại vì chỉ là môi trường Python có thể tái tạo và không chứa model dbt của dự án.
- Hai file cache `.vsidx` ban đầu bị Visual Studio khóa đã được bổ sung sau khi ứng dụng đóng. Thư mục `.vs` vẫn được `.gitignore` loại khỏi GitHub vì chỉ là trạng thái IDE có thể tái tạo.
- Snapshot Airbyte, cấu hình dbt người dùng, connection manager/parameter/package/project SSIS nguyên bản, log và artifact build có khả năng chứa thông tin kết nối vẫn được giữ trong `D:\FINALE`, nhưng bị `.gitignore` loại khỏi GitHub. Bản SSIS đã làm sạch được cung cấp riêng để tham khảo mã nguồn.
- `99_INVENTORY/MANIFEST_SHA256.csv` là bản kiểm kê cục bộ, cũng không được đưa lên GitHub vì nó liệt kê đường dẫn và hash của các tệp nhạy cảm.
- Các bản gốc vẫn giữ nguyên tại vị trí cũ.

Danh sách nguồn chi tiết nằm trong `99_INVENTORY/SOURCE_MAP.md`; mã SHA-256 của toàn bộ tệp nằm trong `99_INVENTORY/MANIFEST_SHA256.csv`.
