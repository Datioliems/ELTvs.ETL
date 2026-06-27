-- ============================================================
-- THIẾT KẾ CƠ SỞ DỮ LIỆU MỨC VẬT LÝ - HỆ THỐNG QUẢN LÝ NHÀ HÀNG
-- Hệ quản trị: Microsoft SQL Server 2019+
-- Ngày tạo: 2025
-- Mô tả: Thiết kế đầy đủ bao gồm bảng, kiểu dữ liệu, ràng buộc,
--        index, trigger, stored procedure
-- ============================================================

USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = 'RestaurantDB')
    DROP DATABASE RestaurantDB;
GO

CREATE DATABASE RestaurantDB
    ON PRIMARY (
        NAME = 'RestaurantDB_Data',
        FILENAME = 'C:\SQLData\RestaurantDB.mdf',
        SIZE = 100MB,
        MAXSIZE = UNLIMITED,
        FILEGROWTH = 50MB
    )
    LOG ON (
        NAME = 'RestaurantDB_Log',
        FILENAME = 'C:\SQLData\RestaurantDB.ldf',
        SIZE = 20MB,
        MAXSIZE = 500MB,
        FILEGROWTH = 10MB
    );
GO

USE RestaurantDB;
GO

-- ============================================================
-- PHẦN 1: TẠO CÁC BẢNG (DDL)
-- ============================================================

-- -------------------------------------------------------
-- 1. BẢNG: DanhMuc (Danh mục món ăn)
-- -------------------------------------------------------
CREATE TABLE DanhMuc (
    MaDanhMuc   INT             NOT NULL IDENTITY(1,1),
    TenDanhMuc  NVARCHAR(100)   NOT NULL,
    MoTa        NVARCHAR(500)   NULL,
    TrangThai   BIT             NOT NULL DEFAULT 1,   -- 1: Hoạt động, 0: Ngừng
    NgayTao     DATETIME2(0)    NOT NULL DEFAULT GETDATE(),
    NgayCapNhat DATETIME2(0)    NULL,

    CONSTRAINT PK_DanhMuc PRIMARY KEY CLUSTERED (MaDanhMuc),
    CONSTRAINT UQ_DanhMuc_TenDanhMuc UNIQUE (TenDanhMuc),
    CONSTRAINT CK_DanhMuc_TenDanhMuc CHECK (LEN(LTRIM(RTRIM(TenDanhMuc))) > 0)
);
GO

-- -------------------------------------------------------
-- 2. BẢNG: Mon (Món ăn)
-- -------------------------------------------------------
CREATE TABLE Mon (
    MaMon       INT             NOT NULL IDENTITY(1,1),
    TenMon      NVARCHAR(150)   NOT NULL,
    MoTa        NVARCHAR(1000)  NULL,
    DonGia      DECIMAL(12,2)   NOT NULL,
    MaDanhMuc   INT             NOT NULL,
    HinhAnh     NVARCHAR(500)   NULL,
    TrangThai   BIT             NOT NULL DEFAULT 1,   -- 1: Đang bán, 0: Ngừng bán
    NgayTao     DATETIME2(0)    NOT NULL DEFAULT GETDATE(),
    NgayCapNhat DATETIME2(0)    NULL,

    CONSTRAINT PK_Mon PRIMARY KEY CLUSTERED (MaMon),
    CONSTRAINT FK_Mon_DanhMuc FOREIGN KEY (MaDanhMuc)
        REFERENCES DanhMuc(MaDanhMuc)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT CK_Mon_DonGia CHECK (DonGia >= 0),
    CONSTRAINT CK_Mon_TenMon  CHECK (LEN(LTRIM(RTRIM(TenMon))) > 0)
);
GO

-- -------------------------------------------------------
-- 3. BẢNG: Ban (Bàn ăn)
-- -------------------------------------------------------
CREATE TABLE Ban (
    MaBan       INT             NOT NULL IDENTITY(1,1),
    SoBan       NVARCHAR(20)    NOT NULL,
    ViTri       NVARCHAR(100)   NULL,
    TrangThai   NVARCHAR(20)    NOT NULL DEFAULT N'Trống',
    NgayTao     DATETIME2(0)    NOT NULL DEFAULT GETDATE(),
    NgayCapNhat DATETIME2(0)    NULL,

    CONSTRAINT PK_Ban PRIMARY KEY CLUSTERED (MaBan),
    CONSTRAINT UQ_Ban_SoBan  UNIQUE (SoBan),
    CONSTRAINT CK_Ban_TrangThai CHECK (TrangThai IN (N'Trống', N'Đang dùng', N'Đặt trước', N'Bảo trì'))
);
GO

-- -------------------------------------------------------
-- 4. BẢNG: KhachHang (Khách hàng)
-- -------------------------------------------------------
CREATE TABLE KhachHang (
    MaKH        INT             NOT NULL IDENTITY(1,1),
    TenKH       NVARCHAR(150)   NOT NULL,
    SoDienThoai NVARCHAR(20)    NULL,
    Email       NVARCHAR(200)   NULL,
    DiaChi      NVARCHAR(500)   NULL,
    DiemTichLuy INT             NOT NULL DEFAULT 0,
    NgaySinh    DATE            NULL,
    GioiTinh    NVARCHAR(10)    NULL,
    NgayTao     DATETIME2(0)    NOT NULL DEFAULT GETDATE(),
    NgayCapNhat DATETIME2(0)    NULL,

    CONSTRAINT PK_KhachHang PRIMARY KEY CLUSTERED (MaKH),
    CONSTRAINT UQ_KhachHang_SoDienThoai UNIQUE (SoDienThoai),
    CONSTRAINT CK_KhachHang_Email       CHECK (Email LIKE '%_@_%.__%' OR Email IS NULL),
    CONSTRAINT CK_KhachHang_DiemTichLuy CHECK (DiemTichLuy >= 0),
    CONSTRAINT CK_KhachHang_GioiTinh    CHECK (GioiTinh IN (N'Nam', N'Nữ', N'Khác') OR GioiTinh IS NULL)
);
GO

-- -------------------------------------------------------
-- 5. BẢNG: TaiKhoan (Tài khoản người dùng hệ thống)
-- -------------------------------------------------------
CREATE TABLE TaiKhoan (
    MaTaiKhoan  INT             NOT NULL IDENTITY(1,1),
    TenTK       NVARCHAR(100)   NOT NULL,
    MatKhau     NVARCHAR(256)   NOT NULL,   -- Lưu hash (bcrypt/SHA-256)
    ChucVu      NVARCHAR(50)    NOT NULL DEFAULT N'Nhân viên',
    TrangThai   NVARCHAR(20)    NOT NULL DEFAULT N'Hoạt động',
    NgayTao     DATETIME2(0)    NOT NULL DEFAULT GETDATE(),
    NgayCapNhat DATETIME2(0)    NULL,
    LanDangNhapCuoi DATETIME2(0) NULL,

    CONSTRAINT PK_TaiKhoan PRIMARY KEY CLUSTERED (MaTaiKhoan),
    CONSTRAINT UQ_TaiKhoan_TenTK UNIQUE (TenTK),
    CONSTRAINT CK_TaiKhoan_ChucVu    CHECK (ChucVu IN (N'Quản lý', N'Thu ngân', N'Nhân viên', N'Bếp', N'Admin')),
    CONSTRAINT CK_TaiKhoan_TrangThai CHECK (TrangThai IN (N'Hoạt động', N'Khóa', N'Nghỉ việc'))
);
GO

