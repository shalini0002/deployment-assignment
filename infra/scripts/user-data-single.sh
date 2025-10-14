#!/bin/bash

# User Data Script for Single EC2 Instance Deployment
# This script installs and configures both Flask backend and Express frontend

set -e

# Update system
yum update -y

# Install required packages
yum install -y docker git nginx python3 python3-pip nodejs npm

# Start and enable Docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Start and enable Nginx
systemctl start nginx
systemctl enable nginx

# Create application directory
mkdir -p /opt/task-manager
cd /opt/task-manager

# Clone repository (replace with your actual repo)
# git clone https://github.com/your-username/deployment-assignment.git .

# For now, we'll create the applications directly
mkdir -p backend frontend

# Create Flask backend
cat > backend/app.py << 'EOF'
from flask import Flask, jsonify, request
from flask_cors import CORS
import sqlite3
from datetime import datetime
import os

app = Flask(__name__)
CORS(app)

def init_db():
    conn = sqlite3.connect('/opt/task-manager/tasks.db')
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS tasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            description TEXT,
            completed BOOLEAN DEFAULT FALSE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    conn.commit()
    conn.close()

init_db()

@app.route('/')
def home():
    return jsonify({
        'message': 'Flask Backend API is running!',
        'version': '1.0.0'
    })

@app.route('/health')
def health():
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'service': 'flask-backend'
    })

@app.route('/tasks', methods=['GET'])
def get_tasks():
    conn = sqlite3.connect('/opt/task-manager/tasks.db')
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM tasks ORDER BY created_at DESC')
    tasks = []
    for row in cursor.fetchall():
        tasks.append({
            'id': row[0],
            'title': row[1],
            'description': row[2],
            'completed': bool(row[3]),
            'created_at': row[4],
            'updated_at': row[5]
        })
    conn.close()
    return jsonify(tasks)

@app.route('/tasks', methods=['POST'])
def create_task():
    data = request.get_json()
    if not data or 'title' not in data:
        return jsonify({'error': 'Title is required'}), 400
    
    conn = sqlite3.connect('/opt/task-manager/tasks.db')
    cursor = conn.cursor()
    cursor.execute('''
        INSERT INTO tasks (title, description, completed)
        VALUES (?, ?, ?)
    ''', (data['title'], data.get('description', ''), data.get('completed', False)))
    
    task_id = cursor.lastrowid
    conn.commit()
    conn.close()
    
    return jsonify({
        'id': task_id,
        'title': data['title'],
        'description': data.get('description', ''),
        'completed': data.get('completed', False),
        'message': 'Task created successfully'
    }), 201

@app.route('/tasks/<int:task_id>', methods=['PUT'])
def update_task(task_id):
    data = request.get_json()
    conn = sqlite3.connect('/opt/task-manager/tasks.db')
    cursor = conn.cursor()
    cursor.execute('''
        UPDATE tasks 
        SET title = ?, description = ?, completed = ?, updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
    ''', (
        data.get('title'),
        data.get('description'),
        data.get('completed'),
        task_id
    ))
    conn.commit()
    conn.close()
    return jsonify({'message': 'Task updated successfully'})

@app.route('/tasks/<int:task_id>', methods=['DELETE'])
def delete_task(task_id):
    conn = sqlite3.connect('/opt/task-manager/tasks.db')
    cursor = conn.cursor()
    cursor.execute('DELETE FROM tasks WHERE id = ?', (task_id,))
    conn.commit()
    conn.close()
    return jsonify({'message': 'Task deleted successfully'})

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)
EOF

# Create requirements.txt for Flask
cat > backend/requirements.txt << 'EOF'
Flask==2.3.3
Flask-CORS==4.0.0
gunicorn==21.2.0
EOF

# Install Flask dependencies
pip3 install -r backend/requirements.txt

# Create Express frontend
cat > frontend/package.json << 'EOF'
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
    "axios": "^1.5.0"
  }
}
EOF

# Create Express server
cat > frontend/server.js << 'EOF'
const express = require('express');
const cors = require('cors');
const path = require('path');
const axios = require('axios');

const app = express();
const PORT = 3000;
const BACKEND_URL = 'http://localhost:5000';

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'express-frontend'
  });
});

app.get('/api/tasks', async (req, res) => {
  try {
    const response = await axios.get(`${BACKEND_URL}/tasks`);
    res.json(response.data);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch tasks' });
  }
});

