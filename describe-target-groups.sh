#!/bin/bash

# Description:
# This script queries AWS Elastic Load Balancer v2 (ELBv2) target groups and provides detailed information
# about matching target groups and their registered instances. It supports searching for multiple target
# groups simultaneously using case-insensitive pattern matching.
#
# Features:
# - Searches target groups based on one or more search terms
# - Shows target group details including name, ARN, port, protocol, and VPC ID
# - Lists all registered instances for each target group
# - Displays instance health status and port configuration
# - Retrieves and includes instance names from EC2 tags
#
# Usage:
# ./describe-target-groups.sh <aws_profile> <search_term1> [search_term2] [search_term3] ...
#
# Parameters:
# - aws_profile: AWS CLI profile name to use for authentication
# - search_terms: One or more terms to filter target groups (case-insensitive)
#
# Example:
# ./describe-target-groups.sh myprofile webapp database
#
# Output Format:
# - JSON array containing matching target groups
# - Each target group includes:
#   * Target Group Name
#   * Target Group ARN
#   * Port
#   * Protocol
#   * VPC ID
#   * Target Type
#   * List of registered instances with:
#     - Instance ID
#     - Port
#     - Health State
#     - Health Description
#     - Instance Name (from EC2 tags)
#
# Requirements:
# - AWS CLI configured with appropriate permissions
# - jq installed for JSON processing
# - Permissions to describe target groups and EC2 instances

# Check if at least two arguments are provided (profile and one search term)
if [ $# -lt 2 ]; then
    echo "Usage: $0 <aws_profile> <search_term1> [search_term2] [search_term3] ..."
    echo "Example: $0 1234567 instance1 instance2"
    exit 1
fi

# Store the AWS profile and remove it from the arguments list
aws_profile=$1
shift

# Function to get instance name from tags
get_instance_name() {
    local profile=$1
    local instance_id=$2
    aws ec2 describe-tags \
        --profile "$profile" \
        --filters "Name=resource-id,Values=$instance_id" "Name=key,Values=Name" \
        --query 'Tags[0].Value' \
        --output text 2>/dev/null || echo "N/A"
}

echo "Fetching target groups matching: $@"

# Create search pattern for multiple terms
search_pattern=$(printf "|%s" "$@")
search_pattern=${search_pattern:1}  # Remove leading |

# Get all matching target groups and their details in one go
aws elbv2 describe-target-groups --profile "$aws_profile" | \
jq --arg pattern "$search_pattern" -r '
[
  .TargetGroups[] | 
  select(.TargetGroupName | test($pattern;"i")) | 
  {
    "Target Group Name": .TargetGroupName,
    "Target Group ARN": .TargetGroupArn,
    "Port": .Port,
    "Protocol": .Protocol,
    "VPC ID": .VpcId,
    "Target Type": .TargetType,
    "Registered Instances": []
  }
]' > target_groups.json

# Exit if no target groups found
if [ ! -s target_groups.json ] || [ "$(cat target_groups.json)" = "[]" ]; then
    echo "No matching target groups found."
    rm target_groups.json
    exit 0
fi

# Process each target group and add instance information
jq -c '.[]' target_groups.json | while read -r group; do
    tg_arn=$(echo "$group" | jq -r '."Target Group ARN"')
    
    # Get instance health information
    instances=$(aws elbv2 describe-target-health \
        --profile "$aws_profile" \
        --target-group-arn "$tg_arn" 2>/dev/null)
    
    if [ -n "$instances" ]; then
        # Process each instance and add instance name
        instances_with_names=$(echo "$instances" | jq -r '.TargetHealthDescriptions[] | {
            "Instance ID": .Target.Id,
            "Port": .Target.Port,
            "Health State": .TargetHealth.State,
            "Health Description": .TargetHealth.Description,
            "Instance Name": "pending"
        }' | jq -c '.')
        
        # Add instance names
        instances_array="[]"
        while IFS= read -r instance; do
            instance_id=$(echo "$instance" | jq -r '."Instance ID"')
            instance_name=$(get_instance_name "$aws_profile" "$instance_id")
            instance_with_name=$(echo "$instance" | jq --arg name "$instance_name" '. + {"Instance Name": $name}')
            instances_array=$(echo "$instances_array" | jq --argjson inst "$instance_with_name" '. + [$inst]')
        done < <(echo "$instances_with_names")
        
        # Update the group with instances
        echo "$group" | jq --argjson insts "$instances_array" '. + {"Registered Instances": $insts}'
    else
        # No instances registered
        echo "$group"
    fi
done | jq -s '.' > result.json

# Output the final result and cleanup
cat result.json
rm target_groups.json result.json

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "Error: Failed to process target groups information."
    exit 1
fi