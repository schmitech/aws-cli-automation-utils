#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status.

# Color definitions
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to display usage information
show_help() {
    echo "Usage: $0 <profile-name>"
    echo
    echo "Destroy CDK stack and clean up resources"
    echo
    echo "Arguments:"
    echo "  profile-name     AWS Profile Name"
    echo
    echo "Example:"
    echo "  $0 dev-profile"
    echo
    echo "Actions performed:"
    echo "  1. Destroys CDK stack"
    echo "  2. Deletes CDKToolkit CloudFormation stack"
    echo "  3. Clears CDK context"
    echo "  4. Removes local files (cdk.context.json, cdk.out, etc.)"
    echo "  5. Provides information about bootstrap bucket cleanup"
}

# Show help if requested
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
    exit 0
fi

# Check if profile argument is provided
if [ $# -ne 1 ]; then
    echo "Error: AWS profile name is required" >&2
    show_help
    exit 1
fi

# Store the AWS profile
AWS_PROFILE="$1"

# Ensure required tools are installed
if ! command -v cdk &> /dev/null; then
    echo "Error: CDK is not installed. Please install it first." >&2
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed. Please install it first." >&2
    exit 1
fi

# Function to run AWS CLI commands with proper error handling
run_aws_command() {
    if ! "$@"; then
        echo "Error executing: $*" >&2
        exit 1
    fi
}

# Check if config file exists
if [ ! -f "ec2-config.yaml" ]; then
    echo "Error: ec2-config.yaml not found in current directory" >&2
    exit 1
fi

echo "Starting CDK destroy process with profile: $AWS_PROFILE"

# Run CDK destroy with the profile
if ! cdk destroy --profile "$AWS_PROFILE"; then
    echo "Warning: CDK destroy failed. Proceeding with cleanup anyway." >&2
fi

echo "Deleting CDKToolkit CloudFormation stack"
run_aws_command aws cloudformation delete-stack --stack-name CDKToolkit --profile "$AWS_PROFILE"

echo "Clearing CDK context"
cdk context --clear
rm -rf cdk.context.json cdk.out deployment*.out instance_info.json

# Get the bootstrap bucket name from config
if ! command -v yq &> /dev/null; then
    BUCKET_NAME=$(grep bootstrap_s3_bucket_name ec2-config.yaml | awk '{print $2}')
else
    BUCKET_NAME=$(yq eval '.common.bootstrap_s3_bucket_name' ec2-config.yaml)
fi

echo "CDK stack destroyed, CDKToolkit stack deleted, local context removed."
echo -e "${YELLOW}Please go to AWS S3 Console and manually empty and delete bucket named '$BUCKET_NAME'.${NC}"