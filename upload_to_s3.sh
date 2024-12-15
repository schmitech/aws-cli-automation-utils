#!/bin/bash

# Description:
#
# This script uploads contents from a local directory to an AWS S3 bucket root.
# It provides a simple way to recursively copy local files while maintaining 
# the directory structure in S3.
#
# Features:
# - Recursive upload of all files and subdirectories
# - Maintains directory structure in S3
# - Validates input parameters and requirements
# - Reports upload success/failure status
#
# Usage:
# ./upload_to_s3.sh <profile-name> <bucket-name> <source-folder>
#
# Parameters:
# - profile-name : AWS CLI profile name for authentication
# - bucket-name  : Destination S3 bucket name
# - source-folder: Local directory path containing files to upload
#
# Example:
# ./upload_to_s3.sh dev-profile my-bucket /path/to/local/folder
#
# Pre-upload Checks:
# - Validates presence of AWS CLI
# - Verifies local folder exists
# - Confirms all required parameters are provided
#
# Requirements:
# - AWS CLI installed and configured
# - Valid AWS profile with S3 upload permissions
# - Existing source directory with read permissions
#
# Exit Codes:
# - 0: Success (upload completed successfully)
# - 1: Error (missing dependencies, invalid arguments, upload failure)
#
# Note:
# The script uploads to the root of the S3 bucket while preserving
# the directory structure from the source folder

# Function to display usage information
show_help() {
    echo "Usage: $0 <profile-name> <bucket-name> <source-folder>"
    echo
    echo "Upload local folder contents to S3 bucket root using specified AWS profile"
    echo
    echo "Arguments:"
    echo "  profile-name         AWS Profile Name"
    echo "  bucket-name          S3 Bucket Name"
    echo "  source-folder        Local folder path to upload"
    echo
    echo "Example:"
    echo "  $0 dev-profile my-bucket /path/to/local/folder"
}

# Show help if requested
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
    exit 0
fi

# Check if all arguments are provided
if [ $# -ne 3 ]; then
    echo "Error: All arguments are required" >&2
    show_help
    exit 1
fi

# Set variables from arguments
PROFILE_NAME="$1"
S3_BUCKET="$2"
LOCAL_FOLDER="$3"

# Ensure AWS CLI is installed and configured
if ! command -v aws &> /dev/null; then
    echo "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if the local folder exists
if [ ! -d "$LOCAL_FOLDER" ]; then
    echo "Local folder does not exist: $LOCAL_FOLDER"
    exit 1
fi

# Upload the contents of the folder to S3 bucket root
echo "Uploading contents of $LOCAL_FOLDER to s3://$S3_BUCKET/"
aws s3 cp "$LOCAL_FOLDER/" "s3://$S3_BUCKET/" --recursive --profile "$PROFILE_NAME"

# Check if the upload was successful
if [ $? -eq 0 ]; then
    echo "Upload completed successfully!"
else
    echo "Upload failed. Please check your AWS credentials and permissions."
fi