#!/bin/bash

# Check if profile argument is provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 <aws_profile>"
    echo "Example: $0 1234567"
    exit 1
fi

# Store the AWS profile
aws_profile=$1

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