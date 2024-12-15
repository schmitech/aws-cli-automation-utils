#!/bin/bash

# Description:
#
# This script bootstraps AWS CDK in a specified AWS account. It reads configuration
# from a YAML file and sets up the necessary resources for CDK deployment, including
# a custom bootstrap bucket name. The bootstrap process creates the foundational
# resources needed for CDK operations.
#
# Usage:
# ./cdk-bootstrap.sh <profile-name>
#
# Parameters:
# - profile-name: AWS CLI profile to use for authentication
#
# Example:
# ./cdk-bootstrap.sh dev-profile
#
# Requirements:
# - AWS CDK CLI installed
# - yq installed (pip install yq)
# - Valid AWS profile with bootstrap permissions
# - ec2-config.yaml file in current directory
#
# Exit Codes:
# - 0: Success (bootstrap completed)
# - 1: Error (missing dependencies, invalid config, bootstrap failure)
#
# Note:
# The bootstrap process uses AdministratorAccess policy for
# CloudFormation execution to ensure full functionality

# Function to display usage information
show_help() {
    echo "Usage: $0 <profile-name>"
    echo
    echo "Bootstrap AWS CDK in the specified account using the provided profile"
    echo
    echo "Arguments:"
    echo "  profile-name     AWS Profile Name"
    echo
    echo "Example:"
    echo "  $0 dev-profile"
    echo
    echo "Note: Account ID and bootstrap bucket name are read from ec2-config.yaml"
}

# Show help if requested
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
    exit 0
fi

# Check if profile argument is provided
if [ $# -ne 1 ]; then
    echo "Error: Profile name is required" >&2
    show_help
    exit 1
fi

profile_name="$1"

# Read configuration from YAML
config_file="ec2-config.yaml"
if [ ! -f "$config_file" ]; then
    echo "Error: Configuration file $config_file not found" >&2
    exit 1
fi

if ! command -v yq &> /dev/null; then
    echo "Error: yq is required but not installed. Please install yq first." >&2
    echo "Installation instructions: pip install yq" >&2
    exit 1
fi

# Read account ID and bootstrap bucket from config using pip version of yq
account_id=$(yq -r '.common.account' "$config_file")
bootstrap_bucket=$(yq -r '.common.bootstrap_s3_bucket_name' "$config_file")

# Validate account ID
if [ "$account_id" = "null" ] || [ -z "$account_id" ]; then
    echo "Error: Failed to read account ID from config file" >&2
    exit 1
fi

# Validate bootstrap bucket
if [ "$bootstrap_bucket" = "null" ] || [ -z "$bootstrap_bucket" ]; then
    echo "Error: Failed to read bootstrap bucket name from config file" >&2
    exit 1
fi

echo "Using configuration from $config_file:"
echo "  Account ID: $account_id"
echo "  Bootstrap Bucket: $bootstrap_bucket"
echo

# Execute CDK bootstrap command
cdk bootstrap \
    --cloudformation-execution-policies arn:aws:iam::aws:policy/AdministratorAccess \
    "aws://${account_id}/ca-central-1" \
    --profile "${profile_name}" \
    --bootstrap-bucket-name "${bootstrap_bucket}"