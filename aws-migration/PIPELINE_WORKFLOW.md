# Pipeline Workflow - Hướng dẫn đúng quy trình

## Vấn đề quan trọng: Tạo Tables trong Glue Data Catalog

### Vấn đề ban đầu

Pipeline ban đầu có **Load job** (`load_job.py`) sử dụng `saveAsTable()` để tạo tables trong Glue Data Catalog. Tuy nhiên:

- **`saveAsTable()` KHÔNG đảm bảo** tạo table trong Glue Data Catalog
- Spark mặc định dùng **local Hive metastore** (Athena không thấy được)
- Cần cấu hình **Glue Catalog metastore** thì `saveAsTable()` mới hoạt động

### Giải pháp

Có 2 cách để tạo tables trong Glue Data Catalog:

#### **Option 1: Dùng Glue Crawler (RECOMMENDED)**

Đây là cách **đơn giản và đáng tin cậy nhất** cho Data Lake + Athena:

1. Transform job ghi Parquet files vào S3
2. Crawler scan S3 folders và tự động tạo table schemas
3. Tables xuất hiện trong Glue Data Catalog
4. Query được với Athena

**Ưu điểm:**
- Crawler tự động infer schema từ Parquet
- Không cần cấu hình Spark metastore
- Best practice cho Data Lake architecture
- Dễ maintain và debug

#### **Option 2: Sửa Load job để bind với Glue Catalog**

Nếu vẫn muốn dùng Load job, cần thêm cấu hình:

```python
spark.conf.set("spark.sql.catalogImplementation", "hive")
spark.conf.set(
    "hive.metastore.client.factory.class",
    "com.amazonaws.glue.catalog.metastore.AWSGlueDataCatalogHiveClientFactory"
)
```

**Nhược điểm:**
- Phức tạp hơn Crawler
- Dễ gây nhầm lẫn cho beginner
- Vẫn khuyến nghị dùng Crawler

---

## Quy trình đúng (RECOMMENDED)

### Step 1: Upload dữ liệu và scripts
```bash
01-upload-to-s3.bat
```
- Upload raw data lên S3
- Upload Glue scripts lên S3
- Tạo folder structure

### Step 2: Tạo IAM Role
```bash
02-create-iam-role.bat
```
- Tạo role với đủ quyền:
  - S3 access (GetObject, PutObject, ListBucket)
  - **Glue Catalog access (CreateTable, UpdateTable)** ← QUAN TRỌNG
  - CloudWatch Logs

### Step 3: Tạo Glue Database và Jobs
```bash
03-create-glue-jobs.bat
```
- Tạo Glue database: `uber_data_db`
- Tạo Extract job
- Tạo Transform job
- **Load job là OPTIONAL** (khuyến nghị bỏ qua, dùng Crawler)

### Step 4: Chạy ETL Jobs
Trong AWS Console hoặc CLI:
1. Chạy `uber-etl-extract-job` → Ghi Parquet vào `processed-data/extracted/`
2. Chạy `uber-etl-transform-job` → Ghi 8 tables vào `processed-data/`

**Kết quả:** S3 có đủ Parquet files

### Step 5: Tạo Tables bằng Crawler (RECOMMENDED)
```bash
05-create-glue-crawler.bat
```
- Tạo **2 crawlers** (idempotent - chạy nhiều lần không lỗi):
  1. `uber-etl-crawler-extracted` - Crawl `processed-data/extracted/` (optional, để verify)
  2. `uber-etl-crawler-curated` - Crawl 8 folders dim/fact (main, required)
- Crawler tự động tạo tables trong Glue Data Catalog
- Tables sẵn sàng query với Athena

**Kết quả:** Glue Data Catalog có 8 tables (hoặc 9 nếu crawl extracted)

**Lưu ý về 2-stage crawler:**
- Extract job ghi vào `processed-data/extracted/` → Parquet files
- Transform job đọc từ `extracted/` và ghi vào 8 folders riêng:
  - `datetime_dim/`, `passenger_count_dim/`, `trip_distance_dim/`
  - `rate_code_dim/`, `pickup_location_dim/`, `dropoff_location_dim/`
  - `payment_type_dim/`, `fact_table/`
- Script tự động tạo 2 crawlers riêng để xử lý đúng từng stage

### Step 6: Query với Athena
- Chọn database: `uber_data_db`
- Query các tables đã tạo

### Step 6b: Chạy lại Crawler (nếu cần)
```bash
06-run-crawler-curated.bat
```
- Chỉ start crawler curated (không tạo lại)
- Dùng khi đã chạy Transform job lại và muốn update tables

---

## Quy trình thay thế (nếu dùng Load job)

Nếu bạn muốn dùng Load job thay vì Crawler:

1. Chạy Step 1-4 như trên
2. **Thay vì Step 5**, chạy `uber-etl-load-job`
   - Load job đã được sửa để bind với Glue Catalog
   - Sẽ tạo tables trong Glue Data Catalog

**Lưu ý:** Crawler vẫn được khuyến nghị hơn.

---

## Troubleshooting

### Vấn đề: "Database có 0 tables"

**Nguyên nhân:**
1. Chưa chạy Crawler
2. Crawler trỏ sai path
3. IAM role thiếu quyền `glue:CreateTable`
4. Load job chạy nhưng không bind với Glue Catalog (nếu dùng Load job)

**Giải pháp:**
1. Chạy `05-create-glue-crawler.bat`
2. Kiểm tra Crawler targets trỏ đúng `processed-data/`
3. Kiểm tra IAM role có quyền Glue Catalog
4. Nếu dùng Load job, đảm bảo đã cấu hình Glue Catalog metastore

### Vấn đề: "Crawler chỉ tạo 1 table thay vì 8"

**Nguyên nhân:**
- Crawler trỏ vào `processed-data/` root thay vì từng folder riêng
- Hoặc crawler đang crawl `extracted/` thay vì các dim/fact folders

**Giải pháp:**
- Script `05-create-glue-crawler.bat` đã được cấu hình đúng:
  - Crawler `uber-etl-crawler-curated` trỏ vào 8 folders riêng biệt
  - Mỗi folder → 1 table
  - Crawler `uber-etl-crawler-extracted` là optional (chỉ để verify)

### Vấn đề: "Phải chạy crawler 2 lần - lần 1 crawl extracted/, lần 2 crawl processed-data/"

**Nguyên nhân:**
- Đây là workflow 2-stage:
  1. Extract job → `processed-data/extracted/`
  2. Transform job → `processed-data/*_dim/` và `fact_table/`

**Giải pháp:**
- Script `05-create-glue-crawler.bat` tự động tạo 2 crawlers riêng:
  - Crawler extracted (optional) - chỉ cần chạy 1 lần để verify
  - Crawler curated (main) - chạy sau mỗi lần Transform job
- Sau lần đầu, chỉ cần chạy `06-run-crawler-curated.bat` để update tables

---

## Kiến trúc Data Flow

```
Raw CSV (S3)
    ↓
[Extract Job] → Parquet (processed-data/extracted/)
    ↓
[Transform Job] → 8 Parquet folders (processed-data/*_dim/, fact_table/)
    ↓
[Crawler] → 8 Tables in Glue Data Catalog
    ↓
[Athena] → Query tables
    ↓
[QuickSight] → Visualize
```

---

## Checklist

- [ ] Step 1: Upload data và scripts
- [ ] Step 2: Tạo IAM role với đủ quyền Glue
- [ ] Step 3: Tạo database và jobs (bỏ qua Load job)
- [ ] Step 4: Chạy Extract + Transform jobs
- [ ] Step 5: **Chạy 05-create-glue-crawler.bat để tạo crawlers** ← QUAN TRỌNG
  - [ ] Crawler extracted (optional - để verify)
  - [ ] Crawler curated (main - tạo 8 tables)
- [ ] Step 6: Verify tables trong Glue Console (8 tables)
- [ ] Step 7: Query với Athena
- [ ] (Optional) Step 6b: Chạy 06-run-crawler-curated.bat nếu cần update tables

---

## Tài liệu tham khảo

- [AWS Glue Crawler Documentation](https://docs.aws.amazon.com/glue/latest/dg/add-crawler.html)
- [AWS Glue Data Catalog](https://docs.aws.amazon.com/glue/latest/dg/catalog-and-crawler.html)
- [Athena Query Best Practices](https://docs.aws.amazon.com/athena/latest/ug/best-practices.html)
