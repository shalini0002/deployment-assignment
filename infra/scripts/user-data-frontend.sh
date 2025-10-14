#!/bin/bash

# User Data Script for Frontend EC2 Instance
# This script installs and configures Express frontend

set -e

# Update system
yum update -y

# Install required packages
yum install -y nodejs npm

# Create application directory
mkdir -p /opt/task-manager/frontend
cd /opt/task-manager/frontend

# Create package.json
cat > package.json << 'EOF'
{
  "name": "task-manager-frontend",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "axios": "^1.5.0",
    "path": "^0.12.7",
    "morgan": "^1.10.0"
  }
}
EOF

# Create Express server
cat > server.js << 'EOF'
const express = require('express');
const cors = require('cors');
const path = require('path');
const morgan = require('morgan');
const axios = require('axios');

const app = express();
const PORT = process.env.PORT || 3000;

// Backend API URL - will be set via environment variable
const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:5000';

// Middleware
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'express-frontend',
    backend_url: BACKEND_URL
  });
});

// API proxy endpoints to forward requests to Flask backend
app.get('/api/tasks', async (req, res) => {
  try {
    const response = await axios.get(`${BACKEND_URL}/tasks`);
    res.json(response.data);
  } catch (error) {
    console.error('Error fetching tasks:', error.message);
    res.status(500).json({ error: 'Failed to fetch tasks from backend' });
  }
});

app.post('/api/tasks', async (req, res) => {
  try {
    const response = await axios.post(`${BACKEND_URL}/tasks`, req.body);
    res.status(response.status).json(response.data);
  } catch (error) {
    console.error('Error creating task:', error.message);
    res.status(500).json({ error: 'Failed to create task' });
  }
});

app.get('/api/tasks/:id', async (req, res) => {
  try {
    const response = await axios.get(`${BACKEND_URL}/tasks/${req.params.id}`);
    res.json(response.data);
  } catch (error) {
    console.error('Error fetching task:', error.message);
    res.status(500).json({ error: 'Failed to fetch task from backend' });
  }
});

app.put('/api/tasks/:id', async (req, res) => {
  try {
    const response = await axios.put(`${BACKEND_URL}/tasks/${req.params.id}`, req.body);
    res.json(response.data);
  } catch (error) {
    console.error('Error updating task:', error.message);
    res.status(500).json({ error: 'Failed to update task' });
  }
});

app.delete('/api/tasks/:id', async (req, res) => {
  try {
    const response = await axios.delete(`${BACKEND_URL}/tasks/${req.params.id}`);
    res.json(response.data);
  } catch (error) {
    console.error('Error deleting task:', error.message);
    res.status(500).json({ error: 'Failed to delete task' });
  }
});

