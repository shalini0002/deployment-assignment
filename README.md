# Task Manager - AWS Deployment Assignment

A full-stack Task Manager application with Flask backend and Express.js frontend, designed for deployment on AWS using three different approaches.

## 🏗️ Architecture

- **Backend**: Flask REST API with SQLite database
- **Frontend**: Express.js server with React components
- **Database**: SQLite (file-based, perfect for demos)
- **Reverse Proxy**: Nginx (for single EC2 deployment)

## 📁 Project Structure

```
deployment-assignment/
├── backend-flask/
│   ├── app.py                 # Flask application
│   ├── requirements.txt       # Python dependencies
│   └── Dockerfile            # Backend container config
├── frontend-express/
│   ├── src/                  # React source code
│   │   ├── components/       # React components
│   │   ├── App.js           # Main React app
│   │   ├── index.js         # Entry point
│   │   ├── index.html       # HTML template
│   │   └── styles.css       # Styling
│   ├── server.js            # Express server
│   ├── package.json         # Node.js dependencies
│   ├── webpack.config.js    # Webpack configuration
│   └── Dockerfile           # Frontend container config
├── infra/
│   ├── scripts/             # Deployment scripts
│   │   ├── deploy-single-ec2.sh      # Single EC2 deployment
│   │   ├── deploy-separate-ec2.sh    # Separate EC2s deployment
│   │   ├── deploy-ecr-ecs.sh         # ECS deployment
│   │   ├── user-data-single.sh       # Single EC2 setup script
│   │   ├── user-data-backend.sh      # Backend EC2 setup script
│   │   └── user-data-frontend.sh     # Frontend EC2 setup script
│   └── ecs-task-definitions/
│       └── task-definition.json      # ECS task definition
└── nginx/
    └── nginx.conf            # Nginx reverse proxy config
```

## 🚀 Deployment Options

### Option 1: Single EC2 Instance

Deploy both backend and frontend on a single EC2 instance with Nginx as reverse proxy.

**Prerequisites:**
- AWS CLI configured
- EC2 key pair created
- Appropriate IAM permissions

**Steps:**
1. Update the `KEY_NAME` variable in `deploy-single-ec2.sh`
2. Run the deployment script:
   ```bash
   cd infra/scripts
   chmod +x deploy-single-ec2.sh
   ./deploy-single-ec2.sh
   ```

**Features:**
- Both applications run on one instance
- Nginx handles routing and load balancing
- Cost-effective for small deployments
- Easy to manage and monitor

### Option 2: Separate EC2 Instances

Deploy backend and frontend on separate EC2 instances for better scalability.

**Steps:**
1. Update the `KEY_NAME` variable in `deploy-separate-ec2.sh`
2. Run the deployment script:
   ```bash
   cd infra/scripts
   chmod +x deploy-separate-ec2.sh
   ./deploy-separate-ec2.sh
   ```
3. Update the backend URL in the frontend instance:
   ```bash
   # SSH into frontend instance and update the environment variable
   sudo systemctl edit express-frontend
   # Add: Environment=BACKEND_URL=http://BACKEND_IP:5000
   sudo systemctl restart express-frontend
   ```

**Features:**
- Independent scaling of frontend and backend
- Better fault isolation
- Can use different instance types for each service
- More realistic production-like setup

### Option 3: ECS with ECR and VPC

Deploy using AWS ECS Fargate with containerized applications.

**Prerequisites:**
- Docker installed locally
- AWS CLI configured
- ECS Task Execution Role exists (created automatically by AWS)

**Steps:**
1. Run the deployment script:
   ```bash
   cd infra/scripts
   chmod +x deploy-ecr-ecs.sh
   ./deploy-ecr-ecs.sh
   ```

**Features:**
- Fully managed container orchestration
- Auto-scaling capabilities
- Load balancer integration
- VPC networking for security
- CloudWatch logging
- Production-ready setup

## 🛠️ Local Development

### Backend Development

```bash
cd backend-flask
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
python app.py
```

Backend will be available at `http://localhost:5000`

### Frontend Development

```bash
cd frontend-express
npm install
npm run dev:react  # For development with hot reload
```

Frontend will be available at `http://localhost:3000`

