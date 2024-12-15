#!/bin/bash

# Description:
# This script lists all EC2 instances and their key attributes in a tabular format
# using the specified AWS profile. It provides a quick overview of running instances
# and their configuration.
#
# Features:
# - Displays EC2 instances in an easy-to-read table format
# - Shows key instance attributes including name, ID, and status
# - Includes execution timestamp and profile information
# - Validates AWS CLI installation and profile usage
#
# Usage:
# ./list-ec2.sh <profile-name>
#
# Parameters:
# - profile-name: AWS CLI profile to use for authentication
#
# Example:
# ./list-ec2.sh dev-profile
#
# Output Fields:
# - Instance Name (from Name tag)
# - Instance ID
# - Instance State (running, stopped, etc.)
# - Instance Type (e.g., t2.micro, t3.large)
# - Private IP Address
# - Availability Zone
#
# Requirements:
# - AWS CLI installed
# - Valid AWS profile with EC2 describe permissions
#
# Exit Codes:
# - 0: Success
# - 1: Error (missing AWS CLI, invalid profile, insufficient permissions)
#
# Note:
# The script uses AWS CLI's built-in query and table formatting
# to provide a clean, readable output of instance information

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