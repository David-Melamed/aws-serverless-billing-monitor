import os
import boto3
import json
import logging

logger = logging.getLogger()

def load_resource_types():
    s3_client = boto3.client('s3')
    bucket_name = os.environ.get('RESOURCE_TYPES_BUCKET')
    object_key = 'resource_types.json'
    try:
        response = s3_client.get_object(Bucket=bucket_name, Key=object_key)
        resource_types_data = response['Body'].read()
        resource_types = json.loads(resource_types_data)
        return resource_types
    except Exception as e:
        logger.error(f"Failed to load resource types from S3: {str(e)}")
        return []