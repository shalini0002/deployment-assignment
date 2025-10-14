#!/bin/bash

# User Data Script for Backend EC2 Instance
# This script installs and configures Flask backend

set -e

# Update system
yum update -y

# Install required packages
yum install -y python3 python3-pip

# Create application directory
mkdir -p /opt/task-manager/backend
cd /opt/task-manager/backend

# Create Flask backend application
cat > app.py << 'EOF'
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
        'version': '1.0.0',
        'endpoints': {
            'GET /tasks': 'Get all tasks',
            'POST /tasks': 'Create a new task',
            'GET /tasks/<id>': 'Get a specific task',
            'PUT /tasks/<id>': 'Update a task',
            'DELETE /tasks/<id>': 'Delete a task'
        }
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

@app.route('/tasks/<int:task_id>', methods=['GET'])
def get_task(task_id):
    conn = sqlite3.connect('/opt/task-manager/tasks.db')
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM tasks WHERE id = ?', (task_id,))
    row = cursor.fetchone()
    conn.close()
    
    if not row:
        return jsonify({'error': 'Task not found'}), 404
    
    return jsonify({
        'id': row[0],
        'title': row[1],
        'description': row[2],
        'completed': bool(row[3]),
        'created_at': row[4],
        'updated_at': row[5]
    })

@app.route('/tasks/<int:task_id>', methods=['PUT'])
def update_task(task_id):
    data = request.get_json()
    if not data:
        return jsonify({'error': 'No data provided'}), 400
    
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
    
    if cursor.rowcount == 0:
        conn.close()
        return jsonify({'error': 'Task not found'}), 404
    
    conn.commit()
    conn.close()
    
    return jsonify({'message': 'Task updated successfully'})

@app.route('/tasks/<int:task_id>', methods=['DELETE'])
def delete_task(task_id):
    conn = sqlite3.connect('/opt/task-manager/tasks.db')
    cursor = conn.cursor()
    cursor.execute('DELETE FROM tasks WHERE id = ?', (task_id,))
    
    if cursor.rowcount == 0:
        conn.close()
        return jsonify({'error': 'Task not found'}), 404
    
    conn.commit()
    conn.close()
    
    return jsonify({'message': 'Task deleted successfully'})

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    debug = os.environ.get('FLASK_ENV') == 'development'
    app.run(host='0.0.0.0', port=port, debug=debug)
EOF

# Create requirements.txt
cat > requirements.txt << 'EOF'
Flask==2.3.3
Flask-CORS==4.0.0
gunicorn==21.2.0
EOF

# Install Python dependencies
pip3 install -r requirements.txt

# Create systemd service
cat > /etc/systemd/system/flask-backend.service << 'EOF'
[Unit]
Description=Flask Backend Service
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/task-manager/backend
ExecStart=/usr/local/bin/gunicorn --bind 0.0.0.0:5000 --workers 4 app:app
Restart=always
RestartSec=3
Environment=PORT=5000

[Install]
WantedBy=multi-user.target
EOF

# Set permissions
chown -R ec2-user:ec2-user /opt/task-manager

# Enable and start service
systemctl daemon-reload
systemctl enable flask-backend
systemctl start flask-backend

echo "✅ Flask Backend deployment completed successfully!"
