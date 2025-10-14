#!/bin/bash

# Cleanup script for AWS resources
# This script helps clean up all resources created by the deployment scripts

set -e

AWS_REGION="us-east-1"
CLUSTER_NAME="task-manager-cluster"
SERVICE_NAME="task-manager-service"
SECURITY_GROUP_NAME="task-manager-sg"
ALB_NAME="TaskManager-ALB"
TARGET_GROUP_NAME="TaskManager-TG"
VPC_NAME="TaskManager-VPC"

echo "🧹 Starting cleanup of AWS resources..."

# Function to check if resource exists
resource_exists() {
    local resource_type=$1
    local resource_name=$2
    
    case $resource_type in
        "ecs-service")
            aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $AWS_REGION >/dev/null 2>&1
            ;;
        "ecs-cluster")
            aws ecs describe-clusters --clusters $CLUSTER_NAME --region $AWS_REGION >/dev/null 2>&1
            ;;
        "alb")
            aws elbv2 describe-load-balancers --names $ALB_NAME --region $AWS_REGION >/dev/null 2>&1
            ;;
        "target-group")
            aws elbv2 describe-target-groups --names $TARGET_GROUP_NAME --region $AWS_REGION >/dev/null 2>&1
            ;;
        "security-group")
            aws ec2 describe-security-groups --group-names $SECURITY_GROUP_NAME --region $AWS_REGION >/dev/null 2>&1
            ;;
        "vpc")
            aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$VPC_NAME" --region $AWS_REGION --query 'Vpcs[0].VpcId' --output text | grep -v "None"
            ;;
    esac
}

# Cleanup ECS resources
echo "🗑️  Cleaning up ECS resources..."

# Stop ECS service
if resource_exists "ecs-service"; then
    echo "Stopping ECS service..."
    aws ecs update-service \
        --cluster $CLUSTER_NAME \
        --service $SERVICE_NAME \
        --desired-count 0 \
        --region $AWS_REGION >/dev/null
    
    echo "Waiting for service to stop..."
    aws ecs wait services-stable \
        --cluster $CLUSTER_NAME \
        --services $SERVICE_NAME \
        --region $AWS_REGION
    
    echo "Deleting ECS service..."
    aws ecs delete-service \
        --cluster $CLUSTER_NAME \
        --service $SERVICE_NAME \
        --region $AWS_REGION
fi

# Delete ECS cluster
if resource_exists "ecs-cluster"; then
    echo "Deleting ECS cluster..."
    aws ecs delete-cluster \
        --cluster $CLUSTER_NAME \
        --region $AWS_REGION
fi

# Cleanup Load Balancer resources
echo "🗑️  Cleaning up Load Balancer resources..."

# Delete target group
if resource_exists "target-group"; then
    echo "Deleting target group..."
    TARGET_GROUP_ARN=$(aws elbv2 describe-target-groups \
        --names $TARGET_GROUP_NAME \
        --region $AWS_REGION \
        --query 'TargetGroups[0].TargetGroupArn' \
        --output text)
    
    aws elbv2 delete-target-group \
        --target-group-arn $TARGET_GROUP_ARN \
        --region $AWS_REGION
fi

# Delete load balancer
if resource_exists "alb"; then
    echo "Deleting Application Load Balancer..."
    ALB_ARN=$(aws elbv2 describe-load-balancers \
        --names $ALB_NAME \
        --region $AWS_REGION \
        --query 'LoadBalancers[0].LoadBalancerArn' \
        --output text)
    
    aws elbv2 delete-load-balancer \
        --load-balancer-arn $ALB_ARN \
        --region $AWS_REGION
fi

# Cleanup EC2 instances
echo "🗑️  Cleaning up EC2 instances..."

# Get instances with TaskManager tags
INSTANCE_IDS=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=TaskManager*" "Name=instance-state-name,Values=running,stopped,stopping,pending" \
    --region $AWS_REGION \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text)

if [ ! -z "$INSTANCE_IDS" ]; then
    echo "Found instances: $INSTANCE_IDS"
    read -p "Do you want to terminate these instances? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Terminating EC2 instances..."
        aws ec2 terminate-instances \
            --instance-ids $INSTANCE_IDS \
            --region $AWS_REGION
        
        echo "Waiting for instances to terminate..."
        aws ec2 wait instance-terminated \
            --instance-ids $INSTANCE_IDS \
            --region $AWS_REGION
    fi