// Serve React app for all other routes
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Frontend server running on port ${PORT}`);
  console.log(`Backend URL: ${BACKEND_URL}`);
});
EOF

# Create public directory and HTML file
mkdir -p public

cat > public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Task Manager</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            color: #333;
            padding: 20px;
        }
        
        .container {
            max-width: 800px;
            margin: 0 auto;
            background: white;
            border-radius: 10px;
            padding: 30px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
        }
        
        h1 {
            text-align: center;
            color: #667eea;
            margin-bottom: 30px;
            font-size: 2.5rem;
        }
        
        .form-group {
            margin-bottom: 20px;
        }
        
        input, textarea {
            width: 100%;
            padding: 12px;
            border: 2px solid #e1e5e9;
            border-radius: 8px;
            font-size: 16px;
            transition: border-color 0.3s;
        }
        
        input:focus, textarea:focus {
            outline: none;
            border-color: #667eea;
        }
        
        button {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 12px 24px;
            border: none;
            border-radius: 8px;
            cursor: pointer;
            font-size: 16px;
            font-weight: 600;
            transition: transform 0.2s;
        }
        
        button:hover {
            transform: translateY(-2px);
        }
        
        .task {
            background: #f8f9fa;
            padding: 20px;
            margin: 15px 0;
            border-radius: 8px;
            border-left: 4px solid #667eea;
            transition: all 0.3s;
        }
        
        .task:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 15px rgba(0,0,0,0.1);
        }
        
        .task.completed {
            opacity: 0.7;
            border-left-color: #28a745;
        }
        
        .task.completed .task-title {
            text-decoration: line-through;
            color: #6c757d;
        }
        
        .task-title {
            font-weight: bold;
            margin-bottom: 8px;
            font-size: 1.2rem;
        }
        
        .task-description {
            color: #666;
            margin-bottom: 15px;
            line-height: 1.5;
        }
        
        .task-actions {
            display: flex;
            gap: 10px;
        }
        
        .btn-sm {
            padding: 8px 16px;
            font-size: 14px;
            border-radius: 6px;
        }
        
        .btn-success {
            background: #28a745;
        }
        
        .btn-danger {
            background: #dc3545;
        }
        
        .loading {
            text-align: center;
            padding: 20px;
            color: #667eea;
        }
        
        .error {
            background: #f8d7da;
            color: #721c24;
            padding: 15px;
            border-radius: 8px;
            margin-bottom: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>📝 Task Manager</h1>
        
        <div id="error" class="error" style="display: none;"></div>
        
        <form id="taskForm">
            <div class="form-group">
                <input type="text" id="taskTitle" placeholder="Task title" required>
            </div>
            <div class="form-group">
                <textarea id="taskDescription" placeholder="Task description" rows="3"></textarea>
            </div>
            <button type="submit">Add Task</button>
        </form>
        
        <div id="tasks"></div>
    </div>

    <script>
        let backendUrl = 'http://localhost:5000'; // This will be updated based on environment
        
        function showError(message) {
            const errorDiv = document.getElementById('error');
            errorDiv.textContent = message;
            errorDiv.style.display = 'block';
            setTimeout(() => {
                errorDiv.style.display = 'none';
            }, 5000);
        }

        async function fetchTasks() {
            try {
                document.getElementById('tasks').innerHTML = '<div class="loading">Loading tasks...</div>';
                const response = await fetch('/api/tasks');
                const tasks = await response.json();
                displayTasks(tasks);
            } catch (error) {
                console.error('Error fetching tasks:', error);
                showError('Failed to fetch tasks. Please check if backend is running.');
            }
        }

        function displayTasks(tasks) {
            const container = document.getElementById('tasks');
            if (tasks.length === 0) {
                container.innerHTML = '<div class="loading">No tasks yet. Add one above to get started!</div>';
                return;
            }
            
            container.innerHTML = tasks.map(task => `
                <div class="task ${task.completed ? 'completed' : ''}" data-task-id="${task.id}">
                    <div class="task-title">${task.title}</div>
                    <div class="task-description">${task.description || ''}</div>
                    <div class="task-actions">
                        <button class="btn-sm ${task.completed ? 'btn-danger' : 'btn-success'}" onclick="toggleTask(${task.id})">
                            ${task.completed ? 'Undo' : 'Complete'}
                        </button>
                        <button class="btn-sm btn-danger" onclick="deleteTask(${task.id})">Delete</button>
                    </div>
                </div>
            `).join('');
        }

        async function addTask(title, description) {
            try {
                const response = await fetch('/api/tasks', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ title, description, completed: false })
                });
                
                if (response.ok) {
                    fetchTasks();
                    document.getElementById('taskForm').reset();
                } else {
                    const error = await response.json();
                    showError(error.error || 'Failed to create task');
                }
            } catch (error) {
                console.error('Error adding task:', error);
                showError('Failed to create task. Please try again.');
            }
        }

        async function toggleTask(id) {
            try {
                const taskElement = document.querySelector(`[data-task-id="${id}"]`);
                const isCompleted = taskElement.classList.contains('completed');
                
                const response = await fetch(`/api/tasks/${id}`, {
                    method: 'PUT',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ completed: !isCompleted })
                });
                
                if (response.ok) {
                    fetchTasks();
                } else {
                    const error = await response.json();
                    showError(error.error || 'Failed to update task');
                }
            } catch (error) {
                console.error('Error toggling task:', error);
                showError('Failed to update task. Please try again.');
            }
        }

        async function deleteTask(id) {
            if (confirm('Are you sure you want to delete this task?')) {
                try {
                    const response = await fetch(`/api/tasks/${id}`, { method: 'DELETE' });
                    if (response.ok) {
                        fetchTasks();
                    } else {
                        const error = await response.json();
                        showError(error.error || 'Failed to delete task');
                    }
                } catch (error) {
                    console.error('Error deleting task:', error);
                    showError('Failed to delete task. Please try again.');
                }
            }
        }

        document.getElementById('taskForm').addEventListener('submit', (e) => {
            e.preventDefault();
            const title = document.getElementById('taskTitle').value.trim();
            const description = document.getElementById('taskDescription').value.trim();
            
            if (!title) {
                showError('Please enter a task title');
                return;
            }
            
            addTask(title, description);
        });

        // Initialize the app
        fetchTasks();
    </script>
</body>
</html>
EOF

# Install Node.js dependencies
npm install

# Create systemd service
cat > /etc/systemd/system/express-frontend.service << 'EOF'
[Unit]
Description=Express Frontend Service
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/task-manager/frontend
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=3
Environment=PORT=3000
Environment=BACKEND_URL=http://YOUR_BACKEND_IP:5000

[Install]
WantedBy=multi-user.target
EOF

# Set permissions
chown -R ec2-user:ec2-user /opt/task-manager

# Enable and start service
systemctl daemon-reload
systemctl enable express-frontend
systemctl start express-frontend

echo "✅ Express Frontend deployment completed successfully!"
echo "⚠️  Don't forget to update BACKEND_URL in the systemd service file!"
