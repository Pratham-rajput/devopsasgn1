#!/bin/bash

echo "=========================================="
echo "     STEP 5: LAUNCH PUBLIC WEB SERVER"
echo "=========================================="

# Load variables
source vars.env

if [ -z "$VPC_ID" ] || [ -z "$PUBLIC_SUBNET_ID" ]; then
    echo "ERROR: Required variables missing from vars.env"
    exit 1
fi

echo "VPC ID           : $VPC_ID"
echo "Public Subnet ID : $PUBLIC_SUBNET_ID"

# ------------------------------------------------
# Step 1: Find latest Ubuntu 24.04 LTS AMI
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
# Step 2: Create Security Group
# ------------------------------------------------

echo ""
echo "Creating security group..."

SG_ID=$(aws ec2 create-security-group \
    --group-name "DevOps-Assignment4-Web-SG" \
    --description "Allow HTTP access for Assignment 4 web server" \
    --vpc-id "$VPC_ID" \
    --query 'GroupId' \
    --output text)

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create security group."
    exit 1
fi

echo "Security Group ID: $SG_ID"

# Allow HTTP
aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to allow HTTP traffic."
    exit 1
fi

echo "HTTP port 80 allowed."

# ------------------------------------------------
# Step 3: User-data
# ------------------------------------------------

USER_DATA=$(cat <<'EOF'
#!/bin/bash

apt-get update -y
apt-get install -y nginx
systemctl enable nginx
systemctl start nginx

cat > /var/www/html/index.html <<'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>DevOps Assignment 4</title>
</head>
<body>
    <h1>Nginx Web Server is Running!</h1>
    <p>EC2 instance launched successfully using AWS CLI.</p>
</body>
</html>
HTML
EOF
)

# ------------------------------------------------
# Step 4: Launch EC2 instance
# ------------------------------------------------

echo ""
echo "Launching t3.micro instance..."

INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type t3.micro \
    --subnet-id "$PUBLIC_SUBNET_ID" \
    --security-group-ids "$SG_ID" \
    --associate-public-ip-address \
    --user-data "$USER_DATA" \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=DevOps-Assignment4-Web}]' \
    --query 'Instances[0].InstanceId' \
    --output text)

if [ $? -ne 0 ] || [ -z "$INSTANCE_ID" ]; then
    echo "ERROR: Failed to launch EC2 instance."
    exit 1
fi

echo "Instance launched successfully."
echo "Instance ID: $INSTANCE_ID"

# Save values
cat >> vars.env <<EOF
WEB_SG_ID=$SG_ID
INSTANCE_ID=$INSTANCE_ID
EOF

# ------------------------------------------------
# Step 5: Wait for instance to be running
# ------------------------------------------------

echo ""
echo "Waiting for instance to reach running state..."

aws ec2 wait instance-running \
    --instance-ids "$INSTANCE_ID"

if [ $? -ne 0 ]; then
    echo "ERROR: Instance did not reach running state."
    exit 1
fi

echo "Instance is running."

# ------------------------------------------------
# Step 6: Get public IP
# ------------------------------------------------

PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

echo "Public IP: $PUBLIC_IP"

echo "PUBLIC_IP=$PUBLIC_IP" >> vars.env

# ------------------------------------------------
# Step 7: Verify instance
# ------------------------------------------------

echo ""
echo "=========================================="
echo "       EC2 INSTANCE VERIFICATION"
echo "=========================================="

aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].[InstanceId,InstanceType,State.Name,SubnetId,PublicIpAddress]' \
    --output table

# ------------------------------------------------
# Step 8: HTTP test
# ------------------------------------------------

echo ""
echo "Waiting for Nginx to start..."

sleep 15

echo ""
echo "Testing HTTP connection..."

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout 10 \
    "http://$PUBLIC_IP")

if [ "$HTTP_STATUS" = "200" ]; then
    echo "SUCCESS: Nginx is reachable over HTTP."
    echo "HTTP Status: $HTTP_STATUS"
    echo "URL: http://$PUBLIC_IP"
else
    echo "WARNING: HTTP test returned status: $HTTP_STATUS"
    echo "Nginx may still be starting. Try again with:"
    echo "curl http://$PUBLIC_IP"
fi

echo ""
echo "=========================================="
echo "        STEP 5 COMPLETED"
echo "=========================================="
