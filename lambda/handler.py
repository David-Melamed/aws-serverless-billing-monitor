import logging
import json
from dynamodb_utils import check_active_services 
from dynamodb_utils import write_metadata_to_dynamodb
from sns_utils import send_notification

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    try:
        active_services = check_active_services()
        if active_services:
            send_notification(active_services)
            logger.info("Notification sent successfully")
            write_metadata_to_dynamodb(active_services)
            logger.info("Metadata written to DynamoDB successfully")
            
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