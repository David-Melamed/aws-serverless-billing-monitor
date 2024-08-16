#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status.

# Source the variables from the external file
source "$(dirname "$0")/variables.env"

API_ENDPOINT=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='ApiEndpoint'].OutputValue" --output text)

curl -X POST $API_ENDPOINT