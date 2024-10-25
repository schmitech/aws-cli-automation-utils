#!/bin/bash

# Function to display usage information
show_help() {
    echo "Usage: $0 <account-id> <profile-name>"
    echo
    echo "Bootstrap AWS CDK in the specified account using the provided profile"
    echo
    echo "Arguments:"
    echo "  account-id       AWS Account ID"
    echo "  profile-name     AWS Profile Name"
    echo
    echo "Example:"
    echo "  $0 123456789012 dev-profile"
}

# Show help if requested
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
    exit 0
fi

# Check if both arguments are provided
if [ $# -ne 2 ]; then
    echo "Error: Both account ID and profile name are required" >&2
    show_help
    exit 1
fi

# Read bootstrap bucket name from YAML
config_file="ec2-config.yaml"
if [ ! -f "$config_file" ]; then
    echo "Error: Configuration file $config_file not found" >&2
    exit 1
fi

if ! command -v yq &> /dev/null; then
    echo "Error: yq is required but not installed. Please install yq first." >&2
    echo "Installation instructions: https://github.com/mikefarah/yq#install" >&2
    exit 1
fi

bootstrap_bucket=$(yq eval '.common.bootstrap_s3_bucket_name' "$config_file")
if [ "$bootstrap_bucket" = "null" ] || [ -z "$bootstrap_bucket" ]; then
    echo "Error: Failed to read bootstrap bucket name from config file" >&2
    exit 1
fi

account_id="$1"
profile_name="$2"

# Execute CDK bootstrap command
cdk bootstrap \
    --cloudformation-execution-policies arn:aws:iam::aws:policy/AdministratorAccess \
    "aws://${account_id}/ca-central-1" \
    --profile "${profile_name}" \
    --bootstrap-bucket-name "${bootstrap_bucket}"