#!/bin/bash

# Deploy Flask Backend and Express Frontend on Single EC2 Instance
# This script sets up both applications on one EC2 instance with Nginx as reverse proxy

set -e

# Configuration
AWS_REGION="ap-south-1"
INSTANCE_TYPE="t3.micro"
KEY_NAME="task-manager-key"
SECURITY_GROUP_NAME="task-manager-sg"
AMI_ID="ami-0059e0da390478151" # Amazon Linux 2 AMI for ap-south-1
USER_DATA_FILE="user-data-single.sh"

echo "🚀 Starting deployment of Task Manager on Single EC2 Instance..."

# Create Security Group
echo "📋 Creating Security Group..."
aws ec2 create-security-group \
    --group-name $SECURITY_GROUP_NAME \
    --description "Security group for Task Manager application" \
    --region $AWS_REGION || echo "Security group might already exist"

# Add inbound rules
echo "🔒 Configuring Security Group rules..."
aws ec2 authorize-security-group-ingress \
    --group-name $SECURITY_GROUP_NAME \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0 \
    --region $AWS_REGION || echo "SSH rule might already exist"

aws ec2 authorize-security-group-ingress \
    --group-name $SECURITY_GROUP_NAME \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0 \
    --region $AWS_REGION || echo "HTTP rule might already exist"

aws ec2 authorize-security-group-ingress \
    --group-name $SECURITY_GROUP_NAME \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0 \
    --region $AWS_REGION || echo "HTTPS rule might already exist"

# Get Security Group ID
SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
    --group-names $SECURITY_GROUP_NAME \
    --region $AWS_REGION \
    --query 'SecurityGroups[0].GroupId' \
    --output text)

echo "Security Group ID: $SECURITY_GROUP_ID"

# Launch EC2 Instance
echo "🖥️  Launching EC2 Instance..."
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --count 1 \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SECURITY_GROUP_ID \
    --user-data file://user-data-single.sh \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=TaskManager-Single}]' \
    --region $AWS_REGION \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "Instance ID: $INSTANCE_ID"

# Wait for instance to be running
echo "⏳ Waiting for instance to be running..."
aws ec2 wait instance-running \
    --instance-ids $INSTANCE_ID \
    --region $AWS_REGION

# Get Public IP
PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --region $AWS_REGION \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

echo "🎉 Deployment Complete!"
echo "Instance ID: $INSTANCE_ID"
echo "Public IP: $PUBLIC_IP"
echo "Application URL: http://$PUBLIC_IP"
echo ""
echo "📝 Next Steps:"
echo "1. Wait 5-10 minutes for the application to fully start"
echo "2. Visit http://$PUBLIC_IP to access the Task Manager"
echo "3. SSH into the instance: ssh -i your-key.pem ec2-user@$PUBLIC_IP"
echo ""
echo "⚠️  Remember to stop the instance when done to avoid charges:"
echo "aws ec2 stop-instances --instance-ids $INSTANCE_ID --region $AWS_REGION"
