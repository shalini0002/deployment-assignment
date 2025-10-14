import React, { useState } from 'react';

const TaskItem = ({ task, onUpdate, onDelete, onToggle }) => {
  const [isEditing, setIsEditing] = useState(false);
  const [editTitle, setEditTitle] = useState(task.title);
  const [editDescription, setEditDescription] = useState(task.description || '');
  const [loading, setLoading] = useState(false);

  const handleSave = async () => {
    if (!editTitle.trim()) {
      alert('Please enter a task title');
      return;
    }

    try {
      setLoading(true);
      await onUpdate(task.id, {
        title: editTitle.trim(),
        description: editDescription.trim()
      });
      setIsEditing(false);
    } catch (error) {
      alert('Failed to update task. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const handleCancel = () => {
    setEditTitle(task.title);
    setEditDescription(task.description || '');
    setIsEditing(false);
  };

  const handleDelete = async () => {
    if (window.confirm('Are you sure you want to delete this task?')) {
      try {
        setLoading(true);
        await onDelete(task.id);
      } catch (error) {
        alert('Failed to delete task. Please try again.');
      } finally {
        setLoading(false);
      }
    }
  };

  const formatDate = (dateString) => {
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  return (
    <div className={`task-item ${task.completed ? 'completed' : ''}`}>
      <div className="task-checkbox">
        <input
          type="checkbox"
          checked={task.completed}
          onChange={() => onToggle(task.id)}
          disabled={loading}
        />
      </div>

      <div className="task-content">
        {isEditing ? (
          <div className="edit-form">
            <input
              type="text"
              value={editTitle}
              onChange={(e) => setEditTitle(e.target.value)}
              className="edit-input"
              placeholder="Task title"
            />
            <textarea
              value={editDescription}
              onChange={(e) => setEditDescription(e.target.value)}
              className="edit-textarea"
              placeholder="Task description"
              rows="2"
            />
            <div className="edit-actions">
              <button 
                onClick={handleSave}
                disabled={loading}
                className="save-btn"
              >
                {loading ? 'Saving...' : 'Save'}
              </button>
              <button 
                onClick={handleCancel}
                disabled={loading}
                className="cancel-btn"
              >
                Cancel
              </button>
            </div>
          </div>
        ) : (
          <>
            <h3 className="task-title">{task.title}</h3>
            {task.description && (
              <p className="task-description">{task.description}</p>
            )}
            <div className="task-meta">
              <span className="task-date">
                Created: {formatDate(task.created_at)}
              </span>
              {task.updated_at !== task.created_at && (
                <span className="task-date">
                  Updated: {formatDate(task.updated_at)}
                </span>
              )}
            </div>
          </>
        )}
      </div>

      {!isEditing && (
        <div className="task-actions">
          <button
            onClick={() => setIsEditing(true)}
            disabled={loading}
            className="edit-btn"
            title="Edit task"
          >
            ✏️
          </button>
          <button
            onClick={handleDelete}
            disabled={loading}
            className="delete-btn"
            title="Delete task"
          >
            🗑️
          </button>
        </div>
      )}
    </div>
  );
};

export default TaskItem;
