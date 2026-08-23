#!/bin/bash

echo "=========================================="
echo "       NGINX SERVER MANAGEMENT SCRIPT"
echo "=========================================="

# a. Check whether nginx is installed
echo ""
echo "STEP 1: Checking whether Nginx is installed..."
if command -v nginx >/dev/null 2>&1; then
    echo "Nginx is already installed."
else
    echo "Nginx is not installed. Installing Nginx..."
    sudo apt update
    sudo apt install nginx -y
    echo "Nginx installation completed."
fi

# b. Start nginx and print status
echo ""
echo "STEP 2: Starting Nginx..."
sudo systemctl start nginx

echo "Nginx Status:"
sudo systemctl status nginx --no-pager

# c. List /var/www/html/
echo ""
echo "STEP 3: Contents of /var/www/html/:"
sudo ls -l /var/www/html/

# d. Backup existing index.html and create custom page
echo ""
echo "STEP 4: Backing up existing index.html..."

if [ -f /var/www/html/index.html ]; then
    sudo cp /var/www/html/index.html /var/www/html/index.html.bak
    echo "Backup created: /var/www/html/index.html.bak"
else
    echo "No existing index.html found."
fi

echo "Creating custom index.html..."

sudo bash -c 'cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>DevOps Assignment 2</title>
</head>
<body>
    <h1>Welcome to My Nginx Server</h1>
    <p>Nginx is successfully installed and running.</p>
    <p>This page was created using a Bash script.</p>
</body>
</html>
EOF'

echo "Custom HTML page created successfully."

# e. Reload nginx
echo ""
echo "STEP 5: Reloading Nginx..."
sudo systemctl reload nginx
echo "Nginx reloaded successfully."

# f. Display system resource usage
echo ""
echo "STEP 6: SYSTEM RESOURCE USAGE"
echo "------------------------------------------"

echo ""
echo "CPU / PROCESS USAGE:"
top -bn1 | head -15

echo ""
echo "MEMORY USAGE:"
free -h

echo ""
echo "DISK USAGE:"
df -h

# g. Final nginx status
echo ""
echo "STEP 7: FINAL NGINX STATUS"
echo "------------------------------------------"
sudo systemctl status nginx --no-pager

echo ""
echo "=========================================="
echo "       NGINX SCRIPT COMPLETED"
echo "=========================================="
