#!/bin/bash

# Input file containing the CDK deploy output
input_file="deployment_output.out"

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