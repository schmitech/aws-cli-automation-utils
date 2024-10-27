#!/bin/bash

# Function to display usage information
show_help() {
    echo "Usage: $0 <profile-name> <bucket-name> <source-folder> <destination-folder>"
    echo
    echo "Upload local folder contents to S3 using specified AWS profile"
    echo
    echo "Arguments:"
    echo "  profile-name         AWS Profile Name"
    echo "  bucket-name          S3 Bucket Name"
    echo "  source-folder        Local folder path to upload"
    echo "  destination-folder   S3 destination folder (prefix)"
    echo
    echo "Example:"
    echo "  $0 dev-profile my-bucket /path/to/local/folder remote/folder/"
}

# Show help if requested
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
    exit 0
fi

# Check if all arguments are provided
if [ $# -ne 4 ]; then
    echo "Error: All arguments are required" >&2
    show_help
    exit 1
fi

# Set variables from arguments
PROFILE_NAME="$1"
S3_BUCKET="$2"
LOCAL_FOLDER="$3"
S3_PREFIX="$4"

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

# Upload the folder to S3
echo "Uploading $LOCAL_FOLDER to s3://$S3_BUCKET/$S3_PREFIX"
aws s3 cp "$LOCAL_FOLDER" "s3://$S3_BUCKET/$S3_PREFIX" --recursive --profile "$PROFILE_NAME"

# Check if the upload was successful
if [ $? -eq 0 ]; then
    echo "Upload completed successfully!"
else
    echo "Upload failed. Please check your AWS credentials and permissions."
fi