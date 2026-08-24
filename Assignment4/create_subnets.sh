#!/bin/bash

echo "=========================================="
echo "      STEP 2: CREATE SUBNETS"
echo "=========================================="

# Load VPC ID from vars.env
source vars.env

if [ -z "$VPC_ID" ]; then
    echo "ERROR: VPC_ID not found in vars.env"
    exit 1
fi

echo "Using VPC: $VPC_ID"

# ------------------------------------------------
# Find an Availability Zone
# ------------------------------------------------

AZ=$(aws ec2 describe-availability-zones \
    --filters Name=state,Values=available \
    --query 'AvailabilityZones[0].ZoneName' \
    --output text)

if [ $? -ne 0 ] || [ -z "$AZ" ]; then
    echo "ERROR: Could not determine Availability Zone."
    exit 1
fi

echo "Using Availability Zone: $AZ"

# ------------------------------------------------
# Create Public Subnet
# ------------------------------------------------

echo ""
echo "Creating public subnet: 10.0.1.0/24"

PUBLIC_SUBNET_ID=$(aws ec2 create-subnet \
    --vpc-id "$VPC_ID" \
    --cidr-block 10.0.1.0/24 \
    --availability-zone "$AZ" \
    --query 'Subnet.SubnetId' \
    --output text)

if [ $? -ne 0 ] || [ -z "$PUBLIC_SUBNET_ID" ]; then
    echo "ERROR: Failed to create public subnet."
    exit 1
fi

echo "Public Subnet ID: $PUBLIC_SUBNET_ID"

# Tag public subnet
aws ec2 create-tags \
    --resources "$PUBLIC_SUBNET_ID" \
    --tags Key=Name,Value=DevOps-Assignment4-Public-Subnet

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to tag public subnet."
    exit 1
fi

# ------------------------------------------------
# Create Private Subnet
# ------------------------------------------------

echo ""
echo "Creating private subnet: 10.0.2.0/24"

PRIVATE_SUBNET_ID=$(aws ec2 create-subnet \
    --vpc-id "$VPC_ID" \
    --cidr-block 10.0.2.0/24 \
    --availability-zone "$AZ" \
    --query 'Subnet.SubnetId' \
    --output text)

if [ $? -ne 0 ] || [ -z "$PRIVATE_SUBNET_ID" ]; then
    echo "ERROR: Failed to create private subnet."
    exit 1
fi

echo "Private Subnet ID: $PRIVATE_SUBNET_ID"

# Tag private subnet
aws ec2 create-tags \
    --resources "$PRIVATE_SUBNET_ID" \
    --tags Key=Name,Value=DevOps-Assignment4-Private-Subnet

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to tag private subnet."
    exit 1
fi

# ------------------------------------------------
# Save IDs to vars.env
# ------------------------------------------------

echo ""
echo "Saving subnet IDs to vars.env..."

{
    echo "VPC_ID=$VPC_ID"
    echo "PUBLIC_SUBNET_ID=$PUBLIC_SUBNET_ID"
    echo "PRIVATE_SUBNET_ID=$PRIVATE_SUBNET_ID"
} > vars.env

echo "Subnet IDs saved successfully."

# ------------------------------------------------
# Verification
# ------------------------------------------------

echo ""
echo "=========================================="
echo "          SUBNET VERIFICATION"
echo "=========================================="

aws ec2 describe-subnets \
    --subnet-ids "$PUBLIC_SUBNET_ID" "$PRIVATE_SUBNET_ID" \
    --query 'Subnets[*].[SubnetId,VpcId,CidrBlock,AvailabilityZone,State]' \
    --output table

if [ $? -eq 0 ]; then
    echo ""
    echo "REPORT: Public and private subnets created successfully."
    echo "Both subnets are in Availability Zone: $AZ"
else
    echo ""
    echo "REPORT: Subnet verification failed."
    exit 1
fi
