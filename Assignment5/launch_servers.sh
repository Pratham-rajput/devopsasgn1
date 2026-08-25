#!/bin/bash

echo "=========================================="
echo "       ASSIGNMENT 5 - EC2 INSTANCES"
echo "=========================================="

# Load VPC and subnet information
source ../Assignment4/vars.env

if [ -z "$VPC_ID" ] || [ -z "$PUBLIC_SUBNET_ID" ]; then
    echo "ERROR: VPC_ID or PUBLIC_SUBNET_ID not found."
    exit 1
fi

echo "VPC ID    : $VPC_ID"
echo "Subnet ID : $PUBLIC_SUBNET_ID"

# ------------------------------------------
# Find Ubuntu 22.04 LTS AMI
# ------------------------------------------

echo ""
echo "Finding Ubuntu 22.04 LTS AMI..."

AMI_ID=$(aws ec2 describe-images \
    --owners 099720109477 \
    --filters \
        "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
        "Name=state,Values=available" \
        "Name=architecture,Values=x86_64" \
    --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
    --output text)

if [ $? -ne 0 ] || [ -z "$AMI_ID" ] || [ "$AMI_ID" = "None" ]; then
    echo "ERROR: Ubuntu 22.04 AMI not found."
    exit 1
fi

echo "AMI ID: $AMI_ID"

# ------------------------------------------
# Create Security Group
# ------------------------------------------

echo ""
echo "Creating Security Group..."

SG_ID=$(aws ec2 describe-security-groups \
    --filters \
        "Name=vpc-id,Values=$VPC_ID" \
        "Name=group-name,Values=Assignment5-SG" \
    --query 'SecurityGroups[0].GroupId' \
    --output text)

if [ "$SG_ID" = "None" ] || [ -z "$SG_ID" ]; then

    SG_ID=$(aws ec2 create-security-group \
        --group-name Assignment5-SG \
        --description "Security group for Assignment 5" \
        --vpc-id "$VPC_ID" \
        --query 'GroupId' \
        --output text)

    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to create Security Group."
        exit 1
    fi

    echo "Security Group created: $SG_ID"

    # Allow HTTP
    aws ec2 authorize-security-group-ingress \
        --group-id "$SG_ID" \
        --protocol tcp \
        --port 80 \
        --cidr 0.0.0.0/0

    # Allow SSH
    aws ec2 authorize-security-group-ingress \
        --group-id "$SG_ID" \
        --protocol tcp \
        --port 22 \
        --cidr 0.0.0.0/0

else
    echo "Security Group already exists: $SG_ID"
fi

# ------------------------------------------
# Launch proxy-server
# ------------------------------------------

echo ""
echo "Launching proxy-server..."

PROXY_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type t3.micro \
    --subnet-id "$PUBLIC_SUBNET_ID" \
    --security-group-ids "$SG_ID" \
    --associate-public-ip-address \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=proxy-server}]' \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "proxy-server Instance ID: $PROXY_ID"

# ------------------------------------------
# Launch web-server-1
# ------------------------------------------

echo ""
echo "Launching web-server-1..."

WEB1_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type t3.micro \
    --subnet-id "$PUBLIC_SUBNET_ID" \
    --security-group-ids "$SG_ID" \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=web-server-1}]' \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "web-server-1 Instance ID: $WEB1_ID"

# ------------------------------------------
# Launch web-server-2
# ------------------------------------------

echo ""
echo "Launching web-server-2..."

WEB2_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type t3.micro \
    --subnet-id "$PUBLIC_SUBNET_ID" \
    --security-group-ids "$SG_ID" \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=web-server-2}]' \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "web-server-2 Instance ID: $WEB2_ID"

# ------------------------------------------
# Wait for all instances
# ------------------------------------------

echo ""
echo "Waiting for instances to reach running state..."

aws ec2 wait instance-running \
    --instance-ids "$PROXY_ID" "$WEB1_ID" "$WEB2_ID"

# ------------------------------------------
# Get IP addresses
# ------------------------------------------

PROXY_PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids "$PROXY_ID" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

WEB1_PRIVATE_IP=$(aws ec2 describe-instances \
    --instance-ids "$WEB1_ID" \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' \
    --output text)

WEB2_PRIVATE_IP=$(aws ec2 describe-instances \
    --instance-ids "$WEB2_ID" \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' \
    --output text)

# ------------------------------------------
# Save variables
# ------------------------------------------

cat > vars.env <<EOF
VPC_ID=$VPC_ID
SUBNET_ID=$PUBLIC_SUBNET_ID
SG_ID=$SG_ID

PROXY_ID=$PROXY_ID
WEB1_ID=$WEB1_ID
WEB2_ID=$WEB2_ID

PROXY_PUBLIC_IP=$PROXY_PUBLIC_IP
WEB1_PRIVATE_IP=$WEB1_PRIVATE_IP
WEB2_PRIVATE_IP=$WEB2_PRIVATE_IP
EOF

# ------------------------------------------
# Display results
# ------------------------------------------

echo ""
echo "=========================================="
echo "             INSTANCE DETAILS"
echo "=========================================="

printf "%-18s %-22s %-18s %-18s\n" \
    "NAME" "INSTANCE ID" "PRIVATE IP" "PUBLIC IP"

printf "%-18s %-22s %-18s %-18s\n" \
    "proxy-server" "$PROXY_ID" \
    "$(aws ec2 describe-instances --instance-ids "$PROXY_ID" --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)" \
    "$PROXY_PUBLIC_IP"

printf "%-18s %-22s %-18s %-18s\n" \
    "web-server-1" "$WEB1_ID" \
    "$WEB1_PRIVATE_IP" "None"

printf "%-18s %-22s %-18s %-18s\n" \
    "web-server-2" "$WEB2_ID" \
    "$WEB2_PRIVATE_IP" "None"

echo ""
echo "=========================================="
echo "IMPORTANT VALUES"
echo "=========================================="

echo "Proxy Public IP : $PROXY_PUBLIC_IP"
echo "Web 1 Private IP: $WEB1_PRIVATE_IP"
echo "Web 2 Private IP: $WEB2_PRIVATE_IP"

echo ""
echo "Saved to: vars.env"
