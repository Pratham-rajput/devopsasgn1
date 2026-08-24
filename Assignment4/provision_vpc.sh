#!/bin/bash

# ============================================================
# Assignment 4 - VPC Provisioning
# Idempotent AWS VPC Infrastructure Script
# ============================================================

set -u

REGION=$(aws configure get region)

if [ -z "$REGION" ]; then
    echo "ERROR: AWS region is not configured."
    exit 1
fi

VARS_FILE="vars.env"

touch "$VARS_FILE"

# Load existing variables if available
source "$VARS_FILE"

# ============================================================
# Helper: Save variable
# ============================================================

save_var() {
    local key="$1"
    local value="$2"

    sed -i "/^${key}=/d" "$VARS_FILE"
    echo "${key}=${value}" >> "$VARS_FILE"
}

# ============================================================
# 1. Create VPC
# ============================================================

create_vpc()
{
    echo ""
    echo "========== CREATE VPC =========="

    # Idempotency check
    EXISTING_VPC=$(aws ec2 describe-vpcs \
        --filters "Name=tag:Name,Values=DevOps-Assignment4-VPC" \
        --query 'Vpcs[0].VpcId' \
        --output text)

    if [ "$EXISTING_VPC" != "None" ] && [ -n "$EXISTING_VPC" ]; then
        VPC_ID="$EXISTING_VPC"
        echo "VPC already exists: $VPC_ID"
    else
        VPC_ID=$(aws ec2 create-vpc \
            --cidr-block 10.0.0.0/16 \
            --query 'Vpc.VpcId' \
            --output text)

        if [ $? -ne 0 ]; then
            echo "ERROR: Failed to create VPC."
            exit 1
        fi

        aws ec2 create-tags \
            --resources "$VPC_ID" \
            --tags Key=Name,Value=DevOps-Assignment4-VPC

        echo "Created VPC: $VPC_ID"
    fi

    save_var "VPC_ID" "$VPC_ID"
}

# ============================================================
# 2. Create Public and Private Subnets
# ============================================================

create_subnets()
{
    echo ""
    echo "========== CREATE SUBNETS =========="

    source "$VARS_FILE"

    # Find an available AZ
    AZ=$(aws ec2 describe-availability-zones \
        --filters Name=state,Values=available \
        --query 'AvailabilityZones[0].ZoneName' \
        --output text)

    save_var "AZ" "$AZ"

    # ---------------- Public subnet ----------------

    PUBLIC_SUBNET_ID=$(aws ec2 describe-subnets \
        --filters \
        "Name=vpc-id,Values=$VPC_ID" \
        "Name=cidr-block,Values=10.0.1.0/24" \
        --query 'Subnets[0].SubnetId' \
        --output text)

    if [ "$PUBLIC_SUBNET_ID" != "None" ] && [ -n "$PUBLIC_SUBNET_ID" ]; then
        echo "Public subnet already exists: $PUBLIC_SUBNET_ID"
    else
        PUBLIC_SUBNET_ID=$(aws ec2 create-subnet \
            --vpc-id "$VPC_ID" \
            --cidr-block 10.0.1.0/24 \
            --availability-zone "$AZ" \
            --query 'Subnet.SubnetId' \
            --output text)

        aws ec2 create-tags \
            --resources "$PUBLIC_SUBNET_ID" \
            --tags Key=Name,Value=DevOps-Assignment4-Public-Subnet

        echo "Created public subnet: $PUBLIC_SUBNET_ID"
    fi

    # ---------------- Private subnet ----------------

    PRIVATE_SUBNET_ID=$(aws ec2 describe-subnets \
        --filters \
        "Name=vpc-id,Values=$VPC_ID" \
        "Name=cidr-block,Values=10.0.2.0/24" \
        --query 'Subnets[0].SubnetId' \
        --output text)

    if [ "$PRIVATE_SUBNET_ID" != "None" ] && [ -n "$PRIVATE_SUBNET_ID" ]; then
        echo "Private subnet already exists: $PRIVATE_SUBNET_ID"
    else
        PRIVATE_SUBNET_ID=$(aws ec2 create-subnet \
            --vpc-id "$VPC_ID" \
            --cidr-block 10.0.2.0/24 \
            --availability-zone "$AZ" \
            --query 'Subnet.SubnetId' \
            --output text)

        aws ec2 create-tags \
            --resources "$PRIVATE_SUBNET_ID" \
            --tags Key=Name,Value=DevOps-Assignment4-Private-Subnet

        echo "Created private subnet: $PRIVATE_SUBNET_ID"
    fi

    save_var "PUBLIC_SUBNET_ID" "$PUBLIC_SUBNET_ID"
    save_var "PRIVATE_SUBNET_ID" "$PRIVATE_SUBNET_ID"
}