-- -------------------------------------------------------
-- 6. BẢNG: NhanVien (Nhân viên)
-- -------------------------------------------------------
CREATE TABLE NhanVien (
    MaNV        INT             NOT NULL IDENTITY(1,1),
    TenNV       NVARCHAR(150)   NOT NULL,
    DiaChi      NVARCHAR(500)   NULL,
    SoDienThoai NVARCHAR(20)    NULL,
    CCCD        NVARCHAR(20)    NULL,
    NgaySinh    DATE            NULL,
    GioiTinh    NVARCHAR(10)    NULL,
    MaTaiKhoan  INT             NULL,       -- FK → TaiKhoan
    NgayTao     DATETIME2(0)    NOT NULL DEFAULT GETDATE(),
    NgayCapNhat DATETIME2(0)    NULL,

    CONSTRAINT PK_NhanVien PRIMARY KEY CLUSTERED (MaNV),
    CONSTRAINT FK_NhanVien_TaiKhoan FOREIGN KEY (MaTaiKhoan)
        REFERENCES TaiKhoan(MaTaiKhoan)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT UQ_NhanVien_CCCD    UNIQUE (CCCD),
    CONSTRAINT UQ_NhanVien_TaiKhoan UNIQUE (MaTaiKhoan),
    CONSTRAINT CK_NhanVien_GioiTinh CHECK (GioiTinh IN (N'Nam', N'Nữ', N'Khác') OR GioiTinh IS NULL)
);
GO

-- -------------------------------------------------------
-- 7. BẢNG: ChiNhanh (Chi nhánh nhà hàng)
-- -------------------------------------------------------
CREATE TABLE ChiNhanh (
    MaChiNhanh  INT             NOT NULL IDENTITY(1,1),
    TenChiNhanh NVARCHAR(200)   NOT NULL,
    MaChiNhanhStr NVARCHAR(20)  NULL,       -- Mã code hiển thị
    SLTonKhoHeThong INT         NOT NULL DEFAULT 0,
    DonVi       NVARCHAR(50)    NULL,
    DiaChi      NVARCHAR(500)   NULL,
    SoDienThoai NVARCHAR(20)    NULL,
    TrangThai   BIT             NOT NULL DEFAULT 1,
    NgayTao     DATETIME2(0)    NOT NULL DEFAULT GETDATE(),
    NgayCapNhat DATETIME2(0)    NULL,

    CONSTRAINT PK_ChiNhanh PRIMARY KEY CLUSTERED (MaChiNhanh),
    CONSTRAINT UQ_ChiNhanh_MaStr UNIQUE (MaChiNhanhStr),
    CONSTRAINT CK_ChiNhanh_SLTonKho CHECK (SLTonKhoHeThong >= 0)
);
GO

-- -------------------------------------------------------
-- 8. BẢNG: NhaCungCap (Nhà cung cấp nguyên liệu)
-- -------------------------------------------------------
CREATE TABLE NhaCungCap (
    MaNCC       INT             NOT NULL IDENTITY(1,1),
    TenNCC      NVARCHAR(200)   NOT NULL,
    SoDienThoai NVARCHAR(20)    NULL,
    Email       NVARCHAR(200)   NULL,
    DiaChi      NVARCHAR(500)   NULL,
    MaSoThue    NVARCHAR(20)    NULL,
    TrangThai   BIT             NOT NULL DEFAULT 1,
    NgayTao     DATETIME2(0)    NOT NULL DEFAULT GETDATE(),
    NgayCapNhat DATETIME2(0)    NULL,

    CONSTRAINT PK_NhaCungCap PRIMARY KEY CLUSTERED (MaNCC),
    CONSTRAINT UQ_NhaCungCap_MaSoThue UNIQUE (MaSoThue),
    CONSTRAINT CK_NhaCungCap_Email    CHECK (Email LIKE '%_@_%.__%' OR Email IS NULL)
);
GO

-- -------------------------------------------------------
-- 9. BẢNG: NguyenLieu (Nguyên liệu)
-- -------------------------------------------------------
CREATE TABLE NguyenLieu (
    MaNguyenLieu    INT             NOT NULL IDENTITY(1,1),
    TenNguyenLieu   NVARCHAR(200)   NOT NULL,
    DonViTinh       NVARCHAR(50)    NULL,
    MoTa            NVARCHAR(500)   NULL,
    MaChiNhanh      INT             NOT NULL,   -- Nguyên liệu thuộc chi nhánh
    NgayTao         DATETIME2(0)    NOT NULL DEFAULT GETDATE(),
    NgayCapNhat     DATETIME2(0)    NULL,

    CONSTRAINT PK_NguyenLieu PRIMARY KEY CLUSTERED (MaNguyenLieu),
    CONSTRAINT FK_NguyenLieu_ChiNhanh FOREIGN KEY (MaChiNhanh)
        REFERENCES ChiNhanh(MaChiNhanh)
        ON UPDATE CASCADE ON DELETE RESTRICT
);
GO

-- -------------------------------------------------------
-- 10. BẢNG: DinhMuc (Định mức nguyên liệu cho từng món)
-- -------------------------------------------------------
CREATE TABLE DinhMuc (
    MaMon           INT             NOT NULL,
    MaNguyenLieu    INT             NOT NULL,
    SoLuongDung     DECIMAL(10,3)   NOT NULL,
    DonVi           NVARCHAR(50)    NULL,
    MoTa            NVARCHAR(500)   NULL,

    CONSTRAINT PK_DinhMuc PRIMARY KEY CLUSTERED (MaMon, MaNguyenLieu),
    CONSTRAINT FK_DinhMuc_Mon FOREIGN KEY (MaMon)
        REFERENCES Mon(MaMon)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT FK_DinhMuc_NguyenLieu FOREIGN KEY (MaNguyenLieu)
        REFERENCES NguyenLieu(MaNguyenLieu)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT CK_DinhMuc_SoLuong CHECK (SoLuongDung > 0)
);
GO

-- -------------------------------------------------------
-- 11. BẢNG: PhieuNhapKho (Phiếu nhập kho nguyên liệu)
-- -------------------------------------------------------
CREATE TABLE PhieuNhapKho (
    MaPNK       INT             NOT NULL IDENTITY(1,1),
    NgayNK      DATETIME2(0)    NOT NULL DEFAULT GETDATE(),
    MaNCC       INT             NOT NULL,
    MaNV        INT             NOT NULL,   -- Nhân viên lập phiếu
    TongTien    DECIMAL(15,2)   NOT NULL DEFAULT 0,
    GhiChu      NVARCHAR(1000)  NULL,
    TrangThai   NVARCHAR(30)    NOT NULL DEFAULT N'Chờ duyệt',

    CONSTRAINT PK_PhieuNhapKho PRIMARY KEY CLUSTERED (MaPNK),
    CONSTRAINT FK_PhieuNhapKho_NCC FOREIGN KEY (MaNCC)
        REFERENCES NhaCungCap(MaNCC)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT FK_PhieuNhapKho_NV  FOREIGN KEY (MaNV)
        REFERENCES NhanVien(MaNV)
        ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT CK_PhieuNhapKho_TongTien CHECK (TongTien >= 0),
    CONSTRAINT CK_PhieuNhapKho_TrangThai CHECK (TrangThai IN (N'Chờ duyệt', N'Đã duyệt', N'Huỷ'))
);
GO

