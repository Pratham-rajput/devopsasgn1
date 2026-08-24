#!/bin/bash

echo "=========================================="
echo "   STEP 6: NAT GATEWAY & PRIVATE ROUTE"
echo "=========================================="

# Load variables
source vars.env

if [ -z "$VPC_ID" ] || [ -z "$PUBLIC_SUBNET_ID" ] || [ -z "$PRIVATE_SUBNET_ID" ]; then
    echo "ERROR: Required variables missing from vars.env"
    exit 1
fi

echo "VPC ID            : $VPC_ID"
echo "Public Subnet ID  : $PUBLIC_SUBNET_ID"
echo "Private Subnet ID : $PRIVATE_SUBNET_ID"

# ------------------------------------------------
# Step 1: Allocate Elastic IP
# ------------------------------------------------

echo ""
echo "STEP 1: Allocating Elastic IP..."

ALLOCATION_ID=$(aws ec2 allocate-address \
    --domain vpc \
    --query 'AllocationId' \
    --output text)

if [ $? -ne 0 ] || [ -z "$ALLOCATION_ID" ]; then
    echo "ERROR: Failed to allocate Elastic IP."
    exit 1
fi

echo "Elastic IP Allocation ID: $ALLOCATION_ID"

# Get actual public IP
ELASTIC_IP=$(aws ec2 describe-addresses \
    --allocation-ids "$ALLOCATION_ID" \
    --query 'Addresses[0].PublicIp' \
    --output text)

echo "Elastic IP: $ELASTIC_IP"

# Tag Elastic IP
aws ec2 create-tags \
    --resources "$ALLOCATION_ID" \
    --tags Key=Name,Value=DevOps-Assignment4-NAT-EIP

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to tag Elastic IP."
    exit 1
fi

# ------------------------------------------------
# Step 2: Create NAT Gateway
# ------------------------------------------------

echo ""
echo "STEP 2: Creating NAT Gateway in public subnet..."

NAT_GATEWAY_ID=$(aws ec2 create-nat-gateway \
    --subnet-id "$PUBLIC_SUBNET_ID" \
    --allocation-id "$ALLOCATION_ID" \
    --query 'NatGateway.NatGatewayId' \
    --output text)

if [ $? -ne 0 ] || [ -z "$NAT_GATEWAY_ID" ]; then
    echo "ERROR: Failed to create NAT Gateway."
    exit 1
fi

echo "NAT Gateway ID: $NAT_GATEWAY_ID"

# Tag NAT Gateway
aws ec2 create-tags \
    --resources "$NAT_GATEWAY_ID" \
    --tags Key=Name,Value=DevOps-Assignment4-NAT

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to tag NAT Gateway."
    exit 1
fi

# ------------------------------------------------
# Step 3: Wait for NAT Gateway
# ------------------------------------------------

echo ""
echo "STEP 3: Waiting for NAT Gateway to become available..."

aws ec2 wait nat-gateway-available \
    --nat-gateway-ids "$NAT_GATEWAY_ID"

if [ $? -ne 0 ]; then
    echo "ERROR: NAT Gateway did not become available."
    exit 1
fi

echo "NAT Gateway is available."

# ------------------------------------------------
# Step 4: Create private route table
# ------------------------------------------------

echo ""
echo "STEP 4: Creating private route table..."

PRIVATE_ROUTE_TABLE_ID=$(aws ec2 create-route-table \
    --vpc-id "$VPC_ID" \
    --query 'RouteTable.RouteTableId' \
    --output text)

if [ $? -ne 0 ] || [ -z "$PRIVATE_ROUTE_TABLE_ID" ]; then
    echo "ERROR: Failed to create private route table."
    exit 1
fi

echo "Private Route Table ID: $PRIVATE_ROUTE_TABLE_ID"

# Tag private route table
aws ec2 create-tags \
    --resources "$PRIVATE_ROUTE_TABLE_ID" \
    --tags Key=Name,Value=DevOps-Assignment4-Private-RT

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to tag private route table."
    exit 1
fi

# ------------------------------------------------
# Step 5: Add default route through NAT Gateway
# ------------------------------------------------

echo ""
echo "STEP 5: Adding 0.0.0.0/0 -> NAT Gateway..."

aws ec2 create-route \
    --route-table-id "$PRIVATE_ROUTE_TABLE_ID" \
    --destination-cidr-block 0.0.0.0/0 \
    --nat-gateway-id "$NAT_GATEWAY_ID"

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create NAT route."
    exit 1
fi

echo "Private default route created successfully."

# ------------------------------------------------
# Step 6: Associate private route table
# ------------------------------------------------

echo ""
echo "STEP 6: Associating private route table with private subnet..."

PRIVATE_ASSOCIATION_ID=$(aws ec2 associate-route-table \
    --route-table-id "$PRIVATE_ROUTE_TABLE_ID" \
    --subnet-id "$PRIVATE_SUBNET_ID" \
    --query 'AssociationId' \
    --output text)

if [ $? -ne 0 ] || [ -z "$PRIVATE_ASSOCIATION_ID" ]; then
    echo "ERROR: Failed to associate private route table."
    exit 1
fi

echo "Private route table associated successfully."
echo "Association ID: $PRIVATE_ASSOCIATION_ID"

# ------------------------------------------------
# Step 7: Save variables
# ------------------------------------------------

echo ""
echo "STEP 7: Saving values to vars.env..."

cat >> vars.env <<EOF
ALLOCATION_ID=$ALLOCATION_ID
ELASTIC_IP=$ELASTIC_IP
NAT_GATEWAY_ID=$NAT_GATEWAY_ID
PRIVATE_ROUTE_TABLE_ID=$PRIVATE_ROUTE_TABLE_ID
PRIVATE_ASSOCIATION_ID=$PRIVATE_ASSOCIATION_ID
EOF

echo "Values saved to vars.env."

# ------------------------------------------------
# Step 8: Verification
# ------------------------------------------------

echo ""
echo "=========================================="
echo "        NAT GATEWAY VERIFICATION"
echo "=========================================="

echo ""
echo "NAT Gateway:"
aws ec2 describe-nat-gateways \
    --nat-gateway-ids "$NAT_GATEWAY_ID" \
    --query 'NatGateways[*].[NatGatewayId,State,SubnetId,NatGatewayAddresses[0].PublicIp]' \
    --output table

echo ""
echo "Private Route Table:"
aws ec2 describe-route-tables \
    --route-table-ids "$PRIVATE_ROUTE_TABLE_ID" \
    --query 'RouteTables[*].Routes[*].[RouteTableId,DestinationCidrBlock,NatGatewayId]' \
    --output table

echo ""
echo "Private Subnet Association:"
aws ec2 describe-route-tables \
    --route-table-ids "$PRIVATE_ROUTE_TABLE_ID" \
    --query 'RouteTables[*].Associations[*].[RouteTableId,SubnetId]' \
    --output table

echo ""
echo "=========================================="
echo "              STEP 6 COMPLETE"
echo "=========================================="

echo "REPORT:"
echo "Elastic IP       : $ELASTIC_IP"
echo "NAT Gateway      : $NAT_GATEWAY_ID"
echo "Private RT       : $PRIVATE_ROUTE_TABLE_ID"
echo "Private Subnet   : $PRIVATE_SUBNET_ID"
echo ""
echo "Private subnet now routes 0.0.0.0/0 through the NAT Gateway."