# ============================================================
# 3 & 4. Internet Gateway + Public Route Table
# ============================================================

setup_igw_and_route()
{
    echo ""
    echo "========== IGW AND PUBLIC ROUTE =========="

    source "$VARS_FILE"

    # ---------------- Internet Gateway ----------------

    IGW_ID=$(aws ec2 describe-internet-gateways \
        --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
        --query 'InternetGateways[0].InternetGatewayId' \
        --output text)

    if [ "$IGW_ID" != "None" ] && [ -n "$IGW_ID" ]; then
        echo "Internet Gateway already exists: $IGW_ID"
    else
        IGW_ID=$(aws ec2 create-internet-gateway \
            --query 'InternetGateway.InternetGatewayId' \
            --output text)

        aws ec2 create-tags \
            --resources "$IGW_ID" \
            --tags Key=Name,Value=DevOps-Assignment4-IGW

        aws ec2 attach-internet-gateway \
            --internet-gateway-id "$IGW_ID" \
            --vpc-id "$VPC_ID"

        echo "Created and attached IGW: $IGW_ID"
    fi

    save_var "IGW_ID" "$IGW_ID"

    # ---------------- Public Route Table ----------------

    PUBLIC_ROUTE_TABLE_ID=$(aws ec2 describe-route-tables \
        --filters \
        "Name=vpc-id,Values=$VPC_ID" \
        "Name=tag:Name,Values=DevOps-Assignment4-Public-RT" \
        --query 'RouteTables[0].RouteTableId' \
        --output text)

    if [ "$PUBLIC_ROUTE_TABLE_ID" != "None" ] && [ -n "$PUBLIC_ROUTE_TABLE_ID" ]; then
        echo "Public route table already exists: $PUBLIC_ROUTE_TABLE_ID"
    else
        PUBLIC_ROUTE_TABLE_ID=$(aws ec2 create-route-table \
            --vpc-id "$VPC_ID" \
            --query 'RouteTable.RouteTableId' \
            --output text)

        aws ec2 create-tags \
            --resources "$PUBLIC_ROUTE_TABLE_ID" \
            --tags Key=Name,Value=DevOps-Assignment4-Public-RT

        echo "Created public route table: $PUBLIC_ROUTE_TABLE_ID"
    fi

    # Check default route
    ROUTE_EXISTS=$(aws ec2 describe-route-tables \
        --route-table-ids "$PUBLIC_ROUTE_TABLE_ID" \
        --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].GatewayId" \
        --output text)

    if [ "$ROUTE_EXISTS" = "$IGW_ID" ]; then
        echo "Public default route already exists."
    else
        aws ec2 create-route \
            --route-table-id "$PUBLIC_ROUTE_TABLE_ID" \
            --destination-cidr-block 0.0.0.0/0 \
            --gateway-id "$IGW_ID"

        echo "Created public default route."
    fi

    # Check public subnet association
    ASSOCIATION=$(aws ec2 describe-route-tables \
        --route-table-ids "$PUBLIC_ROUTE_TABLE_ID" \
        --query "RouteTables[0].Associations[?SubnetId=='$PUBLIC_SUBNET_ID'].AssociationId" \
        --output text)

    if [ -n "$ASSOCIATION" ] && [ "$ASSOCIATION" != "None" ]; then
        echo "Public subnet already associated."
    else
        aws ec2 associate-route-table \
            --route-table-id "$PUBLIC_ROUTE_TABLE_ID" \
            --subnet-id "$PUBLIC_SUBNET_ID"

        echo "Associated public subnet."
    fi

    save_var "PUBLIC_ROUTE_TABLE_ID" "$PUBLIC_ROUTE_TABLE_ID"
}

# ============================================================
# 5 & 6. NAT Gateway + Private Route Table
# ============================================================