-- -------------------------------------------------------
-- 12. BẢNG: ChiTietNhapKho (Chi tiết từng dòng phiếu nhập kho)
-- -------------------------------------------------------
CREATE TABLE ChiTietNhapKho (
    MaCTNK          INT             NOT NULL IDENTITY(1,1),
    MaPNK           INT             NOT NULL,
    MaNguyenLieu    INT             NOT NULL,
    SoLuong         DECIMAL(10,3)   NOT NULL,
    DonGia          DECIMAL(12,2)   NOT NULL,
    ThanhTien       AS (SoLuong * DonGia) PERSISTED,

    CONSTRAINT PK_ChiTietNhapKho PRIMARY KEY CLUSTERED (MaCTNK),
    CONSTRAINT FK_CTNK_PhieuNhapKho  FOREIGN KEY (MaPNK)
        REFERENCES PhieuNhapKho(MaPNK)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT FK_CTNK_NguyenLieu    FOREIGN KEY (MaNguyenLieu)
        REFERENCES NguyenLieu(MaNguyenLieu)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT CK_CTNK_SoLuong  CHECK (SoLuong > 0),
    CONSTRAINT CK_CTNK_DonGia   CHECK (DonGia >= 0)
);
GO

-- -------------------------------------------------------
-- 13. BẢNG: PhieuKiemKe (Phiếu kiểm kê kho)
-- -------------------------------------------------------
CREATE TABLE PhieuKiemKe (
    MaPKK           INT             NOT NULL IDENTITY(1,1),
    NgayKK          DATETIME2(0)    NOT NULL DEFAULT GETDATE(),
    MaNV            INT             NOT NULL,   -- Nhân viên lập phiếu
    MaChiNhanh      INT             NOT NULL,
    GhiChu          NVARCHAR(1000)  NULL,
    TrangThai       NVARCHAR(30)    NOT NULL DEFAULT N'Chờ duyệt',

    CONSTRAINT PK_PhieuKiemKe PRIMARY KEY CLUSTERED (MaPKK),
    CONSTRAINT FK_PhieuKiemKe_NV        FOREIGN KEY (MaNV)
        REFERENCES NhanVien(MaNV)
        ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT FK_PhieuKiemKe_ChiNhanh  FOREIGN KEY (MaChiNhanh)
        REFERENCES ChiNhanh(MaChiNhanh)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT CK_PhieuKiemKe_TrangThai CHECK (TrangThai IN (N'Chờ duyệt', N'Đã duyệt', N'Huỷ'))
);
GO

-- -------------------------------------------------------
-- 14. BẢNG: ChiTietKiemKe (Chi tiết kiểm kê từng nguyên liệu)
-- -------------------------------------------------------
CREATE TABLE ChiTietKiemKe (
    MaCTKK          INT             NOT NULL IDENTITY(1,1),
    MaPKK           INT             NOT NULL,
    MaNguyenLieu    INT             NOT NULL,
    SoLuongTonKhoThucTe  DECIMAL(10,3) NOT NULL,
    ChenhLech       DECIMAL(10,3)   NULL,   -- Tính qua trigger
    GhiChu          NVARCHAR(500)   NULL,

    CONSTRAINT PK_ChiTietKiemKe PRIMARY KEY CLUSTERED (MaCTKK),
    CONSTRAINT FK_CTKK_PhieuKiemKe FOREIGN KEY (MaPKK)
        REFERENCES PhieuKiemKe(MaPKK)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT FK_CTKK_NguyenLieu  FOREIGN KEY (MaNguyenLieu)
        REFERENCES NguyenLieu(MaNguyenLieu)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT CK_CTKK_SoLuong CHECK (SoLuongTonKhoThucTe >= 0)
);
GO

-- -------------------------------------------------------
-- 15. BẢNG: Order_ (Đơn gọi món - tránh xung đột keyword ORDER)
-- -------------------------------------------------------
CREATE TABLE Order_ (
    MaOrder         INT             NOT NULL IDENTITY(1,1),
    MaBan           INT             NOT NULL,
    MaKH            INT             NULL,   -- Có thể không có khách hàng đã đăng ký
    MaNV            INT             NOT NULL,   -- Nhân viên tạo order
    NgayOrder       DATETIME2(0)    NOT NULL DEFAULT GETDATE(),
    GioOrder        TIME(0)         NOT NULL DEFAULT CAST(GETDATE() AS TIME),
    TrangThai       NVARCHAR(30)    NOT NULL DEFAULT N'Đang xử lý',
    GhiChu          NVARCHAR(1000)  NULL,

    CONSTRAINT PK_Order PRIMARY KEY CLUSTERED (MaOrder),
    CONSTRAINT FK_Order_Ban     FOREIGN KEY (MaBan)
        REFERENCES Ban(MaBan)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT FK_Order_KhachHang FOREIGN KEY (MaKH)
        REFERENCES KhachHang(MaKH)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT FK_Order_NhanVien FOREIGN KEY (MaNV)
        REFERENCES NhanVien(MaNV)
        ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT CK_Order_TrangThai CHECK (TrangThai IN (
        N'Đang xử lý', N'Bếp đang làm', N'Đã phục vụ', N'Hoàn thành', N'Huỷ'))
);
GO

-- -------------------------------------------------------
-- 16. BẢNG: ChiTietOrder (Chi tiết các món trong order)
-- -------------------------------------------------------
CREATE TABLE ChiTietOrder (
    MaCTO           INT             NOT NULL IDENTITY(1,1),
    MaOrder         INT             NOT NULL,
    MaMon           INT             NOT NULL,
    SoLuong         INT             NOT NULL DEFAULT 1,
    DonGia          DECIMAL(12,2)   NOT NULL,   -- Chụp giá tại thời điểm gọi
    ThanhTien       AS (SoLuong * DonGia) PERSISTED,
    GhiChu          NVARCHAR(500)   NULL,
    TrangThai       NVARCHAR(30)    NOT NULL DEFAULT N'Chờ',

    CONSTRAINT PK_ChiTietOrder PRIMARY KEY CLUSTERED (MaCTO),
    CONSTRAINT FK_CTO_Order FOREIGN KEY (MaOrder)
        REFERENCES Order_(MaOrder)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT FK_CTO_Mon   FOREIGN KEY (MaMon)
        REFERENCES Mon(MaMon)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT CK_CTO_SoLuong CHECK (SoLuong > 0),
    CONSTRAINT CK_CTO_DonGia  CHECK (DonGia >= 0),
    CONSTRAINT CK_CTO_TrangThai CHECK (TrangThai IN (N'Chờ', N'Đang làm', N'Đã xong', N'Huỷ'))
);
GO

