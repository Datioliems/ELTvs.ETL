# SSIS public sanitized copies

Các file trong thư mục này được tạo từ dự án SSIS cục bộ nhưng đã thay giá trị connection string, server, database, DSN, username và password bằng placeholder.

- `Root_Package.sanitized.dtsx`: bản làm sạch của package ở thư mục solution.
- `Project_Package.sanitized.dtsx`: bản làm sạch của package chính trong project.
- `Sakila_DW.sanitized.dtproj`: bản làm sạch của project SSIS.

Để sử dụng, hãy sao chép/đổi tên về vị trí tương ứng rồi cấu hình lại connection manager trong Visual Studio. Không dùng placeholder để chạy trực tiếp.

Bản nguyên gốc có cấu hình thật vẫn được lưu cục bộ trong `D:\FINALE\02_SSIS\Sakila_DW_Optimized` và bị `.gitignore` loại khỏi GitHub.
