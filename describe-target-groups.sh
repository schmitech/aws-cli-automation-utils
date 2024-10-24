#!/bin/bash

# Check if at least two arguments are provided (profile and one search term)
if [ $# -lt 2 ]; then
    echo "Usage: $0 <aws_profile> <search_term1> [search_term2] [search_term3] ..."
    echo "Example: $0 1234567 couchbase gateway innova"
    exit 1
fi

# Store the AWS profile and remove it from the arguments list
aws_profile=$1
shift

# Build the jq filter for multiple search terms
jq_filter='.TargetGroups[] | select('

# Loop through remaining arguments to build the regex pattern
first_term=true
for term in "$@"; do
    if $first_term; then
        jq_filter+="(.TargetGroupName | test(\"$term\"; \"i\"))"
        first_term=false
    else
        jq_filter+=" or (.TargetGroupName | test(\"$term\"; \"i\"))"
    fi
done

# Complete the jq filter to include desired fields
jq_filter="$jq_filter) | {\"Target Group Name\": .TargetGroupName, \"Port\": .Port, \"Protocol\": .Protocol, \"VPC ID\": .VpcId, \"Target Type\": .TargetType}"

# Run the AWS command with the profile and constructed filter
echo "Fetching target groups matching: $@"
aws elbv2 describe-target-groups --profile "$aws_profile" | jq "$jq_filter"

# Check if the AWS command was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to retrieve target groups. Please check your AWS profile and permissions."
    exit 1
fi