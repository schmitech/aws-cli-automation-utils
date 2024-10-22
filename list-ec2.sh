#!/bin/bash

# Check if profile parameter is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <aws-profile>"
    echo "Example: $0 AdministratorAccess-1234567"
    exit 1
fi

PROFILE=$1

# Print current profile and date
echo "AWS Profile: $PROFILE"
echo "Date: $(date)"
echo ""

# List instances with basic information
echo "EC2 Instances Summary:"
echo "--------------------"
aws ec2 describe-instances --query 'Reservations[*].Instances[*].[Tags[?Key==`Name`].Value | [0], InstanceId, State.Name, InstanceType, PrivateIpAddress]' --output table --profile "$PROFILE"

# Optional: Add error handling
if [ $? -ne 0 ]; then
    echo "Error: Failed to retrieve instance information. Please check your AWS profile and permissions."
    exit 1
fi