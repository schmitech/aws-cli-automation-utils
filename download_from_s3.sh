#!/bin/bash

# Function to display usage information
show_help() {
    echo "Usage: $0 <profile-name> <bucket-name> <source-folder>"
    echo
    echo "Download S3 folder contents and create a zip file"
    echo
    echo "Arguments:"
    echo "  profile-name         AWS Profile Name"
    echo "  bucket-name          S3 Bucket Name"
    echo "  source-folder        S3 folder path to download"
    echo
    echo "Example:"
    echo "  $0 dev-profile my-bucket path/to/folder"
    echo
    echo "Output:"
    echo "  Creates a zip file named after the downloaded folder in the current directory"
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
S3_FOLDER="$3"

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
echo "Downloading from s3://$S3_BUCKET/$S3_FOLDER"
aws s3 cp "s3://$S3_BUCKET/$S3_FOLDER" "$temp_dir" --recursive --profile "$PROFILE_NAME"

# Check if the download was successful
if [ $? -ne 0 ]; then
    echo "Download failed. Please check your AWS credentials and permissions."
    rm -rf "$temp_dir"
    exit 1
fi

# Create zip file
zip_name="$(basename "$S3_FOLDER").zip"
echo "Creating $zip_name in $current_dir"

# Change to temp directory before zipping
cd "$temp_dir" || exit 1
zip -r "$current_dir/$zip_name" .

# Go back to original directory
cd "$current_dir" || exit 1

# Cleanup
rm -rf "$temp_dir"
echo "Done! Created $zip_name in current directory"