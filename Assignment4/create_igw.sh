#!/bin/bash

echo "=========================================="
echo "   STEP 3: INTERNET GATEWAY"
echo "=========================================="

# Load VPC ID
source vars.env

if [ -z "$VPC_ID" ]; then
    echo "ERROR: VPC_ID not found in vars.env"
    exit 1
fi

echo "Using VPC: $VPC_ID"

# Create Internet Gateway
echo ""
echo "Creating Internet Gateway..."

IGW_ID=$(aws ec2 create-internet-gateway \
    --query 'InternetGateway.InternetGatewayId' \
    --output text)

if [ $? -ne 0 ] || [ -z "$IGW_ID" ]; then
    echo "ERROR: Failed to create Internet Gateway."
    exit 1
fi

echo "Internet Gateway created: $IGW_ID"

# Tag Internet Gateway
aws ec2 create-tags \
    --resources "$IGW_ID" \
    --tags Key=Name,Value=DevOps-Assignment4-IGW

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to tag Internet Gateway."
    exit 1
fi

# Attach Internet Gateway to VPC
echo ""
echo "Attaching Internet Gateway to VPC..."

aws ec2 attach-internet-gateway \
    --internet-gateway-id "$IGW_ID" \
    --vpc-id "$VPC_ID"

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to attach Internet Gateway."
    exit 1
fi

echo "Internet Gateway attached successfully."

# Save IGW ID to vars.env
echo ""
echo "Saving IGW ID to vars.env..."

echo "IGW_ID=$IGW_ID" >> vars.env

echo "IGW ID saved."

# Verify
echo ""
echo "=========================================="
echo "        IGW VERIFICATION"
echo "=========================================="

aws ec2 describe-internet-gateways \
    --internet-gateway-ids "$IGW_ID" \
    --query 'InternetGateways[*].[InternetGatewayId,Attachments[0].VpcId,Attachments[0].State]' \
    --output table

if [ $? -eq 0 ]; then
    echo ""
    echo "REPORT: Internet Gateway created and attached successfully."
else
    echo ""
    echo "REPORT: Internet Gateway verification failed."
    exit 1
fi
