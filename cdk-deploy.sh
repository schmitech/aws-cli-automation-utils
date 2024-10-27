#!/bin/bash

# Function to display usage information
show_help() {
    echo "Usage: $0 <profile-name>"
    echo
    echo "Deploy CDK stack using specified AWS profile"
    echo
    echo "Arguments:"
    echo "  profile-name     AWS Profile Name"
    echo
    echo "Example:"
    echo "  $0 dev-profile"
    echo
    echo "Output:"
    echo "  Creates a log file with timestamp in the current directory"
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
aws_profile="$1"

# Ensure CDK is installed
if ! command -v cdk &> /dev/null; then
    echo "Error: CDK is not installed. Please install it first."
    exit 1
fi

# Create timestamp for unique log filename
timestamp=$(date +"%Y%m%d_%H%M%S")
logfile="deployment_${timestamp}.out"

# Run the CDK deploy command and capture output
echo "Starting CDK deployment with profile ${aws_profile}"
echo "Logging output to: ${logfile}"

script -c "cdk deploy --require-approval broadening --profile ${aws_profile}" "${logfile}"

# Check if the command was successful
if [ $? -ne 0 ]; then
    echo "Error: CDK deployment failed. Check ${logfile} for details."
    exit 1
else
    echo "Deployment completed. Output saved to: ${logfile}"
fi