import os
import boto3
import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    try:
        active_services = check_active_services()
        if active_services:
            send_notification(active_services)
            logger.info("Notification sent successfully")
        else:
            logger.warning("No active services found")
        return {
            'statusCode': 200,
            'body': json.dumps('Function executed successfully')
        }
    except Exception as e:
        logger.error(f"Error occurred: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps('Error occurred during execution')
        }

def check_active_services():
    active_services = {}
    config_client = boto3.client('config')
    
    resource_types = [
        'AWS::EC2::Instance',
        'AWS::RDS::DBInstance',
        'AWS::S3::Bucket',
        'AWS::Lambda::Function',
        'AWS::CloudTrail::Trail',
        'AWS::DynamoDB::Table',
        'AWS::ElasticLoadBalancingV2::LoadBalancer',
        'AWS::CloudWatch::Alarm'
    ]
    
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
        limit=1000
    )
    
    resources = []
    for page in response_iterator:
        for resource in page['resourceIdentifiers']:
            resources.append({
                'resourceId': resource['resourceId'],
                'resourceName': resource.get('resourceName', 'N/A')
            })
    
    return resources

def send_notification(active_services):
    sns = boto3.client('sns')
    topic_arn = os.environ['SNSTopicArn']
    
    message = "Active AWS Services:\n\n"
    for resource_type, resources in active_services.items():
        if resources:
            message += f"{resource_type}:\n"
            for resource in resources:
                message += f"- ID: {resource['resourceId']}, Name: {resource['resourceName']}\n"
            message += "\n"
    
    if message == "Active AWS Services:\n\n":
        logger.warning("No active services to report")
        return
    
    try:
        response = sns.publish(
            TopicArn=topic_arn,
            Message=message,
            Subject='AWS Active Services Report'
        )
        logger.info(f"SNS publish response: {response}")
    except Exception as e:
        logger.error(f"Error publishing to SNS: {str(e)}")