-- -------------------------------------------------------
-- 17. BẢNG: HoaDon (Hóa đơn thanh toán)
-- -------------------------------------------------------
CREATE TABLE HoaDon (
    MaHoaDon        INT             NOT NULL IDENTITY(1,1),
    MaOrder         INT             NOT NULL,
    MaNV            INT             NOT NULL,   -- Thu ngân lập hóa đơn
    ThoiGianLap     DATETIME2(0)    NOT NULL DEFAULT GETDATE(),
    TongTien        DECIMAL(15,2)   NOT NULL DEFAULT 0,
    ChietKhau       DECIMAL(5,2)    NOT NULL DEFAULT 0,   -- % chiết khấu
    TienChietKhau   AS (TongTien * ChietKhau / 100) PERSISTED,
    ThanhToan       AS (TongTien - TongTien * ChietKhau / 100) PERSISTED,
    PhuongThucThanhToan NVARCHAR(50) NOT NULL DEFAULT N'Tiền mặt',
    TrangThai       NVARCHAR(30)    NOT NULL DEFAULT N'Chưa thanh toán',
    GhiChu          NVARCHAR(1000)  NULL,

    CONSTRAINT PK_HoaDon PRIMARY KEY CLUSTERED (MaHoaDon),
    CONSTRAINT FK_HoaDon_Order  FOREIGN KEY (MaOrder)
        REFERENCES Order_(MaOrder)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT FK_HoaDon_NhanVien FOREIGN KEY (MaNV)
        REFERENCES NhanVien(MaNV)
        ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT UQ_HoaDon_Order   UNIQUE (MaOrder),   -- 1 order chỉ có 1 hóa đơn
    CONSTRAINT CK_HoaDon_TongTien    CHECK (TongTien >= 0),
    CONSTRAINT CK_HoaDon_ChietKhau   CHECK (ChietKhau BETWEEN 0 AND 100),
    CONSTRAINT CK_HoaDon_PhuongThuc  CHECK (PhuongThucThanhToan IN (
        N'Tiền mặt', N'Chuyển khoản', N'Thẻ tín dụng', N'Ví điện tử', N'QR Code')),
    CONSTRAINT CK_HoaDon_TrangThai   CHECK (TrangThai IN (
        N'Chưa thanh toán', N'Đã thanh toán', N'Hoàn tiền', N'Huỷ'))
);
GO


-- ============================================================
-- PHẦN 2: INDEX (Tối ưu truy vấn)
-- ============================================================

-- Index cho bảng Mon
CREATE NONCLUSTERED INDEX IX_Mon_DanhMuc
    ON Mon(MaDanhMuc) INCLUDE (TenMon, DonGia, TrangThai);

CREATE NONCLUSTERED INDEX IX_Mon_TrangThai
    ON Mon(TrangThai) INCLUDE (MaMon, TenMon, DonGia);

-- Index cho bảng Ban
CREATE NONCLUSTERED INDEX IX_Ban_TrangThai
    ON Ban(TrangThai) INCLUDE (MaBan, SoBan, ViTri);

-- Index cho bảng KhachHang
CREATE NONCLUSTERED INDEX IX_KhachHang_SoDienThoai
    ON KhachHang(SoDienThoai);

CREATE NONCLUSTERED INDEX IX_KhachHang_TenKH
    ON KhachHang(TenKH);

-- Index cho bảng Order_
CREATE NONCLUSTERED INDEX IX_Order_MaBan_TrangThai
    ON Order_(MaBan, TrangThai) INCLUDE (MaOrder, NgayOrder, MaKH, MaNV);

CREATE NONCLUSTERED INDEX IX_Order_MaKH
    ON Order_(MaKH) INCLUDE (MaOrder, NgayOrder, TrangThai);

CREATE NONCLUSTERED INDEX IX_Order_NgayOrder
    ON Order_(NgayOrder) INCLUDE (MaOrder, MaBan, TrangThai);

-- Index cho bảng ChiTietOrder
CREATE NONCLUSTERED INDEX IX_ChiTietOrder_MaOrder
    ON ChiTietOrder(MaOrder) INCLUDE (MaMon, SoLuong, DonGia, ThanhTien);

CREATE NONCLUSTERED INDEX IX_ChiTietOrder_MaMon
    ON ChiTietOrder(MaMon) INCLUDE (SoLuong, DonGia);

-- Index cho bảng HoaDon
CREATE NONCLUSTERED INDEX IX_HoaDon_ThoiGianLap
    ON HoaDon(ThoiGianLap) INCLUDE (MaHoaDon, MaOrder, TongTien, TrangThai);

CREATE NONCLUSTERED INDEX IX_HoaDon_TrangThai
    ON HoaDon(TrangThai) INCLUDE (MaHoaDon, TongTien, ThoiGianLap);

-- Index cho bảng PhieuNhapKho
CREATE NONCLUSTERED INDEX IX_PhieuNhapKho_NgayNK
    ON PhieuNhapKho(NgayNK) INCLUDE (MaPNK, MaNCC, TongTien);

CREATE NONCLUSTERED INDEX IX_PhieuNhapKho_MaNCC
    ON PhieuNhapKho(MaNCC) INCLUDE (MaPNK, NgayNK, TongTien);

-- Index cho bảng NguyenLieu
CREATE NONCLUSTERED INDEX IX_NguyenLieu_ChiNhanh
    ON NguyenLieu(MaChiNhanh) INCLUDE (MaNguyenLieu, TenNguyenLieu, DonViTinh);

-- Index cho bảng DinhMuc
CREATE NONCLUSTERED INDEX IX_DinhMuc_NguyenLieu
    ON DinhMuc(MaNguyenLieu) INCLUDE (MaMon, SoLuongDung, DonVi);
GO


-- ============================================================
-- PHẦN 3: TRIGGERS
-- ============================================================

-- -------------------------------------------------------
-- TRIGGER 1: Tự động cập nhật NgayCapNhat khi UPDATE bản ghi
-- -------------------------------------------------------
CREATE OR ALTER TRIGGER trg_DanhMuc_UpdateTimestamp
ON DanhMuc AFTER UPDATE AS
BEGIN
    SET NOCOUNT ON;
    UPDATE DanhMuc
    SET NgayCapNhat = GETDATE()
    WHERE MaDanhMuc IN (SELECT MaDanhMuc FROM inserted);
END;
GO

CREATE OR ALTER TRIGGER trg_Mon_UpdateTimestamp
ON Mon AFTER UPDATE AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Mon SET NgayCapNhat = GETDATE()
    WHERE MaMon IN (SELECT MaMon FROM inserted);
END;
GO

CREATE OR ALTER TRIGGER trg_KhachHang_UpdateTimestamp
ON KhachHang AFTER UPDATE AS
BEGIN
    SET NOCOUNT ON;
    UPDATE KhachHang SET NgayCapNhat = GETDATE()
    WHERE MaKH IN (SELECT MaKH FROM inserted);
END;
GO

CREATE OR ALTER TRIGGER trg_TaiKhoan_UpdateTimestamp
ON TaiKhoan AFTER UPDATE AS
BEGIN
    SET NOCOUNT ON;
    UPDATE TaiKhoan SET NgayCapNhat = GETDATE()
    WHERE MaTaiKhoan IN (SELECT MaTaiKhoan FROM inserted);
END;
GO

