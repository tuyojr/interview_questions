import boto3
from botocore import UNSIGNED
from botocore.client import Config

s3 = boto3.client('s3', config=Config(signature_version=UNSIGNED))
response = s3.list_objects_v2(Bucket='abcfakebucket', Prefix='__ab__')

if 'Contents' in response:
    file_key = response['Contents'][0]['Key']
    s3_object = s3.get_object(Bucket='abcfakebucket', Key=file_key)
    content = s3_object['Body'].read().decode('utf-8')
    print(content)