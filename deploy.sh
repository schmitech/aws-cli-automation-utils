#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 -u <git_username> -p <git_password>"
    echo "  -u    Git username"
    echo "  -p    Git password"
    exit 1
}

# Parse command line arguments
while getopts "u:p:" opt; do
    case $opt in
        u) GIT_USERNAME="$OPTARG" ;;
        p) GIT_PASSWORD="$OPTARG" ;;
        ?) usage ;;
    esac
done

# Check if required arguments are provided
if [ -z "$GIT_USERNAME" ] || [ -z "$GIT_PASSWORD" ]; then
    echo "Error: Missing required arguments"
    usage
fi

# Exit on any error
set -e

# Function to log steps
log_step() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Function to check if command succeeded
check_status() {
    if [ $? -eq 0 ]; then
        log_step "✓ $1 completed successfully"
    else
        log_step "✗ $1 failed"
        exit 1
    fi
}

# Function to run unit tests and validate results
run_unit_tests() {
    local test_file=$1
    local test_output_file="test_output_${test_file%.py}.txt"
    
    python -m unittest $test_file -v > "$test_output_file" 2>&1
    
    # Check for test failures or errors
    if grep -E "FAIL|ERROR" "$test_output_file" > /dev/null; then
        log_step "✗ Tests in $test_file failed. Details:"
        cat "$test_output_file"
        return 1
    else
        log_step "✓ All tests in $test_file passed"
        return 0
    fi
}

# 1. AWS SSM connection is assumed to be already established
# Script should be run after connecting to EC2 instance

# 2. Backup previous deployment
log_step "Backing up previous deployment"
backup_date=$(date '+%Y%m%d')
mv recreat-api recreat-api-${backup_date} 2>/dev/null || true
check_status "Backup"

# 3. Clone Repository
log_step "Cloning repository"
git clone "https://${GIT_USERNAME}:${GIT_PASSWORD}@dev.azure.com/project-devops/ReCREAT/_git/recreat-api"
check_status "Repository clone"

# 4. Setup Python environment
log_step "Setting up Python environment"
cd recreat-api
python3 -m venv venv
source venv/bin/activate
pip install --no-cache-dir -r requirements.txt
check_status "Python environment setup"

# 5. Run and validate unit tests
log_step "Running unit tests"
cd test
test_files=("test_api.py" "test_s3_utils.py" "test_data_reader.py")
tests_passed=true

for test_file in "${test_files[@]}"; do
    if ! run_unit_tests "$test_file"; then
        tests_passed=false
        break
    fi
done

cd ..

if [ "$tests_passed" = false ]; then
    log_step "✗ Unit tests failed - Stopping deployment"
    exit 1
fi

log_step "✓ All unit tests passed - Proceeding with deployment"

# 6 & 7. Stop existing container
log_step "Stopping existing container"
container_id=$(sudo docker ps --filter "publish=5000" --format "{{.ID}}")
if [ ! -z "$container_id" ]; then
    sudo docker stop $container_id
    check_status "Container stop"
fi

# 8 & 9. Remove existing image
log_step "Removing existing image"
image_id=$(sudo docker images --filter "reference=recreat-api" --format "{{.ID}}")
if [ ! -z "$image_id" ]; then
    sudo docker rmi -f $image_id
    check_status "Image removal"
fi

# 10. Prune docker system
log_step "Pruning docker system"
sudo docker system prune -f
check_status "Docker system prune"

# 11. Build new docker image
log_step "Building docker image"
sudo docker-compose build
check_status "Docker image build"

# 12. Deploy container
log_step "Deploying container"
sudo docker-compose up -d
check_status "Container deployment"

# 13. Verify deployment
log_step "Verifying deployment"
sleep 5  # Wait for container to start
if sudo ss -tulpn | grep :5000; then
    log_step "✓ Application is running on port 5000"
else
    log_step "✗ Application failed to start on port 5000"
    exit 1
fi

log_step "Deployment completed successfully"