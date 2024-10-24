#!/bin/bash

if [ $# -lt 1 ]; then
    echo "Usage: $0 <input_file>"
    echo "Example: $0 deployment_output.out"
    exit 1
fi

# Input file containing the CDK deploy output
input_file="$1"

# Check if input file exists
if [ ! -f "$input_file" ]; then
    echo "Error: Input file '$input_file' not found"
    exit 1
fi

# Output file to store the extracted JSON
output_file="instance_info.json"

# Temporary file for intermediate processing
temp_file="temp_json.json"

# Extract the JSON payload
sed 's/\x1b\[[0-9;]*m//g' "$input_file" |  # Remove ANSI color codes
sed -n '/Ec2Stack\.InstanceInfo = {/,/^}/p' | # Extract lines from start to end of JSON
sed '1s/^.*Ec2Stack\.InstanceInfo = //' | # Remove everything before the opening '{'
sed '$s/}$/}/' | # Ensure the last line only contains '}'
tr -d '\n' |  # Remove newlines
sed 's/}/}\n/' | # Add a newline after the closing '}'
sed 's/  */ /g' > "$temp_file" # Replace multiple spaces with a single space

# Use Python to pretty-print the JSON and save to the output file
python3 -c "
import json
import sys

with open('$temp_file', 'r') as f:
    data = json.load(f)

with open('$output_file', 'w') as f:
    json.dump(data, f, indent=2)
"

# Remove the temporary file
rm "$temp_file"

echo "JSON with instance details saved to $output_file"