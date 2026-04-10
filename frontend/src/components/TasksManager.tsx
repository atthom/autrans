import React from 'react';
import { TextInput, NumberInput, ActionIcon, ColorInput } from '@mantine/core';
import { IconTrash } from '@tabler/icons-react';
import { generateDistinctPastelColor } from '../utils/helpers';
import { TaskDayPicker } from './TaskDayPicker';
import type { Task } from '../types';

interface TasksManagerProps {
  tasks: Task[];
  numDays: number;
  startDate: string;
  onChange: (tasks: Task[]) => void;
  isDarkMode: boolean;
}

export const TasksManager: React.FC<TasksManagerProps> = ({ tasks, numDays, startDate, onChange, isDarkMode }) => {
  const prevNumDaysRef = React.useRef(numDays);
  
  // Auto-adjust task selected days when numDays changes
  React.useEffect(() => {
    // Only run when numDays actually changes
    if (prevNumDaysRef.current !== numDays) {
      const oldNumDays = prevNumDaysRef.current;
      prevNumDaysRef.current = numDays;
      
      const adjustedTasks = tasks.map(task => {
        // If task had all days selected before, select all new days
        if (task.selected_days.length === oldNumDays) {
          return {
            ...task,
            selected_days: Array.from({ length: numDays }, (_, i) => i + 1),
          };
        }
        // Otherwise filter out days that exceed new max
        const filteredDays = task.selected_days.filter(day => day <= numDays);
        // Ensure at least one day is selected
        return {
          ...task,
          selected_days: filteredDays.length > 0 ? filteredDays : [1],
        };
      });
      
      onChange(adjustedTasks);
    }
  }, [numDays]); // Only depend on numDays to avoid infinite loop
  
  const addTask = () => {
    if (tasks.length >= 20) {
      alert('Maximum 20 tasks allowed');
      return;
    }
    // Get existing colors to ensure new color is distinct
    const existingColors = tasks.map(t => t.color).filter((c): c is string => Boolean(c));
    const newTask: Task = {
      name: `Task ${tasks.length + 1}`,
      num_workers: 2,
      difficulty: 1,
      selected_days: Array.from({ length: numDays }, (_, i) => i + 1), // Select all days by default
      color: generateDistinctPastelColor(existingColors),
    };
    onChange([...tasks, newTask]);
  };

  const updateTask = (index: number, updates: Partial<Task>) => {
    const newTasks = [...tasks];
    newTasks[index] = { ...newTasks[index], ...updates };
    onChange(newTasks);
  };

  const deleteTask = (index: number) => {
    if (tasks.length === 1) {
      alert('Cannot delete the last task');
      return;
    }
    onChange(tasks.filter((_, i) => i !== index));
  };

  return (
    <div className="space-y-4">
      {/* Header row */}
      <div className={`grid grid-cols-12 gap-2 text-sm font-semibold px-2 ${isDarkMode ? 'text-gray-300' : 'text-gray-900'}`}>
        <div className="col-span-4">Task name</div>
        <div className="col-span-2">People</div>
        <div className="col-span-2">Difficulty</div>
        <div className="col-span-3">Color</div>
        <div className="col-span-1"></div>
      </div>

      {/* Task list */}
      {tasks.map((task, index) => (
        <div key={index} className="pb-4 mb-4 border-b border-gray-200 last:border-b-0 last:mb-0 last:pb-0">
          <div className="space-y-2">
          <div className="grid grid-cols-12 gap-2 items-end">
            <div className="col-span-4">
              <TextInput
                value={task.name}
                onChange={(e) => updateTask(index, { name: e.currentTarget.value })}
                placeholder="Task name"
              />
            </div>
            
            <div className="col-span-2">
              <NumberInput
                min={1}
                value={task.num_workers}
                onChange={(val) => updateTask(index, { num_workers: typeof val === 'number' ? val : 1 })}
              />
            </div>
            
            <div className="col-span-2">
              <NumberInput
                min={1}
                value={task.difficulty}
                onChange={(val) => updateTask(index, { difficulty: typeof val === 'number' ? val : 1 })}
              />
            </div>
            
            <div className="col-span-3">
              <ColorInput
                value={task.color || '#cccccc'}
                onChange={(color) => updateTask(index, { color })}
                format="hex"
                withEyeDropper={false}
              />
            </div>
            
            <div className="col-span-1 flex items-end justify-center">
              <ActionIcon
                color="red"
                variant="subtle"
                onClick={() => deleteTask(index)}
                title="Delete task"
                size="lg"
              >
                <IconTrash size={18} />
              </ActionIcon>
            </div>
          </div>

          {/* Task day picker - collapsed by default */}
          <div className="ml-4 pr-8">
            <TaskDayPicker
              numDays={numDays}
              selectedDays={task.selected_days}
              startDate={startDate}
              onChange={(days) => updateTask(index, { selected_days: days })}
              isDarkMode={isDarkMode}
            />
          </div>
          </div>
        </div>
      ))}

      {/* Add button */}
      <div className="flex justify-center pt-2">
        <button
          onClick={addTask}
          className="px-4 py-2 bg-primary-500 hover:bg-primary-600 text-white rounded transition-colors text-sm font-medium"
        >
          + Add Task
        </button>
      </div>
    </div>
  );
};