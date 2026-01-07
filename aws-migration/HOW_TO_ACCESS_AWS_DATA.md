# Cách Thao Tác Với Data & Tables Trên AWS

## Tổng quan

Sau khi chạy ETL pipeline, data và tables đã nằm trên AWS. Có **nhiều cách** để thao tác với chúng:

---

## CÁC CÁCH THAO TÁC VỚI DATA TRÊN AWS

### **1. Amazon Athena - Query Data bằng SQL** (PHỔ BIẾN NHẤT)

#### Cách 1: AWS Console (Web UI)

**Bước 1: Truy cập Athena Console**
```
https://ap-southeast-1.console.aws.amazon.com/athena/
```

**Bước 2: Chọn Database**
- Click vào dropdown "Database"
- Chọn: `uber_data_db`

**Bước 3: Xem Tables**
- Tables sẽ hiển thị ở bên trái
- Click vào table để xem schema

**Bước 4: Query Data**
- Viết SQL query trong editor
- Click "Run" để execute
- Kết quả hiển thị bên dưới

**Ví dụ Query:**
```sql
-- Xem tất cả tables
SHOW TABLES IN uber_data_db;

-- Query fact table
SELECT * FROM uber_data_db.fact_table LIMIT 10;

-- Revenue analysis
SELECT 
    COUNT(*) as total_trips,
    SUM(total_amount) as total_revenue
FROM uber_data_db.fact_table;
```

**Bước 5: Download Results**
- Click "Download results" (CSV format)
- Hoặc "Download as CSV"

---

#### Cách 2: AWS CLI

**Query bằng CLI (Windows CMD):**
```cmd
REM Query và lưu kết quả
aws athena start-query-execution ^
    --query-string "SELECT * FROM uber_data_db.fact_table LIMIT 10" ^
    --query-execution-context Database=uber_data_db ^
    --result-configuration OutputLocation=s3://uber-data-v1/athena-results/ ^
    --work-group primary ^
    --region ap-southeast-1

REM Lấy query execution ID từ output, sau đó:
aws athena get-query-results ^
    --query-execution-id 1016d277-cb58-403c-bb52-a0b35a81a508 ^
    --region ap-southeast-1
```

**Script helper cho Windows CMD (.bat):**
```batch
@echo off
REM File: query-athena.bat
REM Usage: query-athena.bat "SELECT COUNT(*) FROM uber_data_db.fact_table"

set QUERY=%1
set OUTPUT_LOCATION=s3://uber-data-v1/athena-results/
set DATABASE=uber_data_db
set REGION=ap-southeast-1
set WORKGROUP=primary

echo Executing query: %QUERY%
echo.

REM Start query execution
for /f "tokens=*" %%a in ('aws athena start-query-execution --query-string "%QUERY%" --query-execution-context Database=%DATABASE% --result-configuration OutputLocation=%OUTPUT_LOCATION% --work-group %WORKGROUP% --region %REGION% --query "QueryExecutionId" --output text') do set EXECUTION_ID=%%a

echo Query Execution ID: %EXECUTION_ID%
echo Waiting for query to complete...
echo.

REM Wait for completion
:LOOP
for /f "tokens=*" %%a in ('aws athena get-query-execution --query-execution-id %EXECUTION_ID% --region %REGION% --query "QueryExecution.Status.State" --output text') do set STATUS=%%a

echo Status: %STATUS%

if "%STATUS%"=="SUCCEEDED" (
    echo.
    echo Query completed successfully!
    goto GET_RESULTS
)

if "%STATUS%"=="FAILED" (
    echo.
    echo Query failed!
    pause
    exit /b 1
)

timeout /t 2 >nul
goto LOOP

:GET_RESULTS
echo.
echo Getting query results...
echo.
aws athena get-query-results --query-execution-id %EXECUTION_ID% --region %REGION%

echo.
echo Results saved to: %OUTPUT_LOCATION%
echo.
pause
```

**Sử dụng:**
```cmd
REM Chạy script
query-athena.bat "SELECT COUNT(*) FROM uber_data_db.fact_table"

REM Hoặc query đơn giản
query-athena.bat "SELECT * FROM uber_data_db.fact_table LIMIT 10"
```

