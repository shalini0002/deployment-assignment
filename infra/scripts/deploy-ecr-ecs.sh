#!/bin/bash

# Deploy Flask Backend and Express Frontend using AWS ECR, ECS, and VPC
# This script creates a complete containerized deployment on AWS

set -e

# Configuration
AWS_REGION="us-east-1"
CLUSTER_NAME="task-manager-cluster"
SERVICE_NAME="task-manager-service"
TASK_DEFINITION_FAMILY="task-manager"
VPC_CIDR="10.0.0.0/16"
SUBNET_CIDR_1="10.0.1.0/24"
SUBNET_CIDR_2="10.0.2.0/24"

echo "🚀 Starting deployment of Task Manager using ECR, ECS, and VPC..."

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: $AWS_ACCOUNT_ID"

# Create ECR repositories
echo "📦 Creating ECR repositories..."
aws ecr create-repository --repository-name task-manager-backend --region $AWS_REGION || echo "Backend repository might already exist"
aws ecr create-repository --repository-name task-manager-frontend --region $AWS_REGION || echo "Frontend repository might already exist"

# Get ECR login token
echo "🔐 Logging into ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build and push backend image
echo "🔨 Building and pushing backend image..."
cd ../../backend-flask
docker build -t task-manager-backend .
docker tag task-manager-backend:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/task-manager-backend:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/task-manager-backend:latest

# Build and push frontend image
echo "🔨 Building and pushing frontend image..."
cd ../frontend-express
docker build -t task-manager-frontend .
docker tag task-manager-frontend:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/task-manager-frontend:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/task-manager-frontend:latest

cd ../infra

# Create VPC
echo "🌐 Creating VPC..."
VPC_ID=$(aws ec2 create-vpc \
    --cidr-block $VPC_CIDR \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=TaskManager-VPC}]' \
    --region $AWS_REGION \
    --query 'Vpc.VpcId' \
    --output text 2>/dev/null || \
    aws ec2 describe-vpcs \
        --filters "Name=tag:Name,Values=TaskManager-VPC" \
        --region $AWS_REGION \
        --query 'Vpcs[0].VpcId' \
        --output text)

echo "VPC ID: $VPC_ID"

# Enable DNS resolution for VPC
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-support --region $AWS_REGION
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames --region $AWS_REGION

# Create Internet Gateway
echo "🌍 Creating Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway \
    --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=TaskManager-IGW}]' \
    --region $AWS_REGION \
    --query 'InternetGateway.InternetGatewayId' \
    --output text 2>/dev/null || \
    aws ec2 describe-internet-gateways \
        --filters "Name=tag:Name,Values=TaskManager-IGW" \
        --region $AWS_REGION \
        --query 'InternetGateways[0].InternetGatewayId' \
        --output text)

# Attach Internet Gateway to VPC
aws ec2 attach-internet-gateway \
    --internet-gateway-id $IGW_ID \
    --vpc-id $VPC_ID \
    --region $AWS_REGION 2>/dev/null || echo "Internet Gateway might already be attached"

# Create public subnets
echo "🏠 Creating public subnets..."
SUBNET_ID_1=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block $SUBNET_CIDR_1 \
    --availability-zone ${AWS_REGION}a \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=TaskManager-Public-Subnet-1}]' \
    --region $AWS_REGION \
    --query 'Subnet.SubnetId' \
    --output text 2>/dev/null || \
    aws ec2 describe-subnets \
        --filters "Name=tag:Name,Values=TaskManager-Public-Subnet-1" \
        --region $AWS_REGION \
        --query 'Subnets[0].SubnetId' \
        --output text)

SUBNET_ID_2=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block $SUBNET_CIDR_2 \
    --availability-zone ${AWS_REGION}b \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=TaskManager-Public-Subnet-2}]' \
    --region $AWS_REGION \
    --query 'Subnet.SubnetId' \
    --output text 2>/dev/null || \
    aws ec2 describe-subnets \
        --filters "Name=tag:Name,Values=TaskManager-Public-Subnet-2" \
        --region $AWS_REGION \
        --query 'Subnets[0].SubnetId' \
        --output text)

# Enable auto-assign public IP for subnets
aws ec2 modify-subnet-attribute --subnet-id $SUBNET_ID_1 --map-public-ip-on-launch --region $AWS_REGION
aws ec2 modify-subnet-attribute --subnet-id $SUBNET_ID_2 --map-public-ip-on-launch --region $AWS_REGION

