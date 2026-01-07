"""
AWS Glue Job: Transform Uber Data to Star Schema
This job transforms the extracted data into dimension tables and a fact table.
"""

import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.dynamicframe import DynamicFrame
from pyspark.sql.functions import col, monotonically_increasing_id
from pyspark.sql.window import Window
from pyspark.sql.functions import row_number

# Get job parameters
args = getResolvedOptions(sys.argv, [
    'JOB_NAME',
    'S3_BUCKET',
    'INPUT_PATH',
    'OUTPUT_PATH'
])

# Initialize Glue context
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# S3 paths
s3_bucket = args['S3_BUCKET']
input_path = args.get('INPUT_PATH', 'processed-data/extracted/')
output_path = args.get('OUTPUT_PATH', 'processed-data/')

input_s3_path = f"s3://{s3_bucket}/{input_path}"
output_s3_path = f"s3://{s3_bucket}/{output_path}"

print(f"Reading extracted data from: {input_s3_path}")

# Read extracted data
df = spark.read.parquet(input_s3_path)
print(f"Loaded {df.count()} rows")

# ========== Create Dimension Tables ==========

# 1. Datetime Dimension
print("Creating datetime dimension...")
datetime_dim = df.select(
    'tpep_pickup_datetime',
    'tpep_dropoff_datetime'
).dropDuplicates()

datetime_dim = datetime_dim \
    .withColumn('pick_hour', col('tpep_pickup_datetime').cast('timestamp').cast('date').cast('int') % 24) \
    .withColumn('pick_day', col('tpep_pickup_datetime').cast('timestamp').cast('string').substr(9, 2).cast('int')) \
    .withColumn('pick_month', col('tpep_pickup_datetime').cast('timestamp').cast('string').substr(6, 2).cast('int')) \
    .withColumn('pick_year', col('tpep_pickup_datetime').cast('timestamp').cast('string').substr(1, 4).cast('int')) \
    .withColumn('pick_weekday', (col('tpep_pickup_datetime').cast('long') / 86400 + 4) % 7) \
    .withColumn('drop_hour', col('tpep_dropoff_datetime').cast('timestamp').cast('date').cast('int') % 24) \
    .withColumn('drop_day', col('tpep_dropoff_datetime').cast('timestamp').cast('string').substr(9, 2).cast('int')) \
    .withColumn('drop_month', col('tpep_dropoff_datetime').cast('timestamp').cast('string').substr(6, 2).cast('int')) \
    .withColumn('drop_year', col('tpep_dropoff_datetime').cast('timestamp').cast('string').substr(1, 4).cast('int')) \
    .withColumn('drop_weekday', (col('tpep_dropoff_datetime').cast('long') / 86400 + 4) % 7)

# Use proper datetime functions
from pyspark.sql.functions import hour, dayofmonth, month, year, dayofweek

datetime_dim = df.select(
    'tpep_pickup_datetime',
    'tpep_dropoff_datetime'
).dropDuplicates()

datetime_dim = datetime_dim \
    .withColumn('pick_hour', hour('tpep_pickup_datetime')) \
    .withColumn('pick_day', dayofmonth('tpep_pickup_datetime')) \
    .withColumn('pick_month', month('tpep_pickup_datetime')) \
    .withColumn('pick_year', year('tpep_pickup_datetime')) \
    .withColumn('pick_weekday', dayofweek('tpep_pickup_datetime')) \
    .withColumn('drop_hour', hour('tpep_dropoff_datetime')) \
    .withColumn('drop_day', dayofmonth('tpep_dropoff_datetime')) \
    .withColumn('drop_month', month('tpep_dropoff_datetime')) \
    .withColumn('drop_year', year('tpep_dropoff_datetime')) \
    .withColumn('drop_weekday', dayofweek('tpep_dropoff_datetime')) \
    .withColumn('datetime_id', monotonically_increasing_id())

datetime_dim = datetime_dim.select(
    'datetime_id', 'tpep_pickup_datetime', 'pick_hour', 'pick_day', 'pick_month', 
    'pick_year', 'pick_weekday', 'tpep_dropoff_datetime', 'drop_hour', 'drop_day', 
    'drop_month', 'drop_year', 'drop_weekday'
)

print(f"Datetime dimension: {datetime_dim.count()} rows")

# 2. Passenger Count Dimension
print("Creating passenger count dimension...")
passenger_count_dim = df.select('passenger_count').dropDuplicates()
passenger_count_dim = passenger_count_dim.withColumn('passenger_count_id', monotonically_increasing_id())
passenger_count_dim = passenger_count_dim.select('passenger_count_id', 'passenger_count')
print(f"Passenger count dimension: {passenger_count_dim.count()} rows")

# 3. Trip Distance Dimension
print("Creating trip distance dimension...")
trip_distance_dim = df.select('trip_distance').dropDuplicates()
trip_distance_dim = trip_distance_dim.withColumn('trip_distance_id', monotonically_increasing_id())
trip_distance_dim = trip_distance_dim.select('trip_distance_id', 'trip_distance')
print(f"Trip distance dimension: {trip_distance_dim.count()} rows")

