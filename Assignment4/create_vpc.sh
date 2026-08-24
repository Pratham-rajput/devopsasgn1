#!/bin/bash

echo "=========================================="
echo "        STEP 1: CREATE VPC"
echo "=========================================="

# Create VPC
echo "Creating VPC with CIDR 10.0.0.0/16..."

VPC_ID=$(aws ec2 create-vpc \
    --cidr-block 10.0.0.0/16 \
    --query 'Vpc.VpcId' \
    --output text)

# Check whether AWS CLI command succeeded
if [ $? -ne 0 ] || [ -z "$VPC_ID" ]; then
    echo "ERROR: Failed to create VPC."
    exit 1
fi

echo "VPC created successfully."
echo "VpcId: $VPC_ID"

# Tag the VPC
aws ec2 create-tags \
    --resources "$VPC_ID" \
    --tags Key=Name,Value=DevOps-Assignment4-VPC

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to tag VPC."
    exit 1
fi

echo "VPC tagged successfully."

# Save VPC ID into vars.env
echo "VPC_ID=$VPC_ID" > vars.env

echo "VpcId saved to vars.env."

# Verify VPC
echo ""
echo "=========================================="
echo "              VPC VERIFICATION"
echo "=========================================="

aws ec2 describe-vpcs \
    --vpc-ids "$VPC_ID" \
    --query 'Vpcs[*].[VpcId,CidrBlock,State]' \
    --output table

if [ $? -eq 0 ]; then
    echo ""
    echo "REPORT: VPC was created and verified successfully."
else
    echo ""
    echo "REPORT: VPC verification failed."
    exit 1
fi
