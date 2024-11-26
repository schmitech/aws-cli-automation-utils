#!/bin/bash

# Check if required arguments are provided
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <aws-profile> <account-id> [region]"
    echo "Example: $0 myprofile 561675551936 ca-central-1"
    exit 1
fi

# Assign arguments to variables
AWS_PROFILE=$1
ACCOUNT_ID=$2
REGION=${3:-ca-central-1}  # Default to ca-central-1 if not provided

# Role name format used by CDK
ROLE_NAME="cdk-hnb659fds-cfn-exec-role-${ACCOUNT_ID}-${REGION}"

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
echo "You can now retry your CloudFormation operation"