### Docker Development

```bash
# Build and run backend
cd backend-flask
docker build -t task-manager-backend .
docker run -p 5000:5000 task-manager-backend

# Build and run frontend
cd frontend-express
docker build -t task-manager-frontend .
docker run -p 3000:3000 task-manager-frontend
```

## 📋 API Endpoints

### Backend API (Flask)

- `GET /` - API information and available endpoints
- `GET /health` - Health check endpoint
- `GET /tasks` - Get all tasks
- `POST /tasks` - Create a new task
- `GET /tasks/<id>` - Get a specific task
- `PUT /tasks/<id>` - Update a task
- `DELETE /tasks/<id>` - Delete a task

### Frontend API (Express Proxy)

- `GET /health` - Frontend health check
- `GET /api/tasks` - Proxy to backend tasks endpoint
- `POST /api/tasks` - Proxy to backend create task
- `PUT /api/tasks/:id` - Proxy to backend update task
- `DELETE /api/tasks/:id` - Proxy to backend delete task

## 🔧 Configuration

### Environment Variables

**Backend:**
- `PORT` - Server port (default: 5000)
- `FLASK_ENV` - Environment mode (development/production)

**Frontend:**
- `PORT` - Server port (default: 3000)
- `BACKEND_URL` - Backend API URL (default: http://localhost:5000)
- `NODE_ENV` - Environment mode (development/production)

### Database

The application uses SQLite for simplicity. In production, consider using:
- PostgreSQL with RDS
- MySQL with RDS
- DynamoDB for serverless architecture

## 🔒 Security Considerations

- CORS enabled for cross-origin requests
- Input validation on API endpoints
- Security headers in Nginx configuration
- Non-root users in Docker containers
- VPC isolation for ECS deployment

## 📊 Monitoring and Logging

- Health check endpoints for both services
- CloudWatch logging for ECS deployment
- Systemd logging for EC2 deployments
- Application-level error handling

## 🧹 Cleanup

To avoid AWS charges, remember to clean up resources:

### Single EC2:
```bash
aws ec2 stop-instances --instance-ids INSTANCE_ID --region us-east-1
aws ec2 terminate-instances --instance-ids INSTANCE_ID --region us-east-1
```

### Separate EC2s:
```bash
aws ec2 stop-instances --instance-ids BACKEND_INSTANCE_ID FRONTEND_INSTANCE_ID --region us-east-1
aws ec2 terminate-instances --instance-ids BACKEND_INSTANCE_ID FRONTEND_INSTANCE_ID --region us-east-1
```

### ECS:
```bash
aws ecs delete-service --cluster task-manager-cluster --service task-manager-service --region us-east-1
aws ecs delete-cluster --cluster task-manager-cluster --region us-east-1
aws elbv2 delete-load-balancer --load-balancer-arn ALB_ARN --region us-east-1
```

## 🐛 Troubleshooting

### Common Issues:

1. **Permission Denied**: Ensure deployment scripts are executable (`chmod +x`)
2. **Port Conflicts**: Check if ports 80, 3000, 5000 are available
3. **Backend Connection**: Verify BACKEND_URL environment variable
4. **Health Check Failures**: Wait 2-3 minutes for services to fully start
5. **Docker Build Issues**: Ensure Docker is running and has sufficient resources

### Logs:

- **EC2**: Check `/var/log/cloud-init-output.log` for user-data script logs
- **ECS**: View logs in CloudWatch under `/ecs/task-manager`
- **Application**: Check systemd logs with `journalctl -u service-name`

## 📝 Assignment Submission

1. **GitHub Repository**: Push this code to your GitHub repository
2. **Deployment URLs**: Provide the URLs for each deployment method:
   - Single EC2: `http://EC2_PUBLIC_IP`
   - Separate EC2s: `http://FRONTEND_PUBLIC_IP:3000`
   - ECS: `http://ALB_DNS_NAME`

3. **Cost Management**: Stop/terminate instances when not in use to avoid charges

## 🤝 Contributing

This is an assignment project. For questions or issues, please refer to the assignment guidelines or contact the instructor.

## 📄 License

This project is created for educational purposes as part of a deployment assignment.