app.post('/api/tasks', async (req, res) => {
  try {
    const response = await axios.post(`${BACKEND_URL}/tasks`, req.body);
    res.status(response.status).json(response.data);
  } catch (error) {
    res.status(500).json({ error: 'Failed to create task' });
  }
});

app.put('/api/tasks/:id', async (req, res) => {
  try {
    const response = await axios.put(`${BACKEND_URL}/tasks/${req.params.id}`, req.body);
    res.json(response.data);
  } catch (error) {
    res.status(500).json({ error: 'Failed to update task' });
  }
});

app.delete('/api/tasks/:id', async (req, res) => {
  try {
    const response = await axios.delete(`${BACKEND_URL}/tasks/${req.params.id}`);
    res.json(response.data);
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete task' });
  }
});

app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Frontend server running on port ${PORT}`);
});
EOF

# Create simple HTML frontend
mkdir -p frontend/public
cat > frontend/public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Task Manager</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; background: #f5f5f5; }
        .container { background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; text-align: center; }
        .form-group { margin-bottom: 15px; }
        input, textarea { width: 100%; padding: 10px; border: 1px solid #ddd; border-radius: 5px; }
        button { background: #007bff; color: white; padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer; }
        button:hover { background: #0056b3; }
        .task { background: #f8f9fa; padding: 15px; margin: 10px 0; border-radius: 5px; border-left: 4px solid #007bff; }
        .task.completed { opacity: 0.6; border-left-color: #28a745; }
        .task-title { font-weight: bold; margin-bottom: 5px; }
        .task-actions { margin-top: 10px; }
        .btn-sm { padding: 5px 10px; margin-right: 5px; font-size: 12px; }
        .btn-danger { background: #dc3545; }
        .btn-success { background: #28a745; }
    </style>
</head>
<body>
    <div class="container">
        <h1>📝 Task Manager</h1>
        
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
        async function fetchTasks() {
            try {
                const response = await fetch('/api/tasks');
                const tasks = await response.json();
                displayTasks(tasks);
            } catch (error) {
                console.error('Error fetching tasks:', error);
            }
        }

        function displayTasks(tasks) {
            const container = document.getElementById('tasks');
            container.innerHTML = tasks.map(task => `
                <div class="task ${task.completed ? 'completed' : ''}">
                    <div class="task-title">${task.title}</div>
                    <div>${task.description || ''}</div>
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
                }
            } catch (error) {
                console.error('Error adding task:', error);
            }
        }

        async function toggleTask(id) {
            try {
                const response = await fetch(`/api/tasks/${id}`, {
                    method: 'PUT',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ completed: !document.querySelector(`[onclick="toggleTask(${id})"]`).classList.contains('btn-danger') })
                });
                if (response.ok) fetchTasks();
            } catch (error) {
                console.error('Error toggling task:', error);
            }
        }

        async function deleteTask(id) {
            if (confirm('Are you sure?')) {
                try {
                    const response = await fetch(`/api/tasks/${id}`, { method: 'DELETE' });
                    if (response.ok) fetchTasks();
                } catch (error) {
                    console.error('Error deleting task:', error);
                }
            }
        }

        document.getElementById('taskForm').addEventListener('submit', (e) => {
            e.preventDefault();
            const title = document.getElementById('taskTitle').value;
            const description = document.getElementById('taskDescription').value;
            addTask(title, description);
        });

        fetchTasks();
    </script>
</body>
</html>
EOF

# Install Node.js dependencies
cd frontend
npm install

# Configure Nginx
cat > /etc/nginx/conf.d/task-manager.conf << 'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    location /api {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Remove default nginx configuration
rm -f /etc/nginx/conf.d/default.conf

# Create systemd service for Flask backend
cat > /etc/systemd/system/flask-backend.service << 'EOF'
[Unit]
Description=Flask Backend Service
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/task-manager/backend
ExecStart=/usr/local/bin/python3 app.py
Restart=always
RestartSec=3
Environment=PORT=5000

[Install]
WantedBy=multi-user.target
EOF

# Create systemd service for Express frontend
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

[Install]
WantedBy=multi-user.target
EOF

# Set permissions
chown -R ec2-user:ec2-user /opt/task-manager

# Reload systemd and start services
systemctl daemon-reload
systemctl enable flask-backend
systemctl enable express-frontend
systemctl start flask-backend
systemctl start express-frontend

# Restart nginx
systemctl restart nginx

echo "✅ Task Manager deployment completed successfully!"
