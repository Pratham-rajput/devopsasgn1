#!/bin/bash
set -e

AWS_REGION="$1"
ECR_REPOSITORY="$2"
DB_HOST="$3"
DB_NAME="$4"
DB_USER="$5"
DB_PASSWORD="$6"

echo "=== NimbusCart App Deployment ==="

echo "Installing Docker and AWS CLI..."
sudo apt-get update
sudo apt-get install -y docker.io awscli

sudo systemctl enable docker
sudo systemctl start docker

echo "Logging into ECR..."

aws ecr get-login-password --region "$AWS_REGION" | \
sudo docker login \
  --username AWS \
  --password-stdin "$ECR_REPOSITORY"

echo "Pulling NimbusCart API image..."

sudo docker pull "$ECR_REPOSITORY:latest"

echo "Removing old container if it exists..."

sudo docker rm -f nimbuscart-api 2>/dev/null || true

echo "Starting API container..."

sudo docker run -d \
  --name nimbuscart-api \
  --restart unless-stopped \
  -p 5000:5000 \
  -e PORT=5000 \
  -e DB_HOST="$DB_HOST" \
  -e DB_PORT=5432 \
  -e DB_NAME="$DB_NAME" \
  -e DB_USER="$DB_USER" \
  -e DB_PASSWORD="$DB_PASSWORD" \
  "$ECR_REPOSITORY:latest"

echo "=== Container Status ==="
sudo docker ps
