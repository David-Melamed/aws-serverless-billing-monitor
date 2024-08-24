import os
import boto3
import logging

logger = logging.getLogger()

def send_notification(active_services):
    sns = boto3.client('sns')
    topic_arn = os.environ['SNSTopicArn']
    
    excluded_resource_types = ['AWS::IAM::Role','AWS::IAM::User','AWS::IAM::Policy','AWS::CloudFormation::Stack']

    message = "Active AWS Services Count and Details:\n\n"
    for resource_type, resources in active_services.items():
        print(resource_type)
        if resource_type not in excluded_resource_types:
            resource_count = len(resources)
            message += f"{resource_type} (count={resource_count}):\n"
            for resource in resources:
                resource_name = resource['resourceName'] if resource['resourceName'] else 'N/A'
                resource_id = resource['resourceId']
                message += f"  • {resource_name} (ID: {resource_id})\n"
            message += "\n"

    if message == "Active AWS Services Count and Details:\n\n":
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