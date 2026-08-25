#!/bin/bash

# Update packages
apt update -y

# Install NGINX
apt install -y nginx

# Start NGINX
systemctl start nginx

# Enable NGINX at boot
systemctl enable nginx

# Create custom web page
cat > /var/www/html/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Assignment 6 Web Server</title>
</head>
<body>
    <h1>Hello from Terraform!</h1>
    <p>NGINX was installed and configured using provisioners.sh</p>
</body>
</html>
EOF

# Restart NGINX
systemctl restart nginx
