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
app.use(express.static(path.join(__dirname, 'dist')));

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
  res.sendFile(path.join(__dirname, 'dist', 'index.html'));
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Frontend server running on port ${PORT}`);
  console.log(`Backend URL: ${BACKEND_URL}`);
});