fi

# Cleanup Security Groups
echo "🗑️  Cleaning up Security Groups..."
if resource_exists "security-group"; then
    echo "Deleting security group..."
    aws ec2 delete-security-group \
        --group-name $SECURITY_GROUP_NAME \
        --region $AWS_REGION
fi

# Cleanup VPC resources
echo "🗑️  Cleaning up VPC resources..."
VPC_ID=$(resource_exists "vpc")
if [ ! -z "$VPC_ID" ] && [ "$VPC_ID" != "None" ]; then
    echo "Found VPC: $VPC_ID"
    
    # Get and delete subnets
    SUBNET_IDS=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --region $AWS_REGION \
        --query 'Subnets[].SubnetId' \
        --output text)
    
    if [ ! -z "$SUBNET_IDS" ]; then
        echo "Deleting subnets: $SUBNET_IDS"
        for subnet_id in $SUBNET_IDS; do
            aws ec2 delete-subnet --subnet-id $subnet_id --region $AWS_REGION
        done
    fi
    
    # Get and delete route tables (except main)
    ROUTE_TABLE_IDS=$(aws ec2 describe-route-tables \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --region $AWS_REGION \
        --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' \
        --output text)
    
    if [ ! -z "$ROUTE_TABLE_IDS" ]; then
        echo "Deleting route tables: $ROUTE_TABLE_IDS"
        for rt_id in $ROUTE_TABLE_IDS; do
            aws ec2 delete-route-table --route-table-id $rt_id --region $AWS_REGION
        done
    fi
    
    # Get and delete internet gateways
    IGW_IDS=$(aws ec2 describe-internet-gateways \
        --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
        --region $AWS_REGION \
        --query 'InternetGateways[].InternetGatewayId' \
        --output text)
    
    if [ ! -z "$IGW_IDS" ]; then
        echo "Detaching and deleting internet gateways: $IGW_IDS"
        for igw_id in $IGW_IDS; do
            aws ec2 detach-internet-gateway \
                --internet-gateway-id $igw_id \
                --vpc-id $VPC_ID \
                --region $AWS_REGION
            aws ec2 delete-internet-gateway \
                --internet-gateway-id $igw_id \
                --region $AWS_REGION
        done
    fi
    
    # Delete VPC
    echo "Deleting VPC: $VPC_ID"
    aws ec2 delete-vpc --vpc-id $VPC_ID --region $AWS_REGION
fi

# Cleanup ECR repositories
echo "🗑️  Cleaning up ECR repositories..."
REPOS=("task-manager-backend" "task-manager-frontend")

for repo in "${REPOS[@]}"; do
    if aws ecr describe-repositories --repository-names $repo --region $AWS_REGION >/dev/null 2>&1; then
        echo "Deleting ECR repository: $repo"
        
        # Delete all images in the repository
        IMAGE_IDS=$(aws ecr list-images \
            --repository-name $repo \
            --region $AWS_REGION \
            --query 'imageIds[].imageDigest' \
            --output text)
        
        if [ ! -z "$IMAGE_IDS" ]; then
            aws ecr batch-delete-image \
                --repository-name $repo \
                --image-ids imageDigest=$IMAGE_IDS \
                --region $AWS_REGION
        fi
        
        aws ecr delete-repository \
            --repository-name $repo \
            --region $AWS_REGION \
            --force
    fi
done

# Cleanup CloudWatch log groups
echo "🗑️  Cleaning up CloudWatch log groups..."
LOG_GROUPS=("/ecs/task-manager")

for log_group in "${LOG_GROUPS[@]}"; do
    if aws logs describe-log-groups --log-group-name-prefix $log_group --region $AWS_REGION --query 'logGroups[0].logGroupName' --output text | grep -v "None"; then
        echo "Deleting log group: $log_group"
        aws logs delete-log-group \
            --log-group-name $log_group \
            --region $AWS_REGION
    fi
done

echo "✅ Cleanup completed successfully!"
echo "📋 Summary of cleaned resources:"
echo "   - ECS cluster and service"
echo "   - Application Load Balancer and target group"
echo "   - EC2 instances (if confirmed)"
echo "   - Security groups"
echo "   - VPC and networking resources"
echo "   - ECR repositories"
echo "   - CloudWatch log groups"
echo ""
echo "⚠️  Please verify that all resources have been cleaned up in the AWS Console"
