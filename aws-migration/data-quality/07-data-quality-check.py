"""
Data Quality Check Script for Uber ETL Pipeline
Step 07: Data Quality & Profiling

This script performs:
- Data completeness checks
- Data validation
- Duplicate detection
- Data profiling
- Quality score calculation
"""

import boto3
import json
from datetime import datetime
from typing import Dict, List
import sys

# AWS Clients
athena = boto3.client('athena', region_name='ap-southeast-1')
s3 = boto3.client('s3')

DATABASE = 'uber_data_db'
BUCKET_NAME = 'uber-data-v1'
WORKGROUP = 'primary'
OUTPUT_LOCATION = f's3://{BUCKET_NAME}/athena-results/'

class DataQualityChecker:
    def __init__(self):
        self.results = {
            'timestamp': datetime.now().isoformat(),
            'checks': [],
            'overall_score': 0,
            'status': 'PASS'
        }
    
    def execute_query(self, query: str) -> List[Dict]:
        """Execute Athena query and return results"""
        try:
            response = athena.start_query_execution(
                QueryString=query,
                QueryExecutionContext={'Database': DATABASE},
                ResultConfiguration={'OutputLocation': OUTPUT_LOCATION},
                WorkGroup=WORKGROUP
            )
            
            query_id = response['QueryExecutionId']
            
            # Wait for query to complete
            import time
            while True:
                status = athena.get_query_execution(QueryExecutionId=query_id)
                state = status['QueryExecution']['Status']['State']
                
                if state in ['SUCCEEDED', 'FAILED', 'CANCELLED']:
                    break
                time.sleep(1)
            
            if state == 'SUCCEEDED':
                # Get results
                results = athena.get_query_results(QueryExecutionId=query_id)
                return self._parse_results(results)
            else:
                raise Exception(f"Query failed: {state}")
                
        except Exception as e:
            print(f"Error executing query: {e}")
            return []
    
    def _parse_results(self, results: Dict) -> List[Dict]:
        """Parse Athena query results"""
        rows = []
        columns = [col['Name'] for col in results['ResultSet']['ResultSetMetadata']['ColumnInfo']]
        
        for row in results['ResultSet']['Rows'][1:]:  # Skip header
            row_data = {}
            for i, col in enumerate(columns):
                value = row['Data'][i].get('VarCharValue', '')
                row_data[col] = value
            rows.append(row_data)
        
        return rows
    
    def check_completeness(self):
        """Check for null values and missing data"""
        print("Checking data completeness...")
        
        queries = {
            'fact_table_nulls': f"""
                SELECT 
                    COUNT(*) as total_rows,
                    SUM(CASE WHEN trip_id IS NULL THEN 1 ELSE 0 END) as null_trip_id,
                    SUM(CASE WHEN total_amount IS NULL THEN 1 ELSE 0 END) as null_total_amount,
                    SUM(CASE WHEN fare_amount IS NULL THEN 1 ELSE 0 END) as null_fare_amount
                FROM {DATABASE}.fact_table
            """,
            'datetime_dim_nulls': f"""
                SELECT 
                    COUNT(*) as total_rows,
                    SUM(CASE WHEN datetime_id IS NULL THEN 1 ELSE 0 END) as null_datetime_id,
                    SUM(CASE WHEN tpep_pickup_datetime IS NULL THEN 1 ELSE 0 END) as null_pickup
                FROM {DATABASE}.datetime_dim
            """
        }
        
        for check_name, query in queries.items():
            results = self.execute_query(query)
            if results:
                result = results[0]
                total_rows = int(result.get('total_rows', 0))
                null_count = sum(int(v) for k, v in result.items() if k.startswith('null_') and v)
                
                completeness_pct = ((total_rows - null_count) / total_rows * 100) if total_rows > 0 else 0
                
                self.results['checks'].append({
                    'check': check_name,
                    'type': 'completeness',
                    'status': 'PASS' if completeness_pct >= 95 else 'FAIL',
                    'score': completeness_pct,
                    'details': result
                })
    
    def check_duplicates(self):
        """Check for duplicate records"""
        print("Checking for duplicates...")
        
        query = f"""
            SELECT 
                COUNT(*) as total_rows,
                COUNT(DISTINCT trip_id) as unique_trip_ids
            FROM {DATABASE}.fact_table
        """
        
        results = self.execute_query(query)
        if results:
            result = results[0]
            total_rows = int(result.get('total_rows', 0))
            unique_ids = int(result.get('unique_trip_ids', 0))
            duplicates = total_rows - unique_ids
            duplicate_pct = (duplicates / total_rows * 100) if total_rows > 0 else 0
            
            self.results['checks'].append({
                'check': 'duplicate_detection',
                'type': 'uniqueness',
                'status': 'PASS' if duplicate_pct < 1 else 'FAIL',
                'score': 100 - duplicate_pct,
                'details': {
                    'total_rows': total_rows,
                    'unique_ids': unique_ids,
                    'duplicates': duplicates,
                    'duplicate_percentage': round(duplicate_pct, 2)
                }
            })
    
    def check_data_ranges(self):
        """Validate data ranges and business rules"""
        print("Checking data ranges...")
        
        queries = {
            'revenue_validation': f"""
                SELECT 
                    COUNT(*) as total_rows,
                    SUM(CASE WHEN total_amount < 0 THEN 1 ELSE 0 END) as negative_revenue,
                    SUM(CASE WHEN total_amount > 1000 THEN 1 ELSE 0 END) as high_revenue_outliers,
                    SUM(CASE WHEN fare_amount < 0 THEN 1 ELSE 0 END) as negative_fare
                FROM {DATABASE}.fact_table
            """,
            'distance_validation': f"""
                SELECT 
                    COUNT(*) as total_rows,
                    SUM(CASE WHEN trip_distance < 0 THEN 1 ELSE 0 END) as negative_distance,
                    SUM(CASE WHEN trip_distance > 100 THEN 1 ELSE 0 END) as extreme_distance
                FROM {DATABASE}.tbl_analytics
            """
        }
        
        for check_name, query in queries.items():
            results = self.execute_query(query)
            if results:
                result = results[0]
                total_rows = int(result.get('total_rows', 0))
                invalid_count = sum(int(v) for k, v in result.items() if k != 'total_rows' and v)
                
                validity_pct = ((total_rows - invalid_count) / total_rows * 100) if total_rows > 0 else 0
                
                self.results['checks'].append({
                    'check': check_name,
                    'type': 'validation',
                    'status': 'PASS' if validity_pct >= 99 else 'FAIL',
                    'score': validity_pct,
                    'details': result
                })
    
    def data_profiling(self):
        """Generate data profiling statistics"""
        print("Generating data profile...")
        
        query = f"""
            SELECT 
                COUNT(*) as total_trips,
                ROUND(SUM(total_amount), 2) as total_revenue,
                ROUND(AVG(total_amount), 2) as avg_revenue,
                ROUND(MIN(total_amount), 2) as min_revenue,
                ROUND(MAX(total_amount), 2) as max_revenue,
                ROUND(AVG(trip_distance), 2) as avg_distance,
                ROUND(AVG(tip_amount), 2) as avg_tip
            FROM {DATABASE}.tbl_analytics
        """
        
        results = self.execute_query(query)
        if results:
            self.results['profile'] = results[0]
    
    def calculate_overall_score(self):
        """Calculate overall data quality score"""
        if not self.results['checks']:
            return
        
        scores = [check['score'] for check in self.results['checks']]
        self.results['overall_score'] = round(sum(scores) / len(scores), 2)
        
        if self.results['overall_score'] >= 95:
            self.results['status'] = 'PASS'
        elif self.results['overall_score'] >= 80:
            self.results['status'] = 'WARNING'
        else:
            self.results['status'] = 'FAIL'
    
    def generate_report(self):
        """Generate and save quality report"""
        self.calculate_overall_score()
        
        # Save to S3
        report_key = f'data-quality/reports/quality-report-{datetime.now().strftime("%Y%m%d-%H%M%S")}.json'
        
        try:
            s3.put_object(
                Bucket=BUCKET_NAME,
                Key=report_key,
                Body=json.dumps(self.results, indent=2),
                ContentType='application/json'
            )
            print(f"\nQuality report saved to: s3://{BUCKET_NAME}/{report_key}")
        except Exception as e:
            print(f"Error saving report: {e}")
        
        # Print summary
        print("\n" + "="*50)
        print("DATA QUALITY REPORT SUMMARY")
        print("="*50)
        print(f"Overall Score: {self.results['overall_score']}%")
        print(f"Status: {self.results['status']}")
        print(f"\nChecks Performed: {len(self.results['checks'])}")
        
        for check in self.results['checks']:
            print(f"\n- {check['check']}: {check['status']} (Score: {check['score']}%)")
        
        return self.results
    
    def run_all_checks(self):
        """Run all data quality checks"""
        print("="*50)
        print("Starting Data Quality Checks")
        print("="*50)
        
        self.check_completeness()
        self.check_duplicates()
        self.check_data_ranges()
        self.data_profiling()
        
        return self.generate_report()

if __name__ == "__main__":
    checker = DataQualityChecker()
    results = checker.run_all_checks()
    
    # Exit with error code if quality check failed
    if results['status'] == 'FAIL':
        sys.exit(1)

