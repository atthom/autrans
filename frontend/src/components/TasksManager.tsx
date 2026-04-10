import React from 'react';
import { TextInput, NumberInput, ActionIcon, RangeSlider, ColorInput } from '@mantine/core';
import { IconTrash } from '@tabler/icons-react';
import { generateDistinctPastelColor } from '../utils/helpers';
import type { Task } from '../types';

interface TasksManagerProps {
  tasks: Task[];
  numDays: number;
  onChange: (tasks: Task[]) => void;
  isDarkMode: boolean;
}


// Generate marks: show all if <10 days, otherwise show max 10 marks
const generateMarks = (numDays: number) => {
  // If fewer than 10 days, show all
  if (numDays < 10) {
    return Array.from({ length: numDays }, (_, i) => ({
      value: i + 1,
      label: String(i + 1)
    }));
  }
  
  // For 10+ days, show exactly 10 evenly-spaced marks
  const maxMarks = 10;
  const marks = [];
  
  // Calculate step to get exactly 10 marks
  const step = (numDays - 1) / (maxMarks - 1);
  
  for (let i = 0; i < maxMarks - 1; i++) {
    const value = Math.floor(1 + i * step);
    marks.push({ value, label: String(value) });
  }
  
  // Always add the last day to ensure we reach the end
  marks.push({ value: numDays, label: String(numDays) });
  
  return marks;
};

export const TasksManager: React.FC<TasksManagerProps> = ({ tasks, numDays, onChange, isDarkMode }) => {
  const prevNumDaysRef = React.useRef(numDays);
  
  // Auto-adjust task ranges when numDays changes
  React.useEffect(() => {
    // Only run when numDays actually changes
    if (prevNumDaysRef.current !== numDays) {
      const oldNumDays = prevNumDaysRef.current;
      prevNumDaysRef.current = numDays;
      
      const adjustedTasks = tasks.map(task => {
        // If task was using the full range before, extend it to new max
        if (task.day_end === oldNumDays) {
          return {
            ...task,
            day_end: numDays,
          };
        }
        // Otherwise just clamp values if they exceed new max
        return {
          ...task,
          day_start: Math.min(task.day_start, numDays),
          day_end: Math.min(task.day_end, numDays),
        };
      });
      
      onChange(adjustedTasks);
    }
  }, [numDays, tasks, onChange]);
  
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
      day_start: 1,
      day_end: numDays,
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

          {/* Day range slider - always shown */}
          <div className="ml-4 pr-8 py-2 flex items-center gap-3">
            <span className={`text-sm whitespace-nowrap ${isDarkMode ? 'text-gray-300' : 'text-gray-900'}`}>Task range</span>
            <div className="flex-1">
              <RangeSlider
                min={1}
                max={numDays}
                step={1}
                minRange={0}
                pushOnOverlap={false}
                value={[task.day_start, task.day_end]}
                onChange={(value) => {
                  updateTask(index, {
                    day_start: value[0],
                    day_end: value[1],
                  });
                }}
                marks={generateMarks(numDays)}
                size="xs"
                color="orange"
                label={(value) => `Day ${value}`}
              />
            </div>
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