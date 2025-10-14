#!/bin/bash

# Deploy Flask Backend and Express Frontend on Separate EC2 Instances
# This script creates two EC2 instances: one for backend, one for frontend

set -e

# Configuration
AWS_REGION="us-east-1"
INSTANCE_TYPE="t3.micro"
KEY_NAME="your-key-pair"
SECURITY_GROUP_NAME="task-manager-sg"
AMI_ID="ami-0c02fb55956c7d316" # Amazon Linux 2 AMI

echo "🚀 Starting deployment of Task Manager on Separate EC2 Instances..."

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

aws ec2 authorize-security-group-ingress \
    --group-name $SECURITY_GROUP_NAME \
    --protocol tcp \
    --port 5000 \
    --cidr 0.0.0.0/0 \
    --region $AWS_REGION || echo "Backend API rule might already exist"

aws ec2 authorize-security-group-ingress \
    --group-name $SECURITY_GROUP_NAME \
    --protocol tcp \
    --port 3000 \
    --cidr 0.0.0.0/0 \
    --region $AWS_REGION || echo "Frontend rule might already exist"

# Get Security Group ID
SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
    --group-names $SECURITY_GROUP_NAME \
    --region $AWS_REGION \
    --query 'SecurityGroups[0].GroupId' \
    --output text)

echo "Security Group ID: $SECURITY_GROUP_ID"

# Launch Backend EC2 Instance
echo "🖥️  Launching Backend EC2 Instance..."
BACKEND_INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --count 1 \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SECURITY_GROUP_ID \
    --user-data file://user-data-backend.sh \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=TaskManager-Backend}]' \
    --region $AWS_REGION \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "Backend Instance ID: $BACKEND_INSTANCE_ID"

# Launch Frontend EC2 Instance
echo "🖥️  Launching Frontend EC2 Instance..."
FRONTEND_INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --count 1 \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SECURITY_GROUP_ID \
    --user-data file://user-data-frontend.sh \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=TaskManager-Frontend}]' \
    --region $AWS_REGION \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "Frontend Instance ID: $FRONTEND_INSTANCE_ID"

# Wait for instances to be running
echo "⏳ Waiting for instances to be running..."
aws ec2 wait instance-running \
    --instance-ids $BACKEND_INSTANCE_ID $FRONTEND_INSTANCE_ID \
    --region $AWS_REGION

# Get Public IPs
BACKEND_PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids $BACKEND_INSTANCE_ID \
    --region $AWS_REGION \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

FRONTEND_PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids $FRONTEND_INSTANCE_ID \
    --region $AWS_REGION \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

echo "🎉 Deployment Complete!"
echo "Backend Instance ID: $BACKEND_INSTANCE_ID"
echo "Backend Public IP: $BACKEND_PUBLIC_IP"
echo "Backend API URL: http://$BACKEND_PUBLIC_IP:5000"
echo ""
echo "Frontend Instance ID: $FRONTEND_INSTANCE_ID"
echo "Frontend Public IP: $FRONTEND_PUBLIC_IP"
echo "Frontend URL: http://$FRONTEND_PUBLIC_IP:3000"
echo ""
echo "📝 Next Steps:"
echo "1. Wait 5-10 minutes for both applications to fully start"
echo "2. Update frontend configuration to point to backend IP: $BACKEND_PUBLIC_IP"
echo "3. Visit http://$FRONTEND_PUBLIC_IP:3000 to access the Task Manager"
echo ""
echo "⚠️  Remember to stop the instances when done to avoid charges:"
echo "aws ec2 stop-instances --instance-ids $BACKEND_INSTANCE_ID $FRONTEND_INSTANCE_ID --region $AWS_REGION"
