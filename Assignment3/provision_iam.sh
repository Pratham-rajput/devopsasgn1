#!/bin/bash

# ==========================================
# AWS IAM USER PROVISIONING SCRIPT
# ==========================================

INPUT_FILE="users.csv"
CLEAN_FILE="users_clean.csv"
LOG_FILE="provision.log"
ERROR_LOG="errors.log"

> "$LOG_FILE"
> "$ERROR_LOG"
# IAM Policy ARNs
READONLY_POLICY="arn:aws:iam::aws:policy/ReadOnlyAccess"
POWERUSER_POLICY="arn:aws:iam::aws:policy/PowerUserAccess"


echo "=========================================="
echo "       AWS IAM USER PROVISIONING"
echo "=========================================="

# Check whether input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "ERROR: $INPUT_FILE not found."
    exit 1
fi

# ------------------------------------------------
# Step 1: Clean Windows line endings and whitespace
# ------------------------------------------------

echo ""
echo "Step 1: Cleaning CSV file..."

sed 's/\r$//' "$INPUT_FILE" | sed 's/[[:space:]]*$//' > "$CLEAN_FILE"

echo "Cleaned file created: $CLEAN_FILE"

# ------------------------------------------------
# Step 2: Count records
# ------------------------------------------------

TOTAL=$(awk 'NR > 1 && NF > 0 {count++} END {print count+0}' "$CLEAN_FILE")

echo ""
echo "Processing $TOTAL users..."

# ------------------------------------------------
# Step 3: Validate records
# ------------------------------------------------

VALID=0
REJECTED=0

echo ""
echo "=========================================="
echo "           VALIDATION RESULTS"
echo "=========================================="

# Skip header and process every row
 while IFS=',' read -r username department access_level
do

    # Remove possible whitespace
    username=$(echo "$username" | sed 's/[[:space:]]*$//')
    department=$(echo "$department" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    access_level=$(echo "$access_level" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Skip empty lines
    [ -z "$username$department$access_level" ] && continue

    # Username validation using grep
    if ! echo "$username" | grep -Eq '^[a-z]+\.[a-z]+$'; then
        echo "REJECTED: $username - invalid username format"
        REJECTED=$((REJECTED + 1))
        continue
    fi
# --------------------------------------
# Create IAM user and attach policy
# --------------------------------------

echo ""
echo "Processing IAM user: $username"

# Check if IAM user already exists
aws iam get-user --user-name "$username" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "SKIPPED: already exists - $username"
    continue
fi

# Create IAM user
aws iam create-user --user-name "$username"

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create IAM user: $username" >> errors.log
    echo "FAILED: Could not create user $username"
    continue
fi

echo "IAM user created successfully: $username"
echo "SUCCESS: $username | USER_CREATED" >> "$LOG_FILE"

# Select policy based on access level
case "$access_level" in

    readonly)
        POLICY_ARN="$READONLY_POLICY"
        echo "Access level: readonly"
        echo "Policy: $POLICY_ARN"
        ;;

    poweruser)
        POLICY_ARN="$POWERUSER_POLICY"
        echo "Access level: poweruser"
        echo "Policy: $POLICY_ARN"
        ;;

    admin)
        echo "Access level: admin"
        echo "Creating custom least-privilege policy for department: $department"

        POLICY_NAME="${username}-${department}-AdminPolicy"

        POLICY_DOCUMENT=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:Describe*",
                "s3:ListAllMyBuckets",
                "s3:GetBucketLocation"
            ],
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "aws:ResourceTag/Department": "$department"
                }
            }
        }
    ]
}
EOF
)

        POLICY_ARN=$(aws iam create-policy \
            --policy-name "$POLICY_NAME" \
            --policy-document "$POLICY_DOCUMENT" \
            --query 'Policy.Arn' \
            --output text)

        if [ $? -ne 0 ]; then
            echo "ERROR: Failed to create custom policy for $username" >> errors.log
            echo "FAILED: Could not create custom policy for $username"
            continue
        fi

        echo "Custom policy created: $POLICY_ARN"
        ;;

esac

# Attach policy to IAM user
echo "Attaching policy to $username..."

aws iam attach-user-policy \
    --user-name "$username" \
    --policy-arn "$POLICY_ARN"

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to attach policy for $username" >> errors.log
    echo "FAILED: Could not attach policy to $username"
    continue
fi

echo "Policy attached successfully to $username"
echo "SUCCESS: $username | POLICY_ATTACHED | $POLICY_ARN" >> "$LOG_FILE"

VALID=$((VALID + 1))

    # Department validation using awk
    department_check=$(echo "$department" | awk '
        {
            if ($0 == "")
                print "empty"
            else
                print "valid"
        }
    ')

    if [ "$department_check" = "empty" ]; then
        echo "REJECTED: $username - department is empty"
        REJECTED=$((REJECTED + 1))
        continue
    fi

    # Access level validation using awk
    access_check=$(echo "$access_level" | awk '
        {
            if ($0 == "readonly" || $0 == "poweruser" || $0 == "admin")
                print "valid"
            else
                print "invalid"
        }
    ')

    if [ "$access_check" = "invalid" ]; then
        echo "REJECTED: $username - invalid access_level: $access_level"
        REJECTED=$((REJECTED + 1))
        continue
    fi

    echo "VALID: $username | $department | $access_level"
    VALID=$((VALID + 1))

done < <(tail -n +2 "$CLEAN_FILE")

# ------------------------------------------------
# Step 4: Validation summary
# ------------------------------------------------

echo ""
echo "=========================================="
echo "         VALIDATION SUMMARY"
echo "=========================================="
echo "Total records : $TOTAL"
echo "Valid rows    : $VALID"
echo "Rejected rows : $REJECTED"
echo "=========================================="
# ==========================================
# FINAL REPORT
# ==========================================

echo ""
echo "=========================================="
echo "              FINAL REPORT"
echo "=========================================="

echo ""
echo "Total users processed:"
grep -E "SUCCESS:|FAILURE:|SKIPPED:" "$LOG_FILE" | wc -l

echo ""
echo "Successful creations:"
grep "USER_CREATED" "$LOG_FILE" | wc -l

echo ""
echo "Failures:"
grep "FAILURE:" "$LOG_FILE" | wc -l

echo ""
echo "Users and Policies:"
echo "------------------------------------------"

printf "%-20s | %s\n" "USERNAME" "POLICY"
printf "%-20s-+-%s\n" "--------------------" "------------------------------"

awk -F' \| ' '
/POLICY_ATTACHED/ {
    username=$2
    policy=$4
    print username " | " policy
}' "$LOG_FILE" | column -t -s '|'

echo ""
echo "=========================================="
echo "Report generated from: $LOG_FILE"
echo "=========================================="