setup_nat_and_route()
{
    echo ""
    echo "========== NAT AND PRIVATE ROUTE =========="

    source "$VARS_FILE"

    # ---------------- Elastic IP ----------------

    ALLOCATION_ID=$(aws ec2 describe-addresses \
        --filters "Name=tag:Name,Values=DevOps-Assignment4-NAT-EIP" \
        --query 'Addresses[0].AllocationId' \
        --output text)

    if [ "$ALLOCATION_ID" != "None" ] && [ -n "$ALLOCATION_ID" ]; then
        echo "Elastic IP already exists: $ALLOCATION_ID"
    else
        ALLOCATION_ID=$(aws ec2 allocate-address \
            --domain vpc \
            --query 'AllocationId' \
            --output text)

        aws ec2 create-tags \
            --resources "$ALLOCATION_ID" \
            --tags Key=Name,Value=DevOps-Assignment4-NAT-EIP

        echo "Allocated Elastic IP: $ALLOCATION_ID"
    fi

    ELASTIC_IP=$(aws ec2 describe-addresses \
        --allocation-ids "$ALLOCATION_ID" \
        --query 'Addresses[0].PublicIp' \
        --output text)

    save_var "ALLOCATION_ID" "$ALLOCATION_ID"
    save_var "ELASTIC_IP" "$ELASTIC_IP"

    # ---------------- NAT Gateway ----------------

    NAT_GATEWAY_ID=$(aws ec2 describe-nat-gateways \
        --filter "Name=subnet-id,Values=$PUBLIC_SUBNET_ID" \
        "Name=state,Values=pending,available" \
        --query 'NatGateways[0].NatGatewayId' \
        --output text)

    if [ "$NAT_GATEWAY_ID" != "None" ] && [ -n "$NAT_GATEWAY_ID" ]; then
        echo "NAT Gateway already exists: $NAT_GATEWAY_ID"
    else
        NAT_GATEWAY_ID=$(aws ec2 create-nat-gateway \
            --subnet-id "$PUBLIC_SUBNET_ID" \
            --allocation-id "$ALLOCATION_ID" \
            --query 'NatGateway.NatGatewayId' \
            --output text)

        aws ec2 create-tags \
            --resources "$NAT_GATEWAY_ID" \
            --tags Key=Name,Value=DevOps-Assignment4-NAT

        echo "Created NAT Gateway: $NAT_GATEWAY_ID"

        echo "Waiting for NAT Gateway..."
        aws ec2 wait nat-gateway-available \
            --nat-gateway-ids "$NAT_GATEWAY_ID"
    fi

    save_var "NAT_GATEWAY_ID" "$NAT_GATEWAY_ID"

    # ---------------- Private Route Table ----------------

    PRIVATE_ROUTE_TABLE_ID=$(aws ec2 describe-route-tables \
        --filters \
        "Name=vpc-id,Values=$VPC_ID" \
        "Name=tag:Name,Values=DevOps-Assignment4-Private-RT" \
        --query 'RouteTables[0].RouteTableId' \
        --output text)

    if [ "$PRIVATE_ROUTE_TABLE_ID" != "None" ] && [ -n "$PRIVATE_ROUTE_TABLE_ID" ]; then
        echo "Private route table already exists: $PRIVATE_ROUTE_TABLE_ID"
    else
        PRIVATE_ROUTE_TABLE_ID=$(aws ec2 create-route-table \
            --vpc-id "$VPC_ID" \
            --query 'RouteTable.RouteTableId' \
            --output text)

        aws ec2 create-tags \
            --resources "$PRIVATE_ROUTE_TABLE_ID" \
            --tags Key=Name,Value=DevOps-Assignment4-Private-RT

        echo "Created private route table: $PRIVATE_ROUTE_TABLE_ID"
    fi

    # Check NAT route
    NAT_ROUTE=$(aws ec2 describe-route-tables \
        --route-table-ids "$PRIVATE_ROUTE_TABLE_ID" \
        --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].NatGatewayId" \
        --output text)

    if [ "$NAT_ROUTE" = "$NAT_GATEWAY_ID" ]; then
        echo "Private NAT route already exists."
    else
        aws ec2 create-route \
            --route-table-id "$PRIVATE_ROUTE_TABLE_ID" \
            --destination-cidr-block 0.0.0.0/0 \
            --nat-gateway-id "$NAT_GATEWAY_ID"

        echo "Created private NAT route."
    fi

    # Check private subnet association
    ASSOCIATION=$(aws ec2 describe-route-tables \
        --route-table-ids "$PRIVATE_ROUTE_TABLE_ID" \
        --query "RouteTables[0].Associations[?SubnetId=='$PRIVATE_SUBNET_ID'].AssociationId" \
        --output text)

    if [ -n "$ASSOCIATION" ] && [ "$ASSOCIATION" != "None" ]; then
        echo "Private subnet already associated."
    else
        aws ec2 associate-route-table \
            --route-table-id "$PRIVATE_ROUTE_TABLE_ID" \
            --subnet-id "$PRIVATE_SUBNET_ID"

        echo "Associated private subnet."
    fi

    save_var "PRIVATE_ROUTE_TABLE_ID" "$PRIVATE_ROUTE_TABLE_ID"
}

