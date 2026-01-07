"""
AWS Glue Job: Load Transformed Data to Glue Data Catalog
This job registers the transformed tables in the Glue Data Catalog for Athena queries.
"""

import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job

# Get job parameters
args = getResolvedOptions(sys.argv, [
    'JOB_NAME',
    'S3_BUCKET',
    'INPUT_PATH',
    'DATABASE_NAME'
])

# Initialize Glue context
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# IMPORTANT: Configure Spark to use Glue Data Catalog as Hive metastore
# Without this, saveAsTable() will NOT create tables in Glue Data Catalog
# It will only create tables in local Hive metastore (which Athena cannot see)
print("Configuring Spark to use Glue Data Catalog as metastore...")
spark.conf.set("spark.sql.catalogImplementation", "hive")
spark.conf.set(
    "hive.metastore.client.factory.class",
    "com.amazonaws.glue.catalog.metastore.AWSGlueDataCatalogHiveClientFactory"
)
print("✓ Glue Catalog configuration applied")

# Parameters
s3_bucket = args['S3_BUCKET']
input_path = args.get('INPUT_PATH', 'processed-data/')
database_name = args.get('DATABASE_NAME', 'uber_data_db')

input_s3_path = f"s3://{s3_bucket}/{input_path}"

print(f"Loading data from: {input_s3_path}")
print(f"Database: {database_name}")

# List of tables to register
tables = [
    'datetime_dim',
    'passenger_count_dim',
    'trip_distance_dim',
    'rate_code_dim',
    'pickup_location_dim',
    'dropoff_location_dim',
    'payment_type_dim',
    'fact_table'
]

# Register each table in Glue Data Catalog
for table_name in tables:
    table_path = f"{input_s3_path}{table_name}/"
    
    print(f"Registering table: {table_name}")
    print(f"Path: {table_path}")
    
    try:
        # Read the Parquet data
        df = spark.read.parquet(table_path)
        
        print(f"  - Rows: {df.count()}")
        print(f"  - Columns: {len(df.columns)}")
        
        # Write to Glue Data Catalog
        df.write.mode("overwrite") \
            .format("parquet") \
            .option("path", table_path) \
            .saveAsTable(f"{database_name}.{table_name}")
        
        print(f"  ✓ Successfully registered {table_name}")
        
    except Exception as e:
        print(f"  ✗ Error registering {table_name}: {str(e)}")
        continue

print("\n" + "="*50)
print("Load job completed!")
print(f"All tables registered in database: {database_name}")
print("You can now query these tables using Amazon Athena")
print("="*50)

# Commit job
job.commit()
