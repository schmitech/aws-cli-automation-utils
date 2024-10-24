#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status.

YELLOW='\033[1;33m'
NC='\033[0m'

# Check if a profile was provided
if [ $# -eq 0 ]; then
    echo "Please provide an AWS profile as an argument."
    echo "Usage: $0 <aws-profile>"
    exit 1
fi

# Store the AWS profile
AWS_PROFILE="$1"

# Function to run AWS CLI commands with proper error handling
run_aws_command() {
    if ! "$@"; then
        echo "Error executing: $*"
        exit 1
    fi
}

# Run CDK destroy with the profile
if ! cdk destroy --profile "$AWS_PROFILE"; then
    echo "CDK destroy failed. Proceeding with cleanup anyway."
fi

echo "Deleting CDKToolkit CloudFormation stack"
run_aws_command aws cloudformation delete-stack --stack-name CDKToolkit --profile "$AWS_PROFILE"

echo "Clearing CDK context"
cdk context --clear
rm -rf cdk.context.json cdk.out deployment*.out instance_info.json

# Get the bootstrap bucket name from your config
BUCKET_NAME=$(grep bootstrap_s3_bucket_name ec2-config.yaml | awk '{print $2}')

echo "CDK stack destroyed, CDKToolkit stack deleted, local context removed."
echo -e "${YELLOW}Please go to AWS S3 Console and manually empty and delete bucket named '$BUCKET_NAME'.${NC}"