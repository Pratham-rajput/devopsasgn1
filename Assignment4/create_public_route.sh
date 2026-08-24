#!/bin/bash

echo "=========================================="
echo "   STEP 4: PUBLIC ROUTE TABLE"
echo "=========================================="

# Load variables
source vars.env

if [ -z "$VPC_ID" ] || [ -z "$IGW_ID" ] || [ -z "$PUBLIC_SUBNET_ID" ]; then
    echo "ERROR: Required variables missing from vars.env"
    exit 1
fi

echo "VPC ID: $VPC_ID"
echo "IGW ID: $IGW_ID"
echo "Public Subnet ID: $PUBLIC_SUBNET_ID"

# ------------------------------------------------
# Create route table
# ------------------------------------------------

echo ""
echo "Creating public route table..."

ROUTE_TABLE_ID=$(aws ec2 create-route-table \
    --vpc-id "$VPC_ID" \
    --query 'RouteTable.RouteTableId' \
    --output text)

if [ $? -ne 0 ] || [ -z "$ROUTE_TABLE_ID" ]; then
    echo "ERROR: Failed to create route table."
    exit 1
fi

echo "Route table created: $ROUTE_TABLE_ID"

# Tag route table
aws ec2 create-tags \
    --resources "$ROUTE_TABLE_ID" \
    --tags Key=Name,Value=DevOps-Assignment4-Public-RT

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to tag route table."
    exit 1
fi

# ------------------------------------------------
# Add default route to Internet Gateway
# ------------------------------------------------

echo ""
echo "Adding route 0.0.0.0/0 -> Internet Gateway..."

aws ec2 create-route \
    --route-table-id "$ROUTE_TABLE_ID" \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id "$IGW_ID"

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create default route."
    exit 1
fi

echo "Default route created successfully."

# ------------------------------------------------
# Associate route table with public subnet
# ------------------------------------------------

echo ""
echo "Associating route table with public subnet..."

ASSOCIATION_ID=$(aws ec2 associate-route-table \
    --route-table-id "$ROUTE_TABLE_ID" \
    --subnet-id "$PUBLIC_SUBNET_ID" \
    --query 'AssociationId' \
    --output text)

if [ $? -ne 0 ] || [ -z "$ASSOCIATION_ID" ]; then
    echo "ERROR: Failed to associate route table."
    exit 1
fi

echo "Route table associated successfully."
echo "Association ID: $ASSOCIATION_ID"

# ------------------------------------------------
# Save Route Table ID
# ------------------------------------------------

echo ""
echo "Saving route table ID to vars.env..."

echo "PUBLIC_ROUTE_TABLE_ID=$ROUTE_TABLE_ID" >> vars.env

# ------------------------------------------------
# Verification
# ------------------------------------------------

echo ""
echo "=========================================="
echo "        ROUTE TABLE VERIFICATION"
echo "=========================================="

echo "Route table ID and destination CIDR:"

aws ec2 describe-route-tables \
    --route-table-ids "$ROUTE_TABLE_ID" \
    --query 'RouteTables[*].Routes[*].[RouteTableId,DestinationCidrBlock]' \
    --output table

echo ""
echo "Checking subnet association..."

aws ec2 describe-route-tables \
    --route-table-ids "$ROUTE_TABLE_ID" \
    --query 'RouteTables[*].Associations[*].[RouteTableId,SubnetId,Main]' \
    --output table

if [ $? -eq 0 ]; then
    echo ""
    echo "REPORT: Public route table and association verified successfully."
else
    echo ""
    echo "REPORT: Route table verification failed."
    exit 1
fi
