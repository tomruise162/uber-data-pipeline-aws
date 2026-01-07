"""
AWS Glue Job: Extract Uber Data from S3
This job reads the raw CSV file from S3 and prepares it for transformation.
"""

import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.dynamicframe import DynamicFrame
from pyspark.sql.functions import to_timestamp

# Get job parameters
args = getResolvedOptions(sys.argv, [
    'JOB_NAME',
    'S3_BUCKET',
    'RAW_DATA_PATH',
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
raw_data_path = args.get('RAW_DATA_PATH', 'raw-data/uber_data.csv')
output_path = args.get('OUTPUT_PATH', 'processed-data/extracted/')

input_path = f"s3://{s3_bucket}/{raw_data_path}"
output_s3_path = f"s3://{s3_bucket}/{output_path}"

print(f"Reading data from: {input_path}")

# Read CSV from S3
df = spark.read.format("csv") \
    .option("header", "true") \
    .option("inferSchema", "true") \
    .load(input_path)

print(f"Loaded {df.count()} rows")
print("Schema:")
df.printSchema()

# Data cleaning and type conversion
print("Converting datetime columns...")
df = df.withColumn("tpep_pickup_datetime", to_timestamp("tpep_pickup_datetime"))
df = df.withColumn("tpep_dropoff_datetime", to_timestamp("tpep_dropoff_datetime"))

# Remove duplicates
print("Removing duplicates...")
initial_count = df.count()
df = df.dropDuplicates()
final_count = df.count()
print(f"Removed {initial_count - final_count} duplicate rows")

# Add trip_id
print("Adding trip_id...")
from pyspark.sql.functions import monotonically_increasing_id
df = df.withColumn("trip_id", monotonically_increasing_id())

# Show sample data
print("Sample data:")
df.show(5)

# Convert to DynamicFrame for Glue
dynamic_frame = DynamicFrame.fromDF(df, glueContext, "extracted_data")

# Write to S3 in Parquet format
print(f"Writing extracted data to: {output_s3_path}")
glueContext.write_dynamic_frame.from_options(
    frame=dynamic_frame,
    connection_type="s3",
    connection_options={
        "path": output_s3_path,
        "partitionKeys": []
    },
    format="parquet",
    format_options={
        "compression": "snappy"
    }
)

print("Extract job completed successfully!")

# Commit job
job.commit()
