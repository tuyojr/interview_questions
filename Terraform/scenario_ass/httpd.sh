#!/bin/bash
set -e

# I'm using the IP address for aws to fetch instance metadata.
# https://stackoverflow.com/a/42315582
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-metadata.html
# read more here: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instancedata-data-retrieval.html#instancedata-inside-access
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null)
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)
PRIVATE_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/local-ipv4)
AZ=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/availability-zone)

sudo yum update -y
sudo yum install -y httpd

# custom home page
cat > /var/www/html/index.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TechCorp Web Application</title>
    <style>
        body {
            font-family: 'Segoe UI', sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            margin: 0;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 16px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            padding: 40px;
            max-width: 500px;
            text-align: center;
        }
        h1 { color: #333; margin-bottom: 30px; }
        .info { 
            background: #f5f5f5; 
            border-radius: 8px; 
            padding: 20px; 
            text-align: left;
            margin: 20px 0;
        }
        .info div { 
            padding: 8px 0; 
            border-bottom: 1px solid #ddd; 
        }
        .info div:last-child { border: none; }
        .label { color: #666; }
        .value { font-family: monospace; color: #333; float: right; }
        .status {
            background: #28a745;
            color: white;
            padding: 8px 20px;
            border-radius: 20px;
            display: inline-block;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 TechCorp Web App</h1>
        <div class="info">
            <div><span class="label">Instance ID:</span><span class="value">$INSTANCE_ID</span></div>
            <div><span class="label">Private IP:</span><span class="value">$PRIVATE_IP</span></div>
            <div><span class="label">Availability Zone:</span><span class="value">$AZ</span></div>
        </div>
        <span class="status">✅ Healthy</span>
    </div>
</body>
</html>
EOF

sudo chown -R apache:apache /var/www/html/
sudo chmod -R 755 /var/www/html/

sudo systemctl enable httpd
sudo systemctl start httpd

echo "Web server setup completed at $(date)." >> /var/log/user-data.log
