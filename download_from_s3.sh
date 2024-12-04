#!/bin/bash

# Function to display usage information
show_help() {
    echo "Usage: $0 <profile-name> <bucket-name>"
    echo
    echo "Download all S3 bucket contents and create a zip file"
    echo
    echo "Arguments:"
    echo "  profile-name         AWS Profile Name"
    echo "  bucket-name          S3 Bucket Name"
    echo
    echo "Example:"
    echo "  $0 dev-profile my-bucket"
    echo
    echo "Output:"
    echo "  Creates a zip file named after the bucket in the current directory"
}

# Show help if requested
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
    exit 0
fi

# Check if all arguments are provided
if [ $# -ne 2 ]; then
    echo "Error: All arguments are required" >&2
    show_help
    exit 1
fi

# Set variables from arguments
PROFILE_NAME="$1"
S3_BUCKET="$2"

# Ensure AWS CLI is installed and configured
if ! command -v aws &> /dev/null; then
    echo "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Ensure zip is installed
if ! command -v zip &> /dev/null; then
    echo "zip is not installed. Please install it first."
    exit 1
fi

# Store the current directory
current_dir=$(pwd)

# Create temporary directory
temp_dir=$(mktemp -d)
echo "Created temporary directory: $temp_dir"

# Download files
echo "Downloading from s3://$S3_BUCKET"
aws s3 cp "s3://$S3_BUCKET" "$temp_dir" --recursive --profile "$PROFILE_NAME"

# Check if the download was successful
if [ $? -ne 0 ]; then
    echo "Download failed. Please check your AWS credentials and permissions."
    rm -rf "$temp_dir"
    exit 1
fi

# Create zip file
zip_name="$S3_BUCKET.zip"
echo "Creating $zip_name in $current_dir"

# Change to temp directory before zipping
cd "$temp_dir" || exit 1
zip -r "$current_dir/$zip_name" .

# Go back to original directory
cd "$current_dir" || exit 1

# Cleanup
rm -rf "$temp_dir"
echo "Done! Created $zip_name in current directory"