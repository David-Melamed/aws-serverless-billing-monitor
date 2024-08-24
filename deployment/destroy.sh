#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status.

# Source the variables from the external file
source "$(dirname "$0")/variables.env"

# Check and remove S3 buckets
for bucket in $LAMBDA_CODE_S3_BUCKET_NAME $LAMBDA_ASSETS_S3_BUCKET_NAME $CONFIG_LOGS_BUCKET_NAME; do
    if aws s3 ls "s3://$bucket" --region "$AWS_REGION" &>/dev/null; then
        echo "Removing all files and versions from S3 bucket $bucket..."
        
        # Check if the bucket is versioned
        if aws s3api get-bucket-versioning --bucket "$bucket" --region "$AWS_REGION" | grep -q '"Status": "Enabled"'; then
            echo "Bucket $bucket is versioned. Deleting all object versions..."
            
            # Delete all versions of all objects
            aws s3api list-object-versions --bucket "$bucket" --region "$AWS_REGION" --query 'Versions[].{Key:Key,VersionId:VersionId}' --output text --page-size 1000 | \
            while read -r key version; do
                if [ -n "$key" ] && [ -n "$version" ]; then
                    aws s3api delete-object --bucket "$bucket" --key "$key" --version-id "$version" --region "$AWS_REGION"
                fi
            done
            
            # Delete all delete markers
            aws s3api list-object-versions --bucket "$bucket" --region "$AWS_REGION" --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' --output text --page-size 1000 | \
            while read -r key version; do
                if [ -n "$key" ] && [ -n "$version" ]; then
                    aws s3api delete-object --bucket "$bucket" --key "$key" --version-id "$version" --region "$AWS_REGION"
                fi
            done
        else
            # If the bucket is not versioned, just remove all files
            aws s3 rm "s3://$bucket" --recursive --region "$AWS_REGION"
        fi

        echo "Deleting S3 bucket $bucket..."
        aws s3 rb "s3://$bucket" --force --region "$AWS_REGION"
    else
        echo "Bucket $bucket does not exist, skipping..."
    fi
done

# Delete the CloudFormation stack
echo "Deleting CloudFormation stack $STACK_NAME..."
aws cloudformation delete-stack --stack-name "$STACK_NAME" --region "$AWS_REGION"

# Wait for the stack to be deleted
echo "Waiting for stack deletion to complete..."
aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME" --region "$AWS_REGION"

# Confirm stack deletion
if ! aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$AWS_REGION" &>/dev/null; then
    echo "Stack $STACK_NAME has been deleted successfully."
else
    echo "Error: Stack $STACK_NAME still exists or deletion failed."
fi

echo "Cleanup complete!"