**Script helper cho Linux/Mac (.sh) - Nếu cần:**
```bash
#!/bin/bash
# File: query-athena.sh
QUERY="$1"
OUTPUT_LOCATION="s3://uber-data-v1/athena-results/"

EXECUTION_ID=$(aws athena start-query-execution \
    --query-string "$QUERY" \
    --query-execution-context Database=uber_data_db \
    --result-configuration OutputLocation=$OUTPUT_LOCATION \
    --work-group primary \
    --region ap-southeast-1 \
    --query 'QueryExecutionId' \
    --output text)

echo "Query Execution ID: $EXECUTION_ID"
echo "Waiting for query to complete..."

while true; do
    STATUS=$(aws athena get-query-execution \
        --query-execution-id $EXECUTION_ID \
        --region ap-southeast-1 \
        --query 'QueryExecution.Status.State' \
        --output text)
    
    if [ "$STATUS" = "SUCCEEDED" ] || [ "$STATUS" = "FAILED" ]; then
        break
    fi
    sleep 2
done

aws athena get-query-results \
    --query-execution-id $EXECUTION_ID \
    --region ap-southeast-1
```

---

#### Cách 3: Python (boto3) - TỐT NHẤT CHO AUTOMATION

**Tạo file:** `query_athena.py`

```python
import boto3
import time
import pandas as pd
from io import StringIO

class AthenaQuery:
    def __init__(self, database='uber_data_db', 
                 output_location='s3://uber-data-v1/athena-results/',
                 region='ap-southeast-1'):
        self.athena = boto3.client('athena', region_name=region)
        self.s3 = boto3.client('s3', region_name=region)
        self.database = database
        self.output_location = output_location
        self.workgroup = 'primary'
    
    def execute_query(self, query: str, wait=True):
        """Execute Athena query"""
        print(f"Executing query: {query[:50]}...")
        
        # Start query
        response = self.athena.start_query_execution(
            QueryString=query,
            QueryExecutionContext={'Database': self.database},
            ResultConfiguration={'OutputLocation': self.output_location},
            WorkGroup=self.workgroup
        )
        
        query_id = response['QueryExecutionId']
        print(f"Query ID: {query_id}")
        
        if wait:
            # Wait for completion
            while True:
                status = self.athena.get_query_execution(QueryExecutionId=query_id)
                state = status['QueryExecution']['Status']['State']
                
                if state in ['SUCCEEDED', 'FAILED', 'CANCELLED']:
                    break
                
                print(f"Status: {state}...")
                time.sleep(2)
            
            if state == 'SUCCEEDED':
                print("Query completed successfully!")
                return query_id
            else:
                error = status['QueryExecution']['Status'].get('StateChangeReason', 'Unknown error')
                raise Exception(f"Query failed: {error}")
        else:
            return query_id
    
    def get_results(self, query_id: str, as_dataframe=True):
        """Get query results"""
        # Get results
        results = self.athena.get_query_results(QueryExecutionId=query_id)
        
        if as_dataframe:
            # Convert to pandas DataFrame
            columns = [col['Name'] for col in results['ResultSet']['ResultSetMetadata']['ColumnInfo']]
            rows = []
            
            for row in results['ResultSet']['Rows'][1:]:  # Skip header
                row_data = []
                for data in row['Data']:
                    value = data.get('VarCharValue', '')
                    row_data.append(value)
                rows.append(row_data)
            
            df = pd.DataFrame(rows, columns=columns)
            return df
        else:
            return results
    
    def query_to_dataframe(self, query: str):
        """Execute query and return as DataFrame"""
        query_id = self.execute_query(query)
        return self.get_results(query_id)
    
    def list_tables(self):
        """List all tables in database"""
        query = f"SHOW TABLES IN {self.database}"
        df = self.query_to_dataframe(query)
        return df
    
    def describe_table(self, table_name: str):
        """Describe table schema"""
        query = f"DESCRIBE {self.database}.{table_name}"
        df = self.query_to_dataframe(query)
        return df
    
    def get_table_count(self, table_name: str):
        """Get row count of table"""
        query = f"SELECT COUNT(*) as count FROM {self.database}.{table_name}"
        df = self.query_to_dataframe(query)
        return int(df['count'].iloc[0])

# Sử dụng
if __name__ == "__main__":
    athena = AthenaQuery()
    
    # List tables
    print("Tables in database:")
    tables = athena.list_tables()
    print(tables)
    
    # Query data
    print("\nQuerying fact_table...")
    df = athena.query_to_dataframe(
        "SELECT * FROM uber_data_db.fact_table LIMIT 10"
    )
    print(df)
    
    # Get table count
    count = athena.get_table_count('fact_table')
    print(f"\nTotal rows in fact_table: {count}")
    
    # Advanced query
    print("\nRevenue analysis:")
    revenue_df = athena.query_to_dataframe("""
        SELECT 
            COUNT(*) as trips,
            SUM(total_amount) as total_revenue,
            AVG(total_amount) as avg_revenue
        FROM uber_data_db.fact_table
    """)
    print(revenue_df)
```

