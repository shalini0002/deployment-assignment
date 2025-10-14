import React, { useState } from 'react';

const TaskForm = ({ onCreateTask }) => {
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    if (!title.trim()) {
      alert('Please enter a task title');
      return;
    }

    try {
      setLoading(true);
      await onCreateTask({
        title: title.trim(),
        description: description.trim(),
        completed: false
      });
      
      // Reset form
      setTitle('');
      setDescription('');
    } catch (error) {
      alert('Failed to create task. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="task-form-container">
      <form onSubmit={handleSubmit} className="task-form">
        <h2>Add New Task</h2>
        <div className="form-group">
          <label htmlFor="title">Title *</label>
          <input
            type="text"
            id="title"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="Enter task title..."
            required
          />
        </div>
        
        <div className="form-group">
          <label htmlFor="description">Description</label>
          <textarea
            id="description"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder="Enter task description..."
            rows="3"
          />
        </div>
        
        <button 
          type="submit" 
          className="submit-btn"
          disabled={loading}
        >
          {loading ? 'Adding...' : 'Add Task'}
        </button>
      </form>
    </div>
  );
};

export default TaskForm;
