import json
import boto3
import csv
import os
import re
import logging
from datetime import datetime
from io import StringIO
from urllib.parse import unquote_plus

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3_client = boto3.client('s3')
sns_client = boto3.client('sns')

SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN', '')
REQUIRED_HEADERS = ['user_id', 'email', 'signup_date']

def lambda_handler(event, context):
    """
    Main Lambda handler for S3 CSV validation
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    for record in event['Records']:
        try:
            bucket_name = record['s3']['bucket']['name']
            object_key = unquote_plus(record['s3']['object']['key'])
            
            logger.info(f"Processing file: s3://{bucket_name}/{object_key}")
            
            if not object_key.lower().endswith('.csv'):
                logger.info(f"Skipping non-CSV file: {object_key}")
                continue
            
            validation_result = validate_csv_file(bucket_name, object_key)
            
            if validation_result['is_valid']:
                logger.info(f"File validation PASSED: {object_key}")
            else:
                logger.error(f"File validation FAILED: {object_key} - {validation_result['error']}")
                
                if SNS_TOPIC_ARN:
                    send_sns_notification(bucket_name, object_key, validation_result)
                else:
                    logger.warning("SNS_TOPIC_ARN not configured, skipping notification")
                    
        except Exception as e:
            logger.error(f"Error processing record: {str(e)}")
            continue
    
    return {
        'statusCode': 200,
        'body': json.dumps('Processing completed')
    }

def validate_csv_file(bucket_name, object_key):
    """
    Download and validate a CSV file from S3
    """
    try:
        response = s3_client.get_object(Bucket=bucket_name, Key=object_key)
        csv_content = response['Body'].read().decode('utf-8')
        
        csv_reader = csv.DictReader(StringIO(csv_content))
        
        headers = csv_reader.fieldnames
        if not headers:
            return {
                'is_valid': False,
                'error': 'CSV file is empty or has no headers',
                'line_number': 1
            }
        
        missing_headers = set(REQUIRED_HEADERS) - set(headers)
        if missing_headers:
            return {
                'is_valid': False,
                'error': f'Missing required headers: {", ".join(missing_headers)}',
                'line_number': 1
            }
        
        line_number = 2  # Start at 2 since header is line 1
        for row in csv_reader:
            validation_error = validate_row(row, line_number)
            if validation_error:
                return {
                    'is_valid': False,
                    'error': validation_error['error'],
                    'line_number': validation_error['line_number']
                }
            line_number += 1
        
        return {'is_valid': True}
        
    except Exception as e:
        return {
            'is_valid': False,
            'error': f'Error processing file: {str(e)}',
            'line_number': 0
        }

def validate_row(row, line_number):
    """
    Validate a single CSV row
    """
    user_id = row.get('user_id', '').strip()
    if not user_id:
        return {
            'error': 'user_id is empty',
            'line_number': line_number
        }
    
    if not user_id.isalnum():
        return {
            'error': 'user_id must be alphanumeric',
            'line_number': line_number
        }
    
    email = row.get('email', '').strip()
    if not email:
        return {
            'error': 'email is empty',
            'line_number': line_number
        }
    
    if not is_valid_email(email):
        return {
            'error': 'email format is invalid',
            'line_number': line_number
        }
    
    signup_date = row.get('signup_date', '').strip()
    if not signup_date:
        return {
            'error': 'signup_date is empty',
            'line_number': line_number
        }
    
    date_validation = validate_date(signup_date)
    if not date_validation['is_valid']:
        return {
            'error': date_validation['error'],
            'line_number': line_number
        }
    
    return None

def is_valid_email(email):
    """
    Validate email format using regex
    """
    email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return re.match(email_pattern, email) is not None

def validate_date(date_string):
    """
    Validate date format (YYYY-MM-DD) and ensure it's not in the future
    """
    try:
        parsed_date = datetime.strptime(date_string, '%Y-%m-%d')
        
        current_date = datetime.now()
        if parsed_date.date() > current_date.date():
            return {
                'is_valid': False,
                'error': 'signup_date cannot be in the future'
            }
        
        return {'is_valid': True}
        
    except ValueError:
        return {
            'is_valid': False,
            'error': 'signup_date must be in YYYY-MM-DD format'
        }

def send_sns_notification(bucket_name, object_key, validation_result):
    """
    Send SNS notification for invalid CSV file
    """
    try:
        message = {
            'bucket': bucket_name,
            'file_name': object_key,
            'line_number': validation_result.get('line_number', 0),
            'error_description': validation_result['error']
        }
        
        subject = f"CSV Validation Failed: {object_key}"
        
        message_body = f"""
CSV File Validation Failed

Bucket: {bucket_name}
File: {object_key}
Line Number: {validation_result.get('line_number', 'N/A')}
Error: {validation_result['error']}

Please check the file and re-upload a corrected version.
        """.strip()
        
        response = sns_client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=subject,
            Message=message_body
        )
        
        logger.info(f"SNS notification sent. MessageId: {response['MessageId']}")
        
    except Exception as e:
        logger.error(f"Failed to send SNS notification: {str(e)}")