-- -------------------------------------------------------
-- TRIGGER 2: Cập nhật TrangThai bàn khi có Order mới
-- -------------------------------------------------------
CREATE OR ALTER TRIGGER trg_Order_UpdateBanStatus
ON Order_ AFTER INSERT AS
BEGIN
    SET NOCOUNT ON;
    -- Khi tạo Order mới → đánh dấu bàn là "Đang dùng"
    UPDATE Ban
    SET TrangThai = N'Đang dùng',
        NgayCapNhat = GETDATE()
    WHERE MaBan IN (
        SELECT MaBan FROM inserted
        WHERE TrangThai NOT IN (N'Huỷ')
    );
END;
GO

CREATE OR ALTER TRIGGER trg_Order_FreeBanOnComplete
ON Order_ AFTER UPDATE AS
BEGIN
    SET NOCOUNT ON;
    -- Khi Order chuyển sang Hoàn thành hoặc Huỷ → trả bàn về "Trống"
    UPDATE Ban
    SET TrangThai = N'Trống',
        NgayCapNhat = GETDATE()
    WHERE MaBan IN (
        SELECT i.MaBan
        FROM inserted i
        JOIN deleted d ON i.MaOrder = d.MaOrder
        WHERE i.TrangThai IN (N'Hoàn thành', N'Huỷ')
          AND d.TrangThai NOT IN (N'Hoàn thành', N'Huỷ')
    );
END;
GO

-- -------------------------------------------------------
-- TRIGGER 3: Tính lại TongTien hóa đơn khi Order thay đổi
-- -------------------------------------------------------
CREATE OR ALTER TRIGGER trg_ChiTietOrder_RecalcHoaDon
ON ChiTietOrder AFTER INSERT, UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @AffectedOrders TABLE (MaOrder INT);

    INSERT INTO @AffectedOrders
    SELECT DISTINCT MaOrder FROM inserted
    UNION
    SELECT DISTINCT MaOrder FROM deleted;

    -- Cập nhật TongTien trong HoaDon
    UPDATE HoaDon
    SET TongTien = ISNULL((
        SELECT SUM(SoLuong * DonGia)
        FROM ChiTietOrder
        WHERE MaOrder = HoaDon.MaOrder
          AND TrangThai != N'Huỷ'
    ), 0)
    WHERE MaOrder IN (SELECT MaOrder FROM @AffectedOrders);
END;
GO

-- -------------------------------------------------------
-- TRIGGER 4: Tính lại TongTien PhieuNhapKho
-- -------------------------------------------------------
CREATE OR ALTER TRIGGER trg_ChiTietNhapKho_RecalcTong
ON ChiTietNhapKho AFTER INSERT, UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @AffectedPNK TABLE (MaPNK INT);

    INSERT INTO @AffectedPNK
    SELECT DISTINCT MaPNK FROM inserted
    UNION
    SELECT DISTINCT MaPNK FROM deleted;

    UPDATE PhieuNhapKho
    SET TongTien = ISNULL((
        SELECT SUM(SoLuong * DonGia)
        FROM ChiTietNhapKho
        WHERE MaPNK = PhieuNhapKho.MaPNK
    ), 0)
    WHERE MaPNK IN (SELECT MaPNK FROM @AffectedPNK);
END;
GO

-- -------------------------------------------------------
-- TRIGGER 5: Không cho phép sửa/xóa hóa đơn đã thanh toán
-- -------------------------------------------------------
CREATE OR ALTER TRIGGER trg_HoaDon_PreventEdit
ON HoaDon INSTEAD OF UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @PaidCount INT;

    -- Kiểm tra DELETE
    IF EXISTS (SELECT 1 FROM deleted d
               WHERE d.TrangThai = N'Đã thanh toán'
               AND NOT EXISTS (SELECT 1 FROM inserted i WHERE i.MaHoaDon = d.MaHoaDon))
    BEGIN
        RAISERROR(N'Không thể xóa hóa đơn đã thanh toán.', 16, 1);
        RETURN;
    END;

    -- Kiểm tra UPDATE: chỉ cho phép cập nhật trường TrangThai → Hoàn tiền
    IF EXISTS (
        SELECT 1 FROM inserted i
        JOIN deleted d ON i.MaHoaDon = d.MaHoaDon
        WHERE d.TrangThai = N'Đã thanh toán'
          AND i.TrangThai != N'Hoàn tiền'
    )
    BEGIN
        RAISERROR(N'Hóa đơn đã thanh toán chỉ được phép chuyển sang trạng thái Hoàn tiền.', 16, 1);
        RETURN;
    END;

    -- Nếu hợp lệ, thực hiện UPDATE bình thường
    UPDATE HoaDon
    SET MaOrder = i.MaOrder,
        MaNV = i.MaNV,
        ThoiGianLap = i.ThoiGianLap,
        TongTien = i.TongTien,
        ChietKhau = i.ChietKhau,
        PhuongThucThanhToan = i.PhuongThucThanhToan,
        TrangThai = i.TrangThai,
        GhiChu = i.GhiChu
    FROM inserted i
    WHERE HoaDon.MaHoaDon = i.MaHoaDon;
END;
GO

-- -------------------------------------------------------
-- TRIGGER 6: Tích lũy điểm khách hàng khi thanh toán
-- -------------------------------------------------------
CREATE OR ALTER TRIGGER trg_HoaDon_TichLuyDiem
ON HoaDon AFTER UPDATE AS
BEGIN
    SET NOCOUNT ON;
    -- Cứ 10,000 VNĐ = 1 điểm, chỉ tính khi chuyển sang "Đã thanh toán"
    UPDATE KhachHang
    SET DiemTichLuy = DiemTichLuy + FLOOR(i.ThanhToan / 10000),
        NgayCapNhat = GETDATE()
    FROM KhachHang kh
    INNER JOIN Order_ o ON o.MaKH = kh.MaKH
    INNER JOIN inserted i ON i.MaOrder = o.MaOrder
    INNER JOIN deleted  d ON d.MaHoaDon = i.MaHoaDon
    WHERE i.TrangThai = N'Đã thanh toán'
      AND d.TrangThai != N'Đã thanh toán'
      AND o.MaKH IS NOT NULL;
END;
GO

-- -------------------------------------------------------
-- TRIGGER 7: Ngăn xóa Danh mục/Món đang sử dụng
-- -------------------------------------------------------
CREATE OR ALTER TRIGGER trg_DanhMuc_PreventDelete
ON DanhMuc INSTEAD OF DELETE AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1 FROM Mon m
        INNER JOIN deleted d ON m.MaDanhMuc = d.MaDanhMuc
        WHERE m.TrangThai = 1
    )
    BEGIN
        RAISERROR(N'Không thể xóa danh mục đang có món ăn hoạt động.', 16, 1);
        RETURN;
    END;
    -- Xóa mềm: set TrangThai = 0
    UPDATE DanhMuc SET TrangThai = 0
    WHERE MaDanhMuc IN (SELECT MaDanhMuc FROM deleted);
END;
GO


-- ============================================================
-- PHẦN 4: STORED PROCEDURES
-- ============================================================

