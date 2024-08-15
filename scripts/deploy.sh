#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status.

# Get the directory of the current script
PROJECT_ROOT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Define variables
S3_BUCKET="service-monitor-bucket"  # Replace with your actual S3 bucket name
STACK_NAME="service-monitor-stack"
TEMPLATE_FOLDER="$PROJECT_ROOT_PATH/cloudformation"
MAIN_TEMPLATE_FILE="$TEMPLATE_FOLDER/main.yaml"
LAMBDA_FUNCTION_NAME="service-monitor"
LAMBDA_KEY="lambda/service_monitor.zip"
AWS_REGION="eu-west-1"
EMAIL_ADDRESS="davidmelamed269@gmail.com"

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

# Upload CloudFormation templates to S3
for template in "$TEMPLATE_FOLDER"/*.yaml; do
    template_name=$(basename "$template")
    aws s3 cp "$template" "s3://$S3_BUCKET/templates/$template_name"
done

# Create a temporary directory
TEMP_DIR=$(mktemp -d)

# Copy Lambda function code to the temporary directory
cp "$PROJECT_ROOT_PATH/lambda/service_monitor.py" "$TEMP_DIR/"

# Change to the temporary directory
cd "$TEMP_DIR"

# Zip the Lambda function code
zip -r service_monitor.zip service_monitor.py

# Check if the S3 bucket exists, skip creation if it does
if aws s3 ls "s3://$S3_BUCKET" 2>&1 | grep -q 'NoSuchBucket'; then
    echo "Creating S3 bucket $S3_BUCKET"
    aws s3 mb "s3://$S3_BUCKET" --region "$AWS_REGION"
else
    echo "S3 bucket $S3_BUCKET already exists"
fi

# Upload the zip file to S3
aws s3 cp service_monitor.zip "s3://$S3_BUCKET/$LAMBDA_KEY"

# Change back to the original directory
cd -

# Clean up the temporary directory
rm -rf "$TEMP_DIR"

# Deploy the CloudFormation stack
aws cloudformation deploy \
    --template-file "$MAIN_TEMPLATE_FILE" \
    --stack-name "$STACK_NAME" \
    --capabilities CAPABILITY_IAM \
    --parameter-overrides \
        LambdaCodeS3Bucket="$S3_BUCKET" \
        LambdaCodeS3Key="$LAMBDA_KEY" \
        EmailAddress="$EMAIL_ADDRESS" \
        MonitoringIntervalMinutes=60 \
    --region "$AWS_REGION"

echo "Deployment complete!"