**Sử dụng:**
```bash
pip install boto3 pandas
python query_athena.py
```

---

### **2. AWS Glue Console - Xem Tables & Schema**

**Truy cập:**
```
https://ap-southeast-1.console.aws.amazon.com/glue/
```

**Xem Tables:**
1. Click "Databases" → Chọn `uber_data_db`
2. Click vào database → Xem danh sách tables
3. Click vào table → Xem schema, partitions, properties

**Xem Data:**
- Glue không query data trực tiếp
- Dùng Athena để query (tích hợp sẵn)

**Actions:**
- Edit schema
- Add partitions
- View table properties
- Delete table

---

### **3. Amazon S3 - Xem Raw Data Files**

**Truy cập:**
```
https://s3.console.aws.amazon.com/s3/buckets/uber-data-v1
```

**Xem Data:**
1. Navigate đến folder: `processed-data/`
2. Click vào folder (ví dụ: `fact_table/`)
3. Xem Parquet files
4. **Download** file để xem local (cần tool đọc Parquet)

**Download bằng CLI (Windows CMD):**
```cmd
REM Download một file
aws s3 cp s3://uber-data-v1/processed-data/fact_table/part-00000-xxx.parquet .\local-file.parquet

REM Download cả folder
aws s3 sync s3://uber-data-v1/processed-data/fact_table/ .\local-folder\

REM List files
aws s3 ls s3://uber-data-v1/processed-data/fact_table/ --recursive
```

**Xem Parquet bằng Python:**
```python
import pandas as pd
import pyarrow.parquet as pq

# Download và đọc
df = pd.read_parquet('s3://uber-data-v1/processed-data/fact_table/part-00000-xxx.parquet')
print(df.head())
```

---

### **4. Amazon QuickSight - Data Visualization**

**Truy cập:**
```
https://quicksight.aws.amazon.com/
```

**Workflow:**
1. **Create Dataset** → Chọn Athena → Chọn `uber_data_db`
2. **Select Tables** → Chọn tables cần visualize
3. **Create Visualizations** → Charts, graphs, KPIs
4. **Publish Dashboard** → Share với stakeholders

**Xem data:**
- QuickSight tự động query Athena
- Data hiển thị trong visualizations
- Interactive filtering và drilling

---

### **5. Python Scripts - Automation**

**Tạo file:** `access_aws_data.py`

```python
import boto3
import pandas as pd
from query_athena import AthenaQuery

# Initialize
athena = AthenaQuery()

# 1. List all tables
print("=== TABLES IN DATABASE ===")
tables = athena.list_tables()
print(tables)

# 2. Describe table schema
print("\n=== FACT TABLE SCHEMA ===")
schema = athena.describe_table('fact_table')
print(schema)

# 3. Query data
print("\n=== SAMPLE DATA ===")
df = athena.query_to_dataframe(
    "SELECT * FROM uber_data_db.fact_table LIMIT 10"
)
print(df)

# 4. Analytics query
print("\n=== REVENUE ANALYSIS ===")
revenue = athena.query_to_dataframe("""
    SELECT 
        COUNT(*) as trips,
        SUM(total_amount) as total_revenue,
        AVG(total_amount) as avg_revenue,
        MIN(total_amount) as min_revenue,
        MAX(total_amount) as max_revenue
    FROM uber_data_db.fact_table
""")
print(revenue)

# 5. Export to CSV
df.to_csv('output.csv', index=False)
print("\nData exported to output.csv")
```

---

## WORKFLOW THỰC TẾ

### **Scenario 1: Quick Data Check**

**Cách nhanh nhất:**
1. Mở Athena Console
2. Chọn database
3. Viết query
4. Run → Xem kết quả

---

### **Scenario 2: Data Analysis**

**Workflow:**
1. **Athena Console** → Query và explore data
2. **Save queries** → Lưu queries hay dùng
3. **Export results** → Download CSV
4. **Python analysis** → Import CSV và analyze thêm

---

### **Scenario 3: Automated Reporting**

