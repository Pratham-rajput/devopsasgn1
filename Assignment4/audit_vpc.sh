#!/bin/bash

LOG_FILE="/var/log/vpc_audit.log"

echo "==========================================" >> "$LOG_FILE"
echo "VPC AUDIT - $(date)" >> "$LOG_FILE"
echo "==========================================" >> "$LOG_FILE"

# Load variables
if [ -f "$HOME/vars.env" ]; then
    source "$HOME/vars.env"
elif [ -f "$(dirname "$0")/vars.env" ]; then
    source "$(dirname "$0")/vars.env"
fi

# NAT Gateway state
echo "NAT Gateway:" >> "$LOG_FILE"

if [ -n "$NAT_GATEWAY_ID" ]; then
    aws ec2 describe-nat-gateways \
        --nat-gateway-ids "$NAT_GATEWAY_ID" \
        --query 'NatGateways[*].[NatGatewayId,State]' \
        --output text >> "$LOG_FILE"
else
    echo "NAT_GATEWAY_ID not found" >> "$LOG_FILE"
fi

# Public instance state
echo "Public Instance:" >> "$LOG_FILE"

if [ -n "$INSTANCE_ID" ]; then
    aws ec2 describe-instances \
        --instance-ids "$INSTANCE_ID" \
        --query 'Reservations[*].Instances[*].[InstanceId,State.Name]' \
        --output text >> "$LOG_FILE"
else
    echo "INSTANCE_ID not found" >> "$LOG_FILE"
fi

# Private instance state
echo "Private Instance:" >> "$LOG_FILE"

if [ -n "$PRIVATE_INSTANCE_ID" ]; then
    aws ec2 describe-instances \
        --instance-ids "$PRIVATE_INSTANCE_ID" \
        --query 'Reservations[*].Instances[*].[InstanceId,State.Name]' \
        --output text >> "$LOG_FILE"
else
    echo "PRIVATE_INSTANCE_ID not found" >> "$LOG_FILE"
fi

echo "" >> "$LOG_FILE"