# ============================================================
# 7 & 8. Launch Public and Private Instances
# ============================================================

launch_instances()
{
    echo ""
    echo "========== LAUNCH INSTANCES =========="

    source "$VARS_FILE"

    # --------------------------------------------------------
    # Find Ubuntu AMI
    # --------------------------------------------------------

    AMI_ID=$(aws ec2 describe-images \
        --owners 099720109477 \
        --filters \
            "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" \
            "Name=state,Values=available" \
            "Name=architecture,Values=x86_64" \
        --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
        --output text)

    if [ -z "$AMI_ID" ] || [ "$AMI_ID" = "None" ]; then
        echo "ERROR: Ubuntu AMI not found."
        exit 1
    fi

    # --------------------------------------------------------
    # Public Security Group
    # --------------------------------------------------------

    WEB_SG_ID=$(aws ec2 describe-security-groups \
        --filters \
        "Name=vpc-id,Values=$VPC_ID" \
        "Name=group-name,Values=DevOps-Assignment4-Web-SG" \
        --query 'SecurityGroups[0].GroupId' \
        --output text)

    if [ "$WEB_SG_ID" = "None" ] || [ -z "$WEB_SG_ID" ]; then

        WEB_SG_ID=$(aws ec2 create-security-group \
            --group-name "DevOps-Assignment4-Web-SG" \
            --description "HTTP and SSH for bastion" \
            --vpc-id "$VPC_ID" \
            --query 'GroupId' \
            --output text)

        aws ec2 authorize-security-group-ingress \
            --group-id "$WEB_SG_ID" \
            --protocol tcp \
            --port 80 \
            --cidr 0.0.0.0/0

        echo "Created public Security Group: $WEB_SG_ID"
    else
        echo "Public Security Group already exists: $WEB_SG_ID"
    fi

    save_var "WEB_SG_ID" "$WEB_SG_ID"

    # --------------------------------------------------------
    # Public Instance
    # --------------------------------------------------------

    INSTANCE_ID=$(aws ec2 describe-instances \
        --filters \
        "Name=tag:Name,Values=DevOps-Assignment4-Web" \
        "Name=instance-state-name,Values=pending,running,stopping,stopped" \
        --query 'Reservations[0].Instances[0].InstanceId' \
        --output text)

    if [ "$INSTANCE_ID" != "None" ] && [ -n "$INSTANCE_ID" ]; then

        echo "Public instance already exists: $INSTANCE_ID"

    else

        USER_DATA=$(cat <<'EOF'
#!/bin/bash

apt-get update -y
apt-get install -y nginx
systemctl enable nginx
systemctl start nginx

echo "<h1>DevOps Assignment 4 - Nginx</h1>" > /var/www/html/index.html
EOF
)

        INSTANCE_ID=$(aws ec2 run-instances \
            --image-id "$AMI_ID" \
            --instance-type t3.micro \
            --subnet-id "$PUBLIC_SUBNET_ID" \
            --security-group-ids "$WEB_SG_ID" \
            --associate-public-ip-address \
            --user-data "$USER_DATA" \
            --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=DevOps-Assignment4-Web}]' \
            --query 'Instances[0].InstanceId' \
            --output text)

        echo "Created public instance: $INSTANCE_ID"

    fi

    save_var "INSTANCE_ID" "$INSTANCE_ID"

    # --------------------------------------------------------
    # Private Security Group
    # --------------------------------------------------------

    PRIVATE_SG_ID=$(aws ec2 describe-security-groups \
        --filters \
        "Name=vpc-id,Values=$VPC_ID" \
        "Name=group-name,Values=DevOps-Assignment4-Private-SG" \
        --query 'SecurityGroups[0].GroupId' \
        --output text)

    if [ "$PRIVATE_SG_ID" = "None" ] || [ -z "$PRIVATE_SG_ID" ]; then

        PRIVATE_SG_ID=$(aws ec2 create-security-group \
            --group-name "DevOps-Assignment4-Private-SG" \
            --description "SSH from bastion only" \
            --vpc-id "$VPC_ID" \
            --query 'GroupId' \
            --output text)

        aws ec2 authorize-security-group-ingress \
            --group-id "$PRIVATE_SG_ID" \
            --protocol tcp \
            --port 22 \
            --source-group "$WEB_SG_ID"

        echo "Created private Security Group: $PRIVATE_SG_ID"
    else
        echo "Private Security Group already exists: $PRIVATE_SG_ID"
    fi

    save_var "PRIVATE_SG_ID" "$PRIVATE_SG_ID"

    # --------------------------------------------------------
    # Get key pair from public instance
    # --------------------------------------------------------

    KEY_NAME=$(aws ec2 describe-instances \
        --instance-ids "$INSTANCE_ID" \
        --query 'Reservations[0].Instances[0].KeyName' \
        --output text)

    if [ "$KEY_NAME" = "None" ] || [ -z "$KEY_NAME" ]; then
        echo ""
        echo "WARNING: Public instance has no key pair."
        echo "Private instance cannot be SSH accessed through the bastion."
        echo "Skipping private instance launch."
        return
    fi

    save_var "KEY_NAME" "$KEY_NAME"

    # --------------------------------------------------------
    # Private Instance
    # --------------------------------------------------------

    PRIVATE_INSTANCE_ID=$(aws ec2 describe-instances \
        --filters \
        "Name=tag:Name,Values=DevOps-Assignment4-Private" \
        "Name=instance-state-name,Values=pending,running,stopping,stopped" \
        --query 'Reservations[0].Instances[0].InstanceId' \
        --output text)

    if [ "$PRIVATE_INSTANCE_ID" != "None" ] && [ -n "$PRIVATE_INSTANCE_ID" ]; then

        echo "Private instance already exists: $PRIVATE_INSTANCE_ID"

    else

        PRIVATE_INSTANCE_ID=$(aws ec2 run-instances \
            --image-id "$AMI_ID" \
            --instance-type t2.micro \
            --subnet-id "$PRIVATE_SUBNET_ID" \
            --security-group-ids "$PRIVATE_SG_ID" \
            --key-name "$KEY_NAME" \
            --no-associate-public-ip-address \
            --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=DevOps-Assignment4-Private}]' \
            --query 'Instances[0].InstanceId' \
            --output text)

        echo "Created private instance: $PRIVATE_INSTANCE_ID"

    fi

    save_var "PRIVATE_INSTANCE_ID" "$PRIVATE_INSTANCE_ID"

    # --------------------------------------------------------
    # Public IP and Private IP
    # --------------------------------------------------------

    PUBLIC_IP=$(aws ec2 describe-instances \
        --instance-ids "$INSTANCE_ID" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text)

    PRIVATE_IP=$(aws ec2 describe-instances \
        --instance-ids "$PRIVATE_INSTANCE_ID" \
        --query 'Reservations[0].Instances[0].PrivateIpAddress' \
        --output text)

    save_var "PUBLIC_IP" "$PUBLIC_IP"
    save_var "PRIVATE_IP" "$PRIVATE_IP"

    echo ""
    echo "Public Instance : $INSTANCE_ID"
    echo "Public IP       : $PUBLIC_IP"
    echo "Private Instance: $PRIVATE_INSTANCE_ID"
    echo "Private IP      : $PRIVATE_IP"
}

# ============================================================
# MAIN
# ============================================================

echo ""
echo "=========================================="
echo "     DEVOPS ASSIGNMENT 4 PROVISIONER"
echo "=========================================="

create_vpc
create_subnets
setup_igw_and_route
setup_nat_and_route
launch_instances

echo ""
echo "=========================================="
echo "       PROVISIONING COMPLETE"
echo "=========================================="

echo ""
echo "Saved variables:"
cat "$VARS_FILE"

echo ""
echo "Run the script again to verify idempotency."
