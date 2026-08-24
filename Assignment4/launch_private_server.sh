#!/bin/bash

echo "=========================================="
echo "   STEP 7: PRIVATE EC2 INSTANCE"
echo "=========================================="

# Load variables
source vars.env

if [ -z "$VPC_ID" ] || [ -z "$PRIVATE_SUBNET_ID" ] || [ -z "$WEB_SG_ID" ] || [ -z "$INSTANCE_ID" ]; then
    echo "ERROR: Required variables missing from vars.env"
    exit 1
fi

echo "VPC ID            : $VPC_ID"
echo "Private Subnet ID : $PRIVATE_SUBNET_ID"
echo "Bastion Instance  : $INSTANCE_ID"

# ------------------------------------------------
# Step 1: Get key pair used by public/bastion EC2
# ------------------------------------------------

echo ""
echo "Finding key pair used by bastion..."

KEY_NAME=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].KeyName' \
    --output text)

if [ $? -ne 0 ] || [ -z "$KEY_NAME" ] || [ "$KEY_NAME" = "None" ]; then
    echo "ERROR: Could not determine the bastion key pair."
    echo "The public instance must have been launched with an EC2 key pair."
    exit 1
fi

echo "Key Pair: $KEY_NAME"

# ------------------------------------------------
# Step 2: Find Ubuntu AMI
# ------------------------------------------------

echo ""
echo "Finding Ubuntu 24.04 LTS AMI..."

AMI_ID=$(aws ec2 describe-images \
    --owners 099720109477 \
    --filters \
        "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" \
        "Name=state,Values=available" \
        "Name=architecture,Values=x86_64" \
    --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
    --output text)

if [ $? -ne 0 ] || [ -z "$AMI_ID" ] || [ "$AMI_ID" = "None" ]; then
    echo "ERROR: Could not find Ubuntu AMI."
    exit 1
fi

echo "AMI ID: $AMI_ID"

# ------------------------------------------------
# Step 3: Create private Security Group
# ------------------------------------------------

echo ""
echo "Creating private Security Group..."

PRIVATE_SG_ID=$(aws ec2 create-security-group \
    --group-name "DevOps-Assignment4-Private-SG" \
    --description "Allow SSH only from bastion" \
    --vpc-id "$VPC_ID" \
    --query 'GroupId' \
    --output text)

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create private Security Group."
    exit 1
fi

echo "Private Security Group: $PRIVATE_SG_ID"

# Allow SSH ONLY from the bastion security group
echo ""
echo "Allowing SSH only from bastion..."

aws ec2 authorize-security-group-ingress \
    --group-id "$PRIVATE_SG_ID" \
    --protocol tcp \
    --port 22 \
    --source-group "$WEB_SG_ID"

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to configure SSH access."
    exit 1
fi

echo "SSH allowed only from bastion Security Group."

# ------------------------------------------------
# Step 4: User data
# ------------------------------------------------

USER_DATA=$(cat <<'EOF'
#!/bin/bash

apt-get update -y
apt-get install -y curl
EOF
)

# ------------------------------------------------
# Step 5: Launch private EC2
# ------------------------------------------------

echo ""
echo "Launching t2.micro in private subnet..."

PRIVATE_INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type t2.micro \
    --subnet-id "$PRIVATE_SUBNET_ID" \
    --security-group-ids "$PRIVATE_SG_ID" \
    --key-name "$KEY_NAME" \
    --no-associate-public-ip-address \
    --user-data "$USER_DATA" \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=DevOps-Assignment4-Private}]' \
    --query 'Instances[0].InstanceId' \
    --output text)

if [ $? -ne 0 ] || [ -z "$PRIVATE_INSTANCE_ID" ]; then
    echo "ERROR: Failed to launch private instance."
    exit 1
fi

echo "Private instance created: $PRIVATE_INSTANCE_ID"

# ------------------------------------------------
# Step 6: Wait for instance
# ------------------------------------------------

echo ""
echo "Waiting for private instance to start..."

aws ec2 wait instance-running \
    --instance-ids "$PRIVATE_INSTANCE_ID"

if [ $? -ne 0 ]; then
    echo "ERROR: Private instance did not start."
    exit 1
fi

echo "Private instance is running."

# ------------------------------------------------
# Step 7: Get private IP
# ------------------------------------------------

PRIVATE_IP=$(aws ec2 describe-instances \
    --instance-ids "$PRIVATE_INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' \
    --output text)

echo "Private IP: $PRIVATE_IP"

# ------------------------------------------------
# Step 8: Save variables
# ------------------------------------------------

cat >> vars.env <<EOF
PRIVATE_SG_ID=$PRIVATE_SG_ID
PRIVATE_INSTANCE_ID=$PRIVATE_INSTANCE_ID
PRIVATE_IP=$PRIVATE_IP
KEY_NAME=$KEY_NAME
EOF

echo ""
echo "Variables saved to vars.env."

# ------------------------------------------------
# Step 9: Verify
# ------------------------------------------------

echo ""
echo "=========================================="
echo "      PRIVATE INSTANCE VERIFICATION"
echo "=========================================="

aws ec2 describe-instances \
    --instance-ids "$PRIVATE_INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].[InstanceId,InstanceType,State.Name,SubnetId,PrivateIpAddress,PublicIpAddress,KeyName]' \
    --output table

echo ""
echo "Security Group:"
echo "$PRIVATE_SG_ID"

echo ""
echo "REPORT:"
echo "Private instance launched successfully."
echo "Private IP : $PRIVATE_IP"
echo "Public IP  : None"
echo ""
echo "SSH access is allowed only from the bastion Security Group."