echo "Subnet IDs: $SUBNET_ID_1, $SUBNET_ID_2"

# Create route table
echo "🛣️  Creating route table..."
ROUTE_TABLE_ID=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=TaskManager-RouteTable}]' \
    --region $AWS_REGION \
    --query 'RouteTable.RouteTableId' \
    --output text 2>/dev/null || \
    aws ec2 describe-route-tables \
        --filters "Name=tag:Name,Values=TaskManager-RouteTable" \
        --region $AWS_REGION \
        --query 'RouteTables[0].RouteTableId' \
        --output text)

# Create route to Internet Gateway
aws ec2 create-route \
    --route-table-id $ROUTE_TABLE_ID \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $IGW_ID \
    --region $AWS_REGION 2>/dev/null || echo "Route might already exist"

# Associate route table with subnets
aws ec2 associate-route-table --subnet-id $SUBNET_ID_1 --route-table-id $ROUTE_TABLE_ID --region $AWS_REGION 2>/dev/null || echo "Association might already exist"
aws ec2 associate-route-table --subnet-id $SUBNET_ID_2 --route-table-id $ROUTE_TABLE_ID --region $AWS_REGION 2>/dev/null || echo "Association might already exist"

# Create security group
echo "🔒 Creating security group..."
SECURITY_GROUP_ID=$(aws ec2 create-security-group \
    --group-name TaskManager-ECS-SG \
    --description "Security group for Task Manager ECS tasks" \
    --vpc-id $VPC_ID \
    --region $AWS_REGION \
    --query 'GroupId' \
    --output text 2>/dev/null || \
    aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=TaskManager-ECS-SG" \
        --region $AWS_REGION \
        --query 'SecurityGroups[0].GroupId' \
        --output text)

# Add security group rules
aws ec2 authorize-security-group-ingress \
    --group-id $SECURITY_GROUP_ID \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0 \
    --region $AWS_REGION 2>/dev/null || echo "HTTP rule might already exist"

aws ec2 authorize-security-group-ingress \
    --group-id $SECURITY_GROUP_ID \
    --protocol tcp \
    --port 5000 \
    --cidr 0.0.0.0/0 \
    --region $AWS_REGION 2>/dev/null || echo "Backend rule might already exist"

echo "Security Group ID: $SECURITY_GROUP_ID"

# Create ECS cluster
echo "🎯 Creating ECS cluster..."
aws ecs create-cluster \
    --cluster-name $CLUSTER_NAME \
    --region $AWS_REGION 2>/dev/null || echo "Cluster might already exist"

# Create task definition
echo "📋 Creating task definition..."
cat > task-definition.json << EOF
{
  "family": "$TASK_DEFINITION_FAMILY",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "arn:aws:iam::$AWS_ACCOUNT_ID:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "name": "backend",
      "image": "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/task-manager-backend:latest",
      "portMappings": [
        {
          "containerPort": 5000,
          "protocol": "tcp"
        }
      ],
      "essential": true,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/task-manager",
          "awslogs-region": "$AWS_REGION",
          "awslogs-stream-prefix": "backend"
        }
      }
    },
    {
      "name": "frontend",
      "image": "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/task-manager-frontend:latest",
      "portMappings": [
        {
          "containerPort": 3000,
          "protocol": "tcp"
        }
      ],
      "essential": true,
      "environment": [
        {
          "name": "BACKEND_URL",
          "value": "http://localhost:5000"
        }
      ],
      "dependsOn": [
        {
          "containerName": "backend",
          "condition": "START"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/task-manager",
          "awslogs-region": "$AWS_REGION",
          "awslogs-stream-prefix": "frontend"
        }
      }
    }
  ]
}
EOF

# Create CloudWatch log group
aws logs create-log-group --log-group-name /ecs/task-manager --region $AWS_REGION 2>/dev/null || echo "Log group might already exist"

# Register task definition
TASK_DEFINITION_ARN=$(aws ecs register-task-definition \
    --cli-input-json file://task-definition.json \
    --region $AWS_REGION \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text)

echo "Task Definition ARN: $TASK_DEFINITION_ARN"

