#!/bin/bash

# Description:
# This script registers an EC2 instance with an Application Load Balancer (ALB) target group
# and monitors the health status until the instance becomes healthy or times out.
#
# Usage:
# ./register-target.sh <aws_profile> <target_group_arn> <instance_id> <port>
#
# Parameters:
# - aws_profile      : AWS CLI profile name for authentication
# - target_group_arn : ARN of the target group to register with
# - instance_id      : EC2 instance ID to register
# - port            : Port number the instance will receive traffic on
#
# Example:
# ./register-target.sh myprofile \
#   arn:aws:elasticloadbalancing:region:account:targetgroup/name/1234567890 \
#   i-0123456789abcdef0 8080
#
# Exit Codes:
# - 0: Success - Instance registered and healthy
# - 1: Error - Various failure conditions (invalid input, registration failed, unhealthy)
#
# Requirements:
# - AWS CLI with appropriate permissions
# - jq installed for JSON processing
# - Permissions to describe and modify target groups
# - Permissions to describe EC2 instances

# Function to check if a value is a valid positive integer
is_positive_integer() {
    [[ $1 =~ ^[0-9]+$ ]] && [ "$1" -gt 0 ] && [ "$1" -le 65535 ]
}

# Function to wait for target health check
wait_for_target_health() {
    local profile=$1
    local tg_arn=$2
    local instance_id=$3
    local port=$4
    local max_attempts=30  # 5 minutes total (30 * 10 seconds)
    local attempt=1

    echo "Waiting for target to become healthy..."
    while [ $attempt -le $max_attempts ]; do
        health_state=$(aws elbv2 describe-target-health \
            --profile "$profile" \
            --target-group-arn "$tg_arn" \
            --targets "Id=$instance_id,Port=$port" | \
            jq -r '.TargetHealthDescriptions[0].TargetHealth.State')

        echo "Current health state: $health_state (Attempt $attempt of $max_attempts)"

        if [ "$health_state" == "healthy" ]; then
            echo "Target is now healthy!"
            return 0
        elif [ "$health_state" == "unhealthy" ]; then
            # Get detailed health description
            health_detail=$(aws elbv2 describe-target-health \
                --profile "$profile" \
                --target-group-arn "$tg_arn" \
                --targets "Id=$instance_id,Port=$port" | \
                jq -r '.TargetHealthDescriptions[0].TargetHealth.Description')
            echo "Target is unhealthy. Reason: $health_detail"
            return 1
        elif [ "$health_state" == "draining" ]; then
            echo "Target is draining. This is unexpected for a newly registered instance."
            return 1
        fi

        sleep 10
        ((attempt++))
    done

    echo "Timeout waiting for target to become healthy"
    return 1
}

# Function to validate target group exists
validate_target_group() {
    local profile=$1
    local tg_arn=$2

    if ! aws elbv2 describe-target-groups \
        --profile "$profile" \
        --target-group-arns "$tg_arn" >/dev/null 2>&1; then
        echo "Error: Target group not found or not accessible"
        return 1
    fi
    return 0
}

# Function to validate instance exists and is running
validate_instance() {
    local profile=$1
    local instance_id=$2

    instance_state=$(aws ec2 describe-instances \
        --profile "$profile" \
        --instance-ids "$instance_id" \
        --query 'Reservations[0].Instances[0].State.Name' \
        --output text 2>/dev/null)

    if [ $? -ne 0 ]; then
        echo "Error: Instance not found or not accessible"
        return 1
    elif [ "$instance_state" != "running" ]; then
        echo "Error: Instance is not in 'running' state (Current state: $instance_state)"
        return 1
    fi
    return 0
}

# Check if all required arguments are provided
if [ $# -lt 4 ]; then
    echo "Usage: $0 <aws_profile> <target_group_arn> <instance_id> <port>"
    echo "Example: $0 1234567 arn:aws:elasticloadbalancing:region:account:targetgroup/name/1234567890 i-0123456789abcdef0 8080"
    echo ""
    echo "Parameters:"
    echo "  aws_profile       : AWS profile to use for the operation"
    echo "  target_group_arn  : ARN of the target group"
    echo "  instance_id       : ID of the EC2 instance to register"
    echo "  port             : Port number (1-65535) on which the instance will receive traffic"
    exit 1
fi

# Store the arguments
aws_profile=$1
target_group_arn=$2
instance_id=$3
port=$4

# Validate AWS profile
if ! aws sts get-caller-identity --profile "$aws_profile" >/dev/null 2>&1; then
    echo "Error: Invalid or unauthorized AWS profile"
    exit 1
fi

# Validate instance ID format
if [[ ! $instance_id =~ ^i-[a-zA-Z0-9]+$ ]]; then
    echo "Error: Invalid instance ID format. It should start with 'i-' followed by alphanumeric characters"
    exit 1
fi

# Validate port number
if ! is_positive_integer "$port"; then
    echo "Error: Invalid port number. Must be between 1 and 65535"
    exit 1
fi

# Validate ARN format (basic validation)
if [[ ! $target_group_arn =~ ^arn:aws:elasticloadbalancing:.+:targetgroup/.+ ]]; then
    echo "Error: Invalid target group ARN format"
    exit 1
fi

# Validate target group exists
echo "Validating target group..."
if ! validate_target_group "$aws_profile" "$target_group_arn"; then
    exit 1
fi

# Validate instance exists and is running
echo "Validating instance..."
if ! validate_instance "$aws_profile" "$instance_id"; then
    exit 1
fi

# Register the instance
echo "Registering instance $instance_id in target group on port $port..."
if ! aws elbv2 register-targets \
    --profile "$aws_profile" \
    --target-group-arn "$target_group_arn" \
    --targets "Id=$instance_id,Port=$port"; then
    echo "Error: Failed to register instance"
    exit 1
fi

echo "Registration request successful"

# Wait for target to become healthy
if wait_for_target_health "$aws_profile" "$target_group_arn" "$instance_id" "$port"; then
    # Show final target details
    echo -e "\nFinal target details:"
    aws elbv2 describe-target-health \
        --profile "$aws_profile" \
        --target-group-arn "$target_group_arn" \
        --targets "Id=$instance_id,Port=$port" | \
        jq -r '.TargetHealthDescriptions[] | {
            "Instance ID": .Target.Id,
            "Port": .Target.Port,
            "State": .TargetHealth.State,
            "Description": .TargetHealth.Description,
            "Reason": .TargetHealth.Reason
        }'
else
    echo "Warning: Target registration completed but target did not become healthy"
    exit 1
fi