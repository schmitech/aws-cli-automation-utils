#!/bin/bash

# Function to display usage information
show_help() {
    echo "Usage: $0 <profile-name>"
    echo
    echo "List EC2 instances with their basic information"
    echo
    echo "Arguments:"
    echo "  profile-name     AWS Profile Name"
    echo
    echo "Example:"
    echo "  $0 dev-profile"
    echo
    echo "Output displays:"
    echo "  - Instance Name"
    echo "  - Instance ID"
    echo "  - Instance State"
    echo "  - Instance Type"
    echo "  - Private IP Address"
    echo "  - Availability Zone"
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
PROFILE="$1"

# Ensure AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed. Please install it first." >&2
    exit 1
fi

# Print current profile and date
echo "AWS Profile: $PROFILE"
echo "Date: $(date)"
echo

# List instances with basic information
echo "EC2 Instances Summary:"
echo "--------------------"
aws ec2 describe-instances \
    --query 'Reservations[*].Instances[*].[Tags[?Key==`Name`].Value | [0], InstanceId, State.Name, InstanceType, PrivateIpAddress, Placement.AvailabilityZone]' \
    --output table \
    --profile "$PROFILE"

# Check for errors
if [ $? -ne 0 ]; then
    echo "Error: Failed to retrieve instance information. Please check your AWS profile and permissions." >&2
    exit 1
fi