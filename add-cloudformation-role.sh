#!/bin/bash

# Description:
#
# This script creates an IAM role specifically for AWS CloudFormation execution
# with CDK. It creates the role with the exact name format required by CDK and
# attaches administrator permissions to enable full stack deployment capabilities.
#
# Usage:
# ./add-cloudformation-role.sh <aws-profile> <account-id> [region]
#
# Parameters:
# - aws-profile: AWS CLI profile to use for authentication
# - account-id: AWS account ID where the role will be created
# - region: Optional. AWS region (defaults to ca-central-1)
#
# Example:
# ./add-cloudformation-role.sh myprofile 561675551936 ca-central-1
#
# Role Configuration:
# - Name Format: cdk-xxx123yyy-cfn-exec-role-{account-id}-{region}
# - Trust Relationship: CloudFormation service
# - Attached Policy: AdministratorAccess
#
# Requirements:
# - AWS CLI installed
# - Valid AWS profile with IAM permissions
# - Permissions to create roles and attach policies
#
# Exit Codes:
# - 0: Success (role created and policy attached)
# - 1: Error (missing parameters, role creation failure, policy attachment failure)
#
# Note:
# This script creates a role with administrative permissions.
# Ensure this aligns with your security requirements.

# Check if required arguments are provided
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <aws-profile> <account-id> [region]"
    echo "Example: $0 my-sso-profile 1234567 ca-central-1"
    exit 1
fi

# Assign arguments to variables
AWS_PROFILE=$1
ACCOUNT_ID=$2
REGION=${3:-ca-central-1}  # Default to ca-central-1 if not provided

# Role name format used by CDK
ROLE_NAME="cdk-lhb533kdx-cfn-exec-role-${ACCOUNT_ID}-${REGION}"

echo "Creating CloudFormation execution role: $ROLE_NAME"
echo "Using AWS Profile: $AWS_PROFILE"

# Create the IAM role
aws iam create-role \
    --profile "$AWS_PROFILE" \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": {
                "Service": "cloudformation.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }]
    }' || {
        echo "Failed to create role"
        exit 1
    }

# Attach necessary permissions
aws iam attach-role-policy \
    --profile "$AWS_PROFILE" \
    --role-name "$ROLE_NAME" \
    --policy-arn arn:aws:iam::aws:policy/AdministratorAccess || {
        echo "Failed to attach policy"
        exit 1
    }

echo "Successfully created role: $ROLE_NAME"