# 4. Rate Code Dimension
print("Creating rate code dimension...")
from pyspark.sql.functions import when

rate_code_dim = df.select('RatecodeID').dropDuplicates()
rate_code_dim = rate_code_dim.withColumn('rate_code_id', monotonically_increasing_id())
rate_code_dim = rate_code_dim.withColumn('rate_code_name',
    when(col('RatecodeID') == 1, 'Standard rate')
    .when(col('RatecodeID') == 2, 'JFK')
    .when(col('RatecodeID') == 3, 'Newark')
    .when(col('RatecodeID') == 4, 'Nassau or Westchester')
    .when(col('RatecodeID') == 5, 'Negotiated fare')
    .when(col('RatecodeID') == 6, 'Group ride')
    .otherwise('Unknown')
)
rate_code_dim = rate_code_dim.select('rate_code_id', 'RatecodeID', 'rate_code_name')
print(f"Rate code dimension: {rate_code_dim.count()} rows")

# 5. Pickup Location Dimension
print("Creating pickup location dimension...")
pickup_location_dim = df.select('pickup_longitude', 'pickup_latitude').dropDuplicates()
pickup_location_dim = pickup_location_dim.withColumn('pickup_location_id', monotonically_increasing_id())
pickup_location_dim = pickup_location_dim.select('pickup_location_id', 'pickup_latitude', 'pickup_longitude')
print(f"Pickup location dimension: {pickup_location_dim.count()} rows")

# 6. Dropoff Location Dimension
print("Creating dropoff location dimension...")
dropoff_location_dim = df.select('dropoff_longitude', 'dropoff_latitude').dropDuplicates()
dropoff_location_dim = dropoff_location_dim.withColumn('dropoff_location_id', monotonically_increasing_id())
dropoff_location_dim = dropoff_location_dim.select('dropoff_location_id', 'dropoff_latitude', 'dropoff_longitude')
print(f"Dropoff location dimension: {dropoff_location_dim.count()} rows")

# 7. Payment Type Dimension
print("Creating payment type dimension...")
payment_type_dim = df.select('payment_type').dropDuplicates()
payment_type_dim = payment_type_dim.withColumn('payment_type_id', monotonically_increasing_id())
payment_type_dim = payment_type_dim.withColumn('payment_type_name',
    when(col('payment_type') == 1, 'Credit card')
    .when(col('payment_type') == 2, 'Cash')
    .when(col('payment_type') == 3, 'No charge')
    .when(col('payment_type') == 4, 'Dispute')
    .when(col('payment_type') == 5, 'Unknown')
    .when(col('payment_type') == 6, 'Voided trip')
    .otherwise('Unknown')
)
payment_type_dim = payment_type_dim.select('payment_type_id', 'payment_type', 'payment_type_name')
print(f"Payment type dimension: {payment_type_dim.count()} rows")

# ========== Create Fact Table ==========
print("Creating fact table...")

fact_table = df \
    .join(passenger_count_dim, on='passenger_count', how='left') \
    .join(trip_distance_dim, on='trip_distance', how='left') \
    .join(rate_code_dim, on='RatecodeID', how='left') \
    .join(pickup_location_dim, on=['pickup_longitude', 'pickup_latitude'], how='left') \
    .join(dropoff_location_dim, on=['dropoff_longitude', 'dropoff_latitude'], how='left') \
    .join(datetime_dim, on=['tpep_pickup_datetime', 'tpep_dropoff_datetime'], how='left') \
    .join(payment_type_dim, on='payment_type', how='left')

fact_table = fact_table.select(
    'trip_id', 'VendorID', 'datetime_id', 'passenger_count_id',
    'trip_distance_id', 'rate_code_id', 'store_and_fwd_flag', 'pickup_location_id',
    'dropoff_location_id', 'payment_type_id', 'fare_amount', 'extra', 'mta_tax',
    'tip_amount', 'tolls_amount', 'improvement_surcharge', 'total_amount'
)

print(f"Fact table: {fact_table.count()} rows")

# ========== Write to S3 ==========

def write_table(df, table_name):
    """Write DataFrame to S3 in Parquet format"""
    path = f"{output_s3_path}{table_name}/"
    print(f"Writing {table_name} to {path}")
    
    dynamic_frame = DynamicFrame.fromDF(df, glueContext, table_name)
    glueContext.write_dynamic_frame.from_options(
        frame=dynamic_frame,
        connection_type="s3",
        connection_options={"path": path},
        format="parquet",
        format_options={"compression": "snappy"}
    )

# Write all tables
write_table(datetime_dim, "datetime_dim")
write_table(passenger_count_dim, "passenger_count_dim")
write_table(trip_distance_dim, "trip_distance_dim")
write_table(rate_code_dim, "rate_code_dim")
write_table(pickup_location_dim, "pickup_location_dim")
write_table(dropoff_location_dim, "dropoff_location_dim")
write_table(payment_type_dim, "payment_type_dim")
write_table(fact_table, "fact_table")

print("Transform job completed successfully!")

# Commit job
job.commit()
