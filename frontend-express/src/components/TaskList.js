import React, { useState } from 'react';
import TaskItem from './TaskItem';

const TaskList = ({ tasks, onUpdateTask, onDeleteTask, onToggleTask }) => {
  const [filter, setFilter] = useState('all'); // all, completed, pending

  const filteredTasks = tasks.filter(task => {
    switch (filter) {
      case 'completed':
        return task.completed;
      case 'pending':
        return !task.completed;
      default:
        return true;
    }
  });

  const completedCount = tasks.filter(task => task.completed).length;
  const pendingCount = tasks.length - completedCount;

  return (
    <div className="task-list-container">
      <div className="task-stats">
        <div className="stat">
          <span className="stat-number">{tasks.length}</span>
          <span className="stat-label">Total</span>
        </div>
        <div className="stat">
          <span className="stat-number">{pendingCount}</span>
          <span className="stat-label">Pending</span>
        </div>
        <div className="stat">
          <span className="stat-number">{completedCount}</span>
          <span className="stat-label">Completed</span>
        </div>
      </div>

      <div className="filter-buttons">
        <button 
          className={filter === 'all' ? 'active' : ''}
          onClick={() => setFilter('all')}
        >
          All Tasks
        </button>
        <button 
          className={filter === 'pending' ? 'active' : ''}
          onClick={() => setFilter('pending')}
        >
          Pending
        </button>
        <button 
          className={filter === 'completed' ? 'active' : ''}
          onClick={() => setFilter('completed')}
        >
          Completed
        </button>
      </div>

      {filteredTasks.length === 0 ? (
        <div className="empty-state">
          <p>
            {filter === 'all' 
              ? "No tasks yet. Add one above to get started!" 
              : `No ${filter} tasks found.`
            }
          </p>
        </div>
      ) : (
        <div className="task-list">
          {filteredTasks.map(task => (
            <TaskItem
              key={task.id}
              task={task}
              onUpdate={onUpdateTask}
              onDelete={onDeleteTask}
              onToggle={onToggleTask}
            />
          ))}
        </div>
      )}
    </div>
  );
};

export default TaskList;