# Create ECS service
echo "🚀 Creating ECS service..."
SERVICE_ARN=$(aws ecs create-service \
    --cluster $CLUSTER_NAME \
    --service-name $SERVICE_NAME \
    --task-definition $TASK_DEFINITION_FAMILY \
    --desired-count 1 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_ID_1,$SUBNET_ID_2],securityGroups=[$SECURITY_GROUP_ID],assignPublicIp=ENABLED}" \
    --region $AWS_REGION \
    --query 'service.serviceArn' \
    --output text 2>/dev/null || echo "Service might already exist")

echo "Service ARN: $SERVICE_ARN"

# Create Application Load Balancer
echo "⚖️  Creating Application Load Balancer..."
ALB_ARN=$(aws elbv2 create-load-balancer \
    --name TaskManager-ALB \
    --subnets $SUBNET_ID_1 $SUBNET_ID_2 \
    --security-groups $SECURITY_GROUP_ID \
    --region $AWS_REGION \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text 2>/dev/null || \
    aws elbv2 describe-load-balancers \
        --names TaskManager-ALB \
        --region $AWS_REGION \
        --query 'LoadBalancers[0].LoadBalancerArn' \
        --output text)

# Get ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns $ALB_ARN \
    --region $AWS_REGION \
    --query 'LoadBalancers[0].DNSName' \
    --output text)

echo "Load Balancer ARN: $ALB_ARN"
echo "Load Balancer DNS: $ALB_DNS"

# Create target group
echo "🎯 Creating target group..."
TARGET_GROUP_ARN=$(aws elbv2 create-target-group \
    --name TaskManager-TG \
    --protocol HTTP \
    --port 3000 \
    --vpc-id $VPC_ID \
    --target-type ip \
    --health-check-path /health \
    --region $AWS_REGION \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text 2>/dev/null || \
    aws elbv2 describe-target-groups \
        --names TaskManager-TG \
        --region $AWS_REGION \
        --query 'TargetGroups[0].TargetGroupArn' \
        --output text)

echo "Target Group ARN: $TARGET_GROUP_ARN"

# Create listener
aws elbv2 create-listener \
    --load-balancer-arn $ALB_ARN \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=$TARGET_GROUP_ARN \
    --region $AWS_REGION 2>/dev/null || echo "Listener might already exist"

# Wait for service to be stable
echo "⏳ Waiting for service to be stable..."
aws ecs wait services-stable \
    --cluster $CLUSTER_NAME \
    --services $SERVICE_NAME \
    --region $AWS_REGION

# Get task ARN
TASK_ARN=$(aws ecs list-tasks \
    --cluster $CLUSTER_NAME \
    --service-name $SERVICE_NAME \
    --region $AWS_REGION \
    --query 'taskArns[0]' \
    --output text)

# Register targets with ALB
echo "🎯 Registering targets with ALB..."
aws ecs describe-tasks \
    --cluster $CLUSTER_NAME \
    --tasks $TASK_ARN \
    --region $AWS_REGION \
    --query 'tasks[0].attachments[0].details' > task-details.json

# Extract network interface ID and IP
NETWORK_INTERFACE_ID=$(cat task-details.json | jq -r '.[] | select(.name=="networkInterfaceId") | .value')
PRIVATE_IP=$(aws ec2 describe-network-interfaces \
    --network-interface-ids $NETWORK_INTERFACE_ID \
    --region $AWS_REGION \
    --query 'NetworkInterfaces[0].PrivateIpAddress' \
    --output text)

echo "Registering IP $PRIVATE_IP with target group..."
aws elbv2 register-targets \
    --target-group-arn $TARGET_GROUP_ARN \
    --targets Id=$PRIVATE_IP,Port=3000 \
    --region $AWS_REGION 2>/dev/null || echo "Target might already be registered"

# Clean up temporary files
rm -f task-definition.json task-details.json

echo "🎉 Deployment Complete!"
echo "Load Balancer DNS: $ALB_DNS"
echo "Application URL: http://$ALB_DNS"
echo ""
echo "📝 Next Steps:"
echo "1. Wait 2-3 minutes for the load balancer to become healthy"
echo "2. Visit http://$ALB_DNS to access the Task Manager"
echo "3. Monitor the service: aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $AWS_REGION"
echo ""
echo "⚠️  Remember to clean up resources when done to avoid charges:"
echo "aws ecs delete-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --region $AWS_REGION"
echo "aws ecs delete-cluster --cluster $CLUSTER_NAME --region $AWS_REGION"
echo "aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN --region $AWS_REGION"
