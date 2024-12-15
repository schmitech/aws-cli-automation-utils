#!/bin/bash

# Description:
#
# This script performs a complete cleanup of AWS CDK resources, including the stack,
# CDK toolkit, local files, and provides guidance for manual S3 bucket cleanup.
# It ensures a thorough removal of all CDK-related resources to prevent lingering
# costs and resources.
#
# Usage:
# ./cdk-destroy.sh <profile-name>
#
# Parameters:
# - profile-name: AWS CLI profile to use for authentication
#
# Example:
# ./cdk-destroy.sh dev-profile
#
# Cleanup Process:
# 1. Destroys the CDK application stack
# 2. Removes the CDKToolkit CloudFormation stack
# 3. Clears local CDK context
# 4. Removes local CDK files:
#    - cdk.context.json
#    - cdk.out directory
#    - deployment logs
#    - instance information files
# 5. Provides instructions for S3 bucket cleanup
#
# Requirements:
# - AWS CDK CLI installed
# - AWS CLI installed
# - Valid AWS profile with deletion permissions
# - ec2-config.yaml file in current directory
# - Optional: yq tool for YAML parsing
#
# Exit Codes:
# - 0: Success (cleanup completed)
# - 1: Error (missing dependencies, invalid profile, cleanup failure)
#
# Safety Features:
# - Exits on first error (set -e)
# - Validates required tools before proceeding
# - Checks for config file existence
#
# Note:
# Manual cleanup of the S3 bootstrap bucket is required through
# the AWS Console to ensure complete resource removal

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
    BUCKET_NAME=$(yq -r '.common.bootstrap_s3_bucket_name' ec2-config.yaml)
fi

echo "CDK stack destroyed, CDKToolkit stack deleted, local context removed."
echo -e "${YELLOW}Please go to AWS S3 Console and manually empty and delete bucket named '$BUCKET_NAME'.${NC}"