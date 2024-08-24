#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status.

# Get the directory of the current script
PROJECT_ROOT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source the variables from the external file
source "$(dirname "$0")/variables.env"

# Print the current script directory for debugging
echo "Script directory: $PROJECT_ROOT_PATH"

# Check if the cloudformation directory exists
if [ ! -d "$TEMPLATE_FOLDER" ]; then
    echo "Error: Directory $TEMPLATE_FOLDER does not exist."
    exit 1
fi

# List the files in the cloudformation directory for debugging
echo "Contents of $TEMPLATE_FOLDER:"
ls "$TEMPLATE_FOLDER"

# Check if the S3 bucket exists, skip creation if it does
for bucket in $LAMBDA_CODE_S3_BUCKET_NAME $LAMBDA_ASSETS_S3_BUCKET_NAME; do
    if aws s3 ls "s3://$bucket" 2>&1 | grep -q 'NoSuchBucket'; then
        echo "Creating S3 bucket $bucket"
        aws s3 mb "s3://$bucket" --region "$AWS_REGION"
    else
        echo "S3 bucket $bucket already exists"
    fi
done

# Upload CloudFormation templates to S3
for template in "$TEMPLATE_FOLDER"/*.yaml; do
    template_name=$(basename "$template")
    aws s3 cp "$template" "s3://$LAMBDA_CODE_S3_BUCKET_NAME/templates/$template_name"
done

# Create a temporary directory
TEMP_DIR=$(mktemp -d)

# Copy Lambda function code to the temporary directory
cp "$PROJECT_ROOT_PATH/lambda/"* "$TEMP_DIR/"

# Change permissions of all files in the temporary directory to 644
chmod 777 "$TEMP_DIR/handler.py"
ls -ltr $TEMP_DIR/

# Zip the Lambda function code
zip -j -r "$TEMP_DIR/$SERVICE_NAME.zip" "$TEMP_DIR"/*

# Check if the zip file was created successfully
if [[ -f "$TEMP_DIR/$SERVICE_NAME.zip" ]]; then
    # Upload the zip file to S3
    aws s3 cp "$TEMP_DIR/$SERVICE_NAME.zip" "s3://$LAMBDA_CODE_S3_BUCKET_NAME/$LAMBDA_KEY"
else
    echo "Error: Zip file $SERVICE_NAME.zip was not created."
    exit 1
fi

if [ -d "$ASSETS_DIR" ]; then
    echo "Uploading assets to S3 bucket $LAMBDA_ASSETS_S3_BUCKET_NAME..."
    aws s3 cp "$ASSETS_DIR" "s3://$LAMBDA_ASSETS_S3_BUCKET_NAME/" --recursive
else
    echo "Warning: Assets directory $ASSETS_DIR does not exist."
fi

# Change back to the original directory
cd $PROJECT_ROOT_PATH

# Deploy the CloudFormation stack
aws cloudformation deploy \
    --template-file "$MAIN_TEMPLATE_FILE" \
    --stack-name "$STACK_NAME" \
    --capabilities CAPABILITY_IAM \
    --parameter-overrides \
        LambdaCodeS3BucketName="$LAMBDA_CODE_S3_BUCKET_NAME" \
        LambdaAssetsS3BucketName="$LAMBDA_ASSETS_S3_BUCKET_NAME" \
        LambdaCodeS3Key="$LAMBDA_KEY" \
        EmailAddress="$EMAIL_ADDRESS" \
        MonitoringIntervalMinutes="$MONITORING_INTERVAL_MINUTES" \
        SnsTopicName="$SNS_TOPIC_NAME" \
        ConfigLogsS3BucketName="$CONFIG_LOGS_BUCKET_NAME" \
    --region "$AWS_REGION"

echo "Deployment complete!"