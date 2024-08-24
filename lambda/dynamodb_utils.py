import boto3
import logging
import os
from s3_utils import load_resource_types
from datetime import datetime

logger = logging.getLogger()

# Initialize the DynamoDB client
dynamodb = boto3.resource('dynamodb')
table_name = os.environ['DYNAMODB_METADATA_TABLE']
metadata_table = dynamodb.Table(table_name)

def check_active_services():
    active_services = {}
    config_client = boto3.client('config')        
    resource_types = load_resource_types()
    for resource_type in resource_types:
        try:
            resources = list_discovered_resources(config_client, resource_type)
            if resources:
                active_services[resource_type] = resources
        except Exception as e:
            logger.error(f"Error discovering resources for {resource_type}: {str(e)}")
    
    return active_services

def list_discovered_resources(config_client, resource_type):
    paginator = config_client.get_paginator('list_discovered_resources')
    response_iterator = paginator.paginate(
        resourceType=resource_type,
        limit=100
    )
    
    resources = []
    for page in response_iterator:
        for resource in page['resourceIdentifiers']:
            resources.append({
                'resourceId': resource['resourceId'],
                'resourceName': resource['resourceName']
            })
    
    return resources

def write_metadata_to_dynamodb(active_services):
    timestamp = datetime.utcnow().isoformat()  # Current time in ISO format
    for resource_type, resources in active_services.items():
        for resource in resources:
            try:
                metadata_table.put_item(
                    Item={
                        'ResourceType': resource_type,
                        'ResourceId': resource['resourceId'],
                        'ResourceName': resource['resourceName'] if resource['resourceName'] else 'N/A',
                        'Timestamp': timestamp
                    }
                )
                logger.info(f"Metadata written to DynamoDB for {resource_type} with ID {resource['resourceId']}")
            except Exception as e:
                logger.error(f"Error writing to DynamoDB: {str(e)}")