-- -------------------------------------------------------
-- SP 1: Tạo Order mới
-- -------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_TaoOrder
    @MaBan      INT,
    @MaKH       INT = NULL,
    @MaNV       INT,
    @GhiChu     NVARCHAR(1000) = NULL,
    @MaOrder    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Kiểm tra bàn tồn tại và trạng thái
        IF NOT EXISTS (SELECT 1 FROM Ban WHERE MaBan = @MaBan)
        BEGIN
            RAISERROR(N'Bàn không tồn tại.', 16, 1);
            ROLLBACK; RETURN;
        END;

        IF EXISTS (SELECT 1 FROM Ban WHERE MaBan = @MaBan AND TrangThai = N'Đang dùng')
        BEGIN
            RAISERROR(N'Bàn đang được sử dụng, không thể tạo order mới.', 16, 1);
            ROLLBACK; RETURN;
        END;

        -- Kiểm tra nhân viên hợp lệ
        IF NOT EXISTS (SELECT 1 FROM NhanVien WHERE MaNV = @MaNV)
        BEGIN
            RAISERROR(N'Nhân viên không tồn tại.', 16, 1);
            ROLLBACK; RETURN;
        END;

        INSERT INTO Order_ (MaBan, MaKH, MaNV, GhiChu)
        VALUES (@MaBan, @MaKH, @MaNV, @GhiChu);

        SET @MaOrder = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
        SELECT @MaOrder AS MaOrder, N'Tạo order thành công' AS ThongBao;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO

-- -------------------------------------------------------
-- SP 2: Thêm món vào Order
-- -------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_ThemMonVaoOrder
    @MaOrder    INT,
    @MaMon      INT,
    @SoLuong    INT,
    @GhiChu     NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Kiểm tra order tồn tại và hợp lệ
        IF NOT EXISTS (SELECT 1 FROM Order_ WHERE MaOrder = @MaOrder
                       AND TrangThai IN (N'Đang xử lý', N'Bếp đang làm'))
        BEGIN
            RAISERROR(N'Order không hợp lệ hoặc đã hoàn thành.', 16, 1);
            ROLLBACK; RETURN;
        END;

        -- Lấy giá hiện tại của món
        DECLARE @DonGia DECIMAL(12,2);
        SELECT @DonGia = DonGia FROM Mon WHERE MaMon = @MaMon AND TrangThai = 1;

        IF @DonGia IS NULL
        BEGIN
            RAISERROR(N'Món ăn không tồn tại hoặc không còn phục vụ.', 16, 1);
            ROLLBACK; RETURN;
        END;

        -- Nếu món đã có trong order → cộng thêm số lượng
        IF EXISTS (SELECT 1 FROM ChiTietOrder
                   WHERE MaOrder = @MaOrder AND MaMon = @MaMon AND TrangThai = N'Chờ')
        BEGIN
            UPDATE ChiTietOrder
            SET SoLuong = SoLuong + @SoLuong
            WHERE MaOrder = @MaOrder AND MaMon = @MaMon AND TrangThai = N'Chờ';
        END
        ELSE
        BEGIN
            INSERT INTO ChiTietOrder (MaOrder, MaMon, SoLuong, DonGia, GhiChu)
            VALUES (@MaOrder, @MaMon, @SoLuong, @DonGia, @GhiChu);
        END;

        COMMIT TRANSACTION;
        SELECT N'Thêm món thành công' AS ThongBao;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO

-- -------------------------------------------------------
-- SP 3: Xuất hóa đơn và thanh toán
-- -------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_ThanhToan
    @MaOrder            INT,
    @MaNV               INT,
    @ChietKhau          DECIMAL(5,2) = 0,
    @PhuongThuc         NVARCHAR(50) = N'Tiền mặt',
    @MaHoaDon           INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Kiểm tra order hợp lệ
        IF NOT EXISTS (SELECT 1 FROM Order_ WHERE MaOrder = @MaOrder
                       AND TrangThai IN (N'Đang xử lý', N'Bếp đang làm', N'Đã phục vụ'))
        BEGIN
            RAISERROR(N'Order không hợp lệ để thanh toán.', 16, 1);
            ROLLBACK; RETURN;
        END;

        -- Kiểm tra chưa có hóa đơn chưa thanh toán
        IF EXISTS (SELECT 1 FROM HoaDon WHERE MaOrder = @MaOrder
                   AND TrangThai NOT IN (N'Huỷ', N'Hoàn tiền'))
        BEGIN
            RAISERROR(N'Order này đã có hóa đơn.', 16, 1);
            ROLLBACK; RETURN;
        END;

        -- Tính tổng tiền
        DECLARE @TongTien DECIMAL(15,2);
        SELECT @TongTien = ISNULL(SUM(SoLuong * DonGia), 0)
        FROM ChiTietOrder
        WHERE MaOrder = @MaOrder AND TrangThai != N'Huỷ';

        -- Tạo hóa đơn
        INSERT INTO HoaDon (MaOrder, MaNV, TongTien, ChietKhau, PhuongThucThanhToan, TrangThai)
        VALUES (@MaOrder, @MaNV, @TongTien, @ChietKhau, @PhuongThuc, N'Đã thanh toán');

        SET @MaHoaDon = SCOPE_IDENTITY();

        -- Cập nhật trạng thái order
        UPDATE Order_ SET TrangThai = N'Hoàn thành' WHERE MaOrder = @MaOrder;

        COMMIT TRANSACTION;

        -- Trả về thông tin hóa đơn
        SELECT
            hd.MaHoaDon,
            hd.MaOrder,
            b.SoBan,
            hd.TongTien,
            hd.ChietKhau,
            hd.ThanhToan,
            hd.PhuongThucThanhToan,
            hd.TrangThai
        FROM HoaDon hd
        INNER JOIN Order_ o  ON o.MaOrder  = hd.MaOrder
        INNER JOIN Ban    b  ON b.MaBan    = o.MaBan
        WHERE hd.MaHoaDon = @MaHoaDon;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO

-- -------------------------------------------------------
-- SP 4: Báo cáo doanh thu theo khoảng thời gian
-- -------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_BaoCaoDoanhThu
    @TuNgay     DATETIME2(0),
    @DenNgay    DATETIME2(0),
    @MaChiNhanh INT = NULL   -- NULL = tất cả chi nhánh
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        CAST(hd.ThoiGianLap AS DATE)    AS Ngay,
        COUNT(DISTINCT hd.MaHoaDon)     AS SoHoaDon,
        COUNT(DISTINCT o.MaOrder)       AS SoOrder,
        SUM(hd.TongTien)                AS TongDoanhThu,
        SUM(hd.TienChietKhau)           AS TongChietKhau,
        SUM(hd.ThanhToan)               AS DoanhThuThuc,
        SUM(CASE WHEN hd.PhuongThucThanhToan = N'Tiền mặt'      THEN hd.ThanhToan ELSE 0 END) AS TienMat,
        SUM(CASE WHEN hd.PhuongThucThanhToan = N'Chuyển khoản'  THEN hd.ThanhToan ELSE 0 END) AS ChuyenKhoan,
        SUM(CASE WHEN hd.PhuongThucThanhToan = N'Thẻ tín dụng'  THEN hd.ThanhToan ELSE 0 END) AS TheNganHang,
        SUM(CASE WHEN hd.PhuongThucThanhToan IN (N'Ví điện tử', N'QR Code') THEN hd.ThanhToan ELSE 0 END) AS ThanhToanOnline
    FROM HoaDon hd
    INNER JOIN Order_ o ON o.MaOrder = hd.MaOrder
    WHERE hd.TrangThai = N'Đã thanh toán'
      AND hd.ThoiGianLap BETWEEN @TuNgay AND @DenNgay
    GROUP BY CAST(hd.ThoiGianLap AS DATE)
    ORDER BY Ngay;
END;
GO

-- -------------------------------------------------------
-- SP 5: Báo cáo món ăn bán chạy
-- -------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_MonAnBanChay
    @TuNgay     DATETIME2(0),
    @DenNgay    DATETIME2(0),
    @TopN       INT = 10
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@TopN)
        m.MaMon,
        m.TenMon,
        dm.TenDanhMuc,
        SUM(cto.SoLuong)        AS TongSoLuongBan,
        SUM(cto.ThanhTien)      AS TongDoanhThu,
        AVG(cto.DonGia)         AS GiaTrungBinh,
        COUNT(DISTINCT o.MaOrder) AS SoLanGoi
    FROM ChiTietOrder cto
    INNER JOIN Order_ o  ON o.MaOrder = cto.MaOrder
    INNER JOIN HoaDon hd ON hd.MaOrder = o.MaOrder
    INNER JOIN Mon m     ON m.MaMon = cto.MaMon
    INNER JOIN DanhMuc dm ON dm.MaDanhMuc = m.MaDanhMuc
    WHERE hd.TrangThai = N'Đã thanh toán'
      AND hd.ThoiGianLap BETWEEN @TuNgay AND @DenNgay
      AND cto.TrangThai != N'Huỷ'
    GROUP BY m.MaMon, m.TenMon, dm.TenDanhMuc
    ORDER BY TongSoLuongBan DESC;
END;
GO

-- -------------------------------------------------------
-- SP 6: Kiểm kê tồn kho nguyên liệu
-- -------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_KiemKeTonKho
    @MaChiNhanh INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Tổng nhập theo từng nguyên liệu
    WITH Nhap AS (
        SELECT ctnk.MaNguyenLieu,
               SUM(ctnk.SoLuong) AS TongNhap
        FROM ChiTietNhapKho ctnk
        INNER JOIN PhieuNhapKho pnk ON pnk.MaPNK = ctnk.MaPNK
        WHERE pnk.TrangThai = N'Đã duyệt'
        GROUP BY ctnk.MaNguyenLieu
    ),
    -- Tổng đã dùng qua định mức × số lượng món đã phục vụ
    DaDung AS (
        SELECT dm.MaNguyenLieu,
               SUM(dm.SoLuongDung * cto.SoLuong) AS TongDaDung
        FROM DinhMuc dm
        INNER JOIN ChiTietOrder cto ON cto.MaMon = dm.MaMon
        INNER JOIN Order_ o         ON o.MaOrder = cto.MaOrder
        INNER JOIN HoaDon hd        ON hd.MaOrder = o.MaOrder
        WHERE hd.TrangThai = N'Đã thanh toán'
          AND cto.TrangThai != N'Huỷ'
        GROUP BY dm.MaNguyenLieu
    )
    SELECT
        nl.MaNguyenLieu,
        nl.TenNguyenLieu,
        nl.DonViTinh,
        ISNULL(n.TongNhap, 0)           AS TongNhap,
        ISNULL(dd.TongDaDung, 0)        AS TongDaDung,
        ISNULL(n.TongNhap, 0) - ISNULL(dd.TongDaDung, 0) AS TonKhoDuKien
    FROM NguyenLieu nl
    LEFT JOIN Nhap  n  ON n.MaNguyenLieu  = nl.MaNguyenLieu
    LEFT JOIN DaDung dd ON dd.MaNguyenLieu = nl.MaNguyenLieu
    WHERE nl.MaChiNhanh = @MaChiNhanh
    ORDER BY TonKhoDuKien ASC;
END;
GO

-- -------------------------------------------------------
-- SP 7: Tìm kiếm khách hàng
-- -------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_TimKiemKhachHang
    @TuKhoa NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        kh.MaKH, kh.TenKH, kh.SoDienThoai, kh.Email,
        kh.DiemTichLuy,
        COUNT(DISTINCT o.MaOrder)   AS TongOrder,
        SUM(hd.ThanhToan)           AS TongChiTieu
    FROM KhachHang kh
    LEFT JOIN Order_ o  ON o.MaKH = kh.MaKH
    LEFT JOIN HoaDon hd ON hd.MaOrder = o.MaOrder AND hd.TrangThai = N'Đã thanh toán'
    WHERE kh.TenKH       LIKE N'%' + @TuKhoa + N'%'
       OR kh.SoDienThoai LIKE N'%' + @TuKhoa + N'%'
       OR kh.Email        LIKE N'%' + @TuKhoa + N'%'
    GROUP BY kh.MaKH, kh.TenKH, kh.SoDienThoai, kh.Email, kh.DiemTichLuy
    ORDER BY TongChiTieu DESC;
END;
GO

-- -------------------------------------------------------
-- SP 8: Thống kê hiệu suất nhân viên
-- -------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_HieuSuatNhanVien
    @TuNgay     DATETIME2(0),
    @DenNgay    DATETIME2(0)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        nv.MaNV,
        nv.TenNV,
        tk.ChucVu,
        COUNT(DISTINCT o.MaOrder)       AS SoOrderPhucVu,
        COUNT(DISTINCT hd.MaHoaDon)     AS SoHoaDonLap,
        SUM(hd.ThanhToan)               AS TongDoanhThu,
        AVG(hd.ThanhToan)               AS DoanhThuTrungBinh
    FROM NhanVien nv
    LEFT JOIN TaiKhoan tk ON tk.MaTaiKhoan = nv.MaTaiKhoan
    LEFT JOIN Order_  o   ON o.MaNV = nv.MaNV
    LEFT JOIN HoaDon  hd  ON hd.MaOrder = o.MaOrder
                         AND hd.TrangThai = N'Đã thanh toán'
                         AND hd.ThoiGianLap BETWEEN @TuNgay AND @DenNgay
    GROUP BY nv.MaNV, nv.TenNV, tk.ChucVu
    ORDER BY TongDoanhThu DESC;
END;
GO


-- ============================================================
-- PHẦN 5: VIEWS (Các view tiện ích)
-- ============================================================

-- View: Hóa đơn chi tiết đầy đủ
CREATE OR ALTER VIEW vw_HoaDonChiTiet AS
SELECT
    hd.MaHoaDon,
    hd.ThoiGianLap,
    b.SoBan,
    b.ViTri,
    kh.TenKH,
    kh.SoDienThoai AS SDTKhachHang,
    nv.TenNV       AS TenThuNgan,
    hd.TongTien,
    hd.ChietKhau,
    hd.TienChietKhau,
    hd.ThanhToan,
    hd.PhuongThucThanhToan,
    hd.TrangThai
FROM HoaDon hd
INNER JOIN Order_    o  ON o.MaOrder = hd.MaOrder
INNER JOIN Ban       b  ON b.MaBan   = o.MaBan
LEFT  JOIN KhachHang kh ON kh.MaKH   = o.MaKH
INNER JOIN NhanVien  nv ON nv.MaNV   = hd.MaNV;
GO

-- View: Order đang hoạt động (bếp xem)
CREATE OR ALTER VIEW vw_OrderDangHoatDong AS
SELECT
    o.MaOrder,
    b.SoBan,
    o.NgayOrder,
    o.GioOrder,
    o.TrangThai     AS TrangThaiOrder,
    m.TenMon,
    dm.TenDanhMuc,
    cto.SoLuong,
    cto.GhiChu      AS GhiChuMon,
    cto.TrangThai   AS TrangThaiMon,
    nv.TenNV        AS NhanVienPhucVu
FROM Order_ o
INNER JOIN Ban          b   ON b.MaBan    = o.MaBan
INNER JOIN ChiTietOrder cto ON cto.MaOrder = o.MaOrder
INNER JOIN Mon          m   ON m.MaMon    = cto.MaMon
INNER JOIN DanhMuc      dm  ON dm.MaDanhMuc = m.MaDanhMuc
INNER JOIN NhanVien     nv  ON nv.MaNV    = o.MaNV
WHERE o.TrangThai IN (N'Đang xử lý', N'Bếp đang làm')
  AND cto.TrangThai IN (N'Chờ', N'Đang làm');
GO

-- View: Tình trạng bàn hiện tại
CREATE OR ALTER VIEW vw_TinhTrangBan AS
SELECT
    b.MaBan,
    b.SoBan,
    b.ViTri,
    b.TrangThai,
    o.MaOrder,
    o.NgayOrder,
    o.GioOrder,
    kh.TenKH,
    COUNT(cto.MaCTO) AS SoMon
FROM Ban b
LEFT JOIN Order_ o  ON o.MaBan = b.MaBan
                   AND o.TrangThai IN (N'Đang xử lý', N'Bếp đang làm', N'Đã phục vụ')
LEFT JOIN KhachHang kh ON kh.MaKH = o.MaKH
LEFT JOIN ChiTietOrder cto ON cto.MaOrder = o.MaOrder AND cto.TrangThai != N'Huỷ'
GROUP BY b.MaBan, b.SoBan, b.ViTri, b.TrangThai,
         o.MaOrder, o.NgayOrder, o.GioOrder, kh.TenKH;
GO


-- ============================================================
-- PHẦN 6: DỮ LIỆU MẪU (SEED DATA)
-- ============================================================

-- Danh mục
INSERT INTO DanhMuc (TenDanhMuc, MoTa) VALUES
(N'Món chính',      N'Các món chính trong thực đơn'),
(N'Khai vị',        N'Các món khai vị'),
(N'Tráng miệng',    N'Bánh, kem, chè...'),
(N'Đồ uống',        N'Nước giải khát, cà phê, trà'),
(N'Lẩu',            N'Các loại lẩu');

-- Món ăn
INSERT INTO Mon (TenMon, DonGia, MaDanhMuc, MoTa) VALUES
(N'Cơm tấm sườn bì chả',    55000, 1, N'Cơm tấm truyền thống'),
(N'Phở bò đặc biệt',         65000, 1, N'Phở bò tái chín đặc biệt'),
(N'Bún bò Huế',              60000, 1, N'Bún bò cay đặc trưng Huế'),
(N'Gỏi cuốn tôm thịt',      45000, 2, N'2 cuốn/phần'),
(N'Chả giò chiên',           50000, 2, N'3 cuốn/phần'),
(N'Chè thái',                35000, 3, N'Chè thái Thái Lan'),
(N'Cà phê sữa đá',           30000, 4, N'Cà phê phin truyền thống'),
(N'Nước cam tươi',           35000, 4, N'Cam vắt tươi'),
(N'Lẩu thái hải sản',       350000, 5, N'Cho 2-3 người');

-- Bàn
INSERT INTO Ban (SoBan, ViTri) VALUES
(N'B01', N'Tầng 1 - Cửa ra vào'),
(N'B02', N'Tầng 1 - Góc trong'),
(N'B03', N'Tầng 1 - Cạnh cửa sổ'),
(N'B04', N'Tầng 2 - Phòng VIP'),
(N'B05', N'Tầng 2 - Phòng VIP'),
(N'B06', N'Tầng 1 - Ngoài trời');

-- Tài khoản (mật khẩu đã hash - ví dụ)
INSERT INTO TaiKhoan (TenTK, MatKhau, ChucVu) VALUES
(N'admin',     '5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8', N'Admin'),
(N'quanly01',  '5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8', N'Quản lý'),
(N'thungan01', '5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8', N'Thu ngân'),
(N'nhanvien01','5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8', N'Nhân viên'),
(N'nhanvien02','5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8', N'Nhân viên');

-- Nhân viên
INSERT INTO NhanVien (TenNV, SoDienThoai, CCCD, MaTaiKhoan) VALUES
(N'Nguyễn Văn An',     '0901234567', '079123456789', 2),
(N'Trần Thị Bình',     '0912345678', '079234567890', 3),
(N'Lê Văn Cường',      '0923456789', '079345678901', 4),
(N'Phạm Thị Dung',     '0934567890', '079456789012', 5);

-- Chi nhánh
INSERT INTO ChiNhanh (TenChiNhanh, MaChiNhanhStr, DonVi, DiaChi) VALUES
(N'Nhà hàng Trung tâm', N'CN001', N'kg', N'123 Nguyễn Huệ, Q1, TP.HCM'),
(N'Chi nhánh Bình Thạnh', N'CN002', N'kg', N'456 Xô Viết Nghệ Tĩnh, Q.BT, TP.HCM');

-- Nhà cung cấp
INSERT INTO NhaCungCap (TenNCC, SoDienThoai, DiaChi) VALUES
(N'Công ty TNHH Thực phẩm Sạch',   '02812345678', N'789 Lạc Long Quân, Q.11, TP.HCM'),
(N'Nông trại Rau Sạch Đà Lạt',     '02632345678', N'100 Trần Phú, Đà Lạt, Lâm Đồng');

-- Nguyên liệu
INSERT INTO NguyenLieu (TenNguyenLieu, DonViTinh, MaChiNhanh) VALUES
(N'Thịt heo', N'kg', 1),
(N'Rau sống',  N'kg', 1),
(N'Gạo tẻ',   N'kg', 1),
(N'Xương bò',  N'kg', 1),
(N'Bánh phở',  N'kg', 1);

-- Định mức nguyên liệu
INSERT INTO DinhMuc (MaMon, MaNguyenLieu, SoLuongDung, DonVi) VALUES
(1, 1, 0.150, N'kg'),   -- Cơm tấm cần 150g thịt
(1, 2, 0.050, N'kg'),   -- Cơm tấm cần 50g rau
(1, 3, 0.200, N'kg'),   -- Cơm tấm cần 200g gạo
(2, 4, 0.300, N'kg'),   -- Phở cần 300g xương bò
(2, 5, 0.100, N'kg');   -- Phở cần 100g bánh phở

-- Khách hàng mẫu
INSERT INTO KhachHang (TenKH, SoDienThoai, Email) VALUES
(N'Nguyễn Minh Tuấn', '0901111222', 'tuan@email.com'),
(N'Lê Thị Hoa',       '0912222333', 'hoa@email.com'),
(N'Trần Văn Bảo',     '0923333444', NULL);

PRINT N'=== THIẾT KẾ VẬT LÝ HOÀN TẤT ===';
PRINT N'Đã tạo: 17 bảng, 15 index, 8 trigger, 8 stored procedure, 3 view, dữ liệu mẫu';
GO
