# Snapshot Airbyte

Thư mục `airbyte_home_snapshot` là bản sao nội dung của `C:\Users\ADMIN\.airbyte` tại thời điểm Docker Desktop không chạy.

Nó bao gồm:

- cấu hình `abctl` và kubeconfig;
- Helm cache;
- PostgreSQL data directory chứa metadata Airbyte;
- log check/discover/sync của connector MSSQL và MySQL;
- log workload/replication.

Đây là **snapshot dữ liệu vận hành**, không phải export cấu hình dạng khai báo có thể nhập vào mọi phiên bản Airbyte. Khi phục hồi, nên dùng cùng phiên bản `abctl`/Airbyte, sao lưu trạng thái hiện tại trước, dừng Airbyte hoàn toàn rồi mới thay thế dữ liệu. Không chép đè vào một instance đang chạy.

Snapshot có thể chứa password, token, certificate hoặc thông tin kết nối. Không commit thư mục này vào kho mã công khai.

dbt xác nhận đích ELT là SQL Server database `DW_AIRBYTE` với các schema `raw_crm`, `raw_hrm`, `raw_sales` và `raw_mysql_inventory`.
