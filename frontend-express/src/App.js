import React, { useState, useEffect } from 'react';
import TaskList from './components/TaskList';
import TaskForm from './components/TaskForm';
import Header from './components/Header';
import './styles.css';

function App() {
  const [tasks, setTasks] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // Fetch tasks from backend
  const fetchTasks = async () => {
    try {
      setLoading(true);
      const response = await fetch('/api/tasks');
      if (!response.ok) {
        throw new Error('Failed to fetch tasks');
      }
      const data = await response.json();
      setTasks(data);
      setError(null);
    } catch (err) {
      setError(err.message);
      console.error('Error fetching tasks:', err);
    } finally {
      setLoading(false);
    }
  };

  // Create new task
  const createTask = async (taskData) => {
    try {
      const response = await fetch('/api/tasks', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(taskData),
      });

      if (!response.ok) {
        throw new Error('Failed to create task');
      }

      const newTask = await response.json();
      setTasks([newTask, ...tasks]);
      return newTask;
    } catch (err) {
      setError(err.message);
      console.error('Error creating task:', err);
      throw err;
    }
  };

  // Update task
  const updateTask = async (id, taskData) => {
    try {
      const response = await fetch(`/api/tasks/${id}`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(taskData),
      });

      if (!response.ok) {
        throw new Error('Failed to update task');
      }

      setTasks(tasks.map(task => 
        task.id === id ? { ...task, ...taskData } : task
      ));
    } catch (err) {
      setError(err.message);
      console.error('Error updating task:', err);
      throw err;
    }
  };

  // Delete task
  const deleteTask = async (id) => {
    try {
      const response = await fetch(`/api/tasks/${id}`, {
        method: 'DELETE',
      });

      if (!response.ok) {
        throw new Error('Failed to delete task');
      }

      setTasks(tasks.filter(task => task.id !== id));
    } catch (err) {
      setError(err.message);
      console.error('Error deleting task:', err);
      throw err;
    }
  };

  // Toggle task completion
  const toggleTask = async (id) => {
    const task = tasks.find(t => t.id === id);
    if (task) {
      await updateTask(id, { ...task, completed: !task.completed });
    }
  };

  useEffect(() => {
    fetchTasks();
  }, []);

  return (
    <div className="app">
      <Header />
      <div className="container">
        {error && (
          <div className="error-banner">
            <p>Error: {error}</p>
            <button onClick={() => setError(null)}>Dismiss</button>
          </div>
        )}
        
        <TaskForm onCreateTask={createTask} />
        
        <div className="tasks-section">
          <h2>Your Tasks</h2>
          {loading ? (
            <div className="loading">Loading tasks...</div>
          ) : (
            <TaskList 
              tasks={tasks} 
              onUpdateTask={updateTask}
              onDeleteTask={deleteTask}
              onToggleTask={toggleTask}
            />
          )}
        </div>
      </div>
    </div>
  );
}

export default App;
