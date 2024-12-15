#!/bin/bash

# Description:
#
# This script downloads all contents from an AWS S3 bucket and creates a local zip archive.
# It handles the downloading process safely using a temporary directory and includes
# error checking at each step.
#
# Usage:
# ./download_from_s3.sh <profile-name> <bucket-name>
# 
# Parameters:
# - profile-name: AWS CLI profile to use for authentication
# - bucket-name: Name of the S3 bucket to download
#
# Example:
# ./download_from_s3.sh dev-profile my-bucket
#
# Process Flow:
# 1. Creates a temporary directory for downloads
# 2. Downloads all files from the specified S3 bucket
# 3. Creates a zip archive of all downloaded files
# 4. Places the zip file in the current directory
# 5. Cleans up temporary files
#
# Output:
# - Creates a zip file named <bucket-name>.zip in the current directory
#
# Requirements:
# - AWS CLI installed and configured
# - zip command-line utility installed
# - Appropriate AWS permissions to access the S3 bucket
# - Sufficient local disk space for downloads
#
# Exit Codes:
# - 0: Success
# - 1: Error (missing dependencies, invalid arguments, download failure)

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