**Workflow:**
1. **Python script** → Query Athena bằng boto3
2. **Process data** → Pandas analysis
3. **Generate report** → CSV/Excel/HTML
4. **Schedule** → Cron job hoặc Lambda

---

### **Scenario 4: Dashboard Creation**

**Workflow:**
1. **QuickSight** → Connect Athena dataset
2. **Create visualizations** → Charts, KPIs
3. **Publish dashboard** → Share với team
4. **Schedule refresh** → Auto-update data

---

## TOOLS & LIBRARIES

### **Python Libraries:**
```bash
pip install boto3 pandas pyarrow
```

### **Useful Commands:**

**List tables:**
```python
athena.query_to_dataframe("SHOW TABLES IN uber_data_db")
```

**Get table info:**
```python
athena.query_to_dataframe("DESCRIBE uber_data_db.fact_table")
```

**Count rows:**
```python
athena.query_to_dataframe("SELECT COUNT(*) FROM uber_data_db.fact_table")
```

**Query with joins:**
```python
query = """
    SELECT 
        f.trip_id,
        d.pick_hour,
        pay.payment_type_name,
        f.total_amount
    FROM uber_data_db.fact_table f
    JOIN uber_data_db.datetime_dim d ON f.datetime_id = d.datetime_id
    JOIN uber_data_db.payment_type_dim pay ON f.payment_type_id = pay.payment_type_id
    LIMIT 100
"""
df = athena.query_to_dataframe(query)
```

---

## BEST PRACTICES

### **1. Query Optimization:**
- Sử dụng `LIMIT` khi explore
- Filter data sớm (WHERE clause)
- Chỉ SELECT columns cần thiết
- Use partitions nếu có

### **2. Cost Management:**
- Athena charges $5/TB scanned
- Use `LIMIT` để giảm scan
- Cache results khi có thể
- Monitor query costs

### **3. Data Access:**
- **Quick check** → Athena Console
- **Analysis** → Python + boto3
- **Visualization** → QuickSight
- **Automation** → Python scripts

---

## QUICK REFERENCE

### **Athena Console:**
```
https://ap-southeast-1.console.aws.amazon.com/athena/
```

### **Glue Console:**
```
https://ap-southeast-1.console.aws.amazon.com/glue/
```

### **S3 Console:**
```
https://s3.console.aws.amazon.com/s3/buckets/uber-data-v1
```

### **QuickSight:**
```
https://quicksight.aws.amazon.com/
```

---

## NEXT STEPS

1. **Thử Athena Console** → Query data trực tiếp
2. **Setup Python environment** → Install boto3, pandas
3. **Tạo query script** → Automate queries
4. **Setup QuickSight** → Create dashboards

---

## QUICK REFERENCE - Windows CMD Commands

### **List Tables:**
```cmd
aws athena start-query-execution --query-string "SHOW TABLES IN uber_data_db" --query-execution-context Database=uber_data_db --result-configuration OutputLocation=s3://uber-data-v1/athena-results/ --work-group primary --region ap-southeast-1
```

### **Query Data (Simple):**
```cmd
query-athena.bat "SELECT * FROM uber_data_db.fact_table LIMIT 10"
```

### **Count Rows:**
```cmd
query-athena.bat "SELECT COUNT(*) as count FROM uber_data_db.fact_table"
```

### **Revenue Analysis:**
```cmd
query-athena.bat "SELECT COUNT(*) as trips, SUM(total_amount) as total_revenue, AVG(total_amount) as avg_revenue FROM uber_data_db.fact_table"
```

### **List S3 Files:**
```cmd
aws s3 ls s3://uber-data-v1/processed-data/fact_table/ --recursive
```

### **Download from S3:**
```cmd
aws s3 cp s3://uber-data-v1/processed-data/fact_table/part-00000-xxx.parquet .\local-file.parquet
```

---

## RECOMMENDED WORKFLOW (Windows)

### **Quick Check:**
1. Mở Athena Console trong browser
2. Query trực tiếp

### **Automated Queries:**
1. Dùng `query-athena.bat` script
2. Hoặc Python script `query_athena.py`

### **Data Analysis:**
1. Query bằng Athena Console hoặc script
2. Download results (CSV)
3. Mở trong Excel hoặc Python

---

**Tóm lại: Cách phổ biến nhất là dùng Amazon Athena (SQL queries) qua Console hoặc Python!**

**Cho Windows CMD: Dùng `query-athena.bat` script hoặc Athena Console!**
