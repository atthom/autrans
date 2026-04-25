import React from 'react';
import { NumberInput, ActionIcon, Fieldset, Accordion } from '@mantine/core';
import { IconTrash, IconMoodSmile, IconMoodEmpty, IconMoodSad } from '@tabler/icons-react';
import { DaysOffPicker } from './DaysOffPicker';
import type { Worker, Task } from '../types';

interface WorkersManagerProps {
  workers: Worker[];
  tasks: Task[];
  startDate: string;
  numDays: number;
  displayDaysAs: 'numbers' | 'dayOfWeek';
  onChange: (workers: Worker[]) => void;
  isDarkMode: boolean;
}

// Rating values
const RATING_LIKE = 3;
const RATING_NEUTRAL = 2;
const RATING_DISLIKE = 1;

export const WorkersManager: React.FC<WorkersManagerProps> = ({ 
  workers, 
  tasks,
  startDate,
  numDays,
  displayDaysAs,
  onChange,
  isDarkMode
}) => {
  console.log('[WorkersManager] RENDER', { 
    workersCount: workers.length, 
    tasksCount: tasks.length,
    workersPrefsLengths: workers.map(w => w.task_preferences?.length || 0)
  });

  const addWorker = () => {
    if (workers.length >= 20) {
      alert('Maximum 20 workers allowed');
      return;
    }
    const newWorker: Worker = {
      name: `Person ${workers.length + 1}`,
      days_off: [],
      task_preferences: tasks.map(() => RATING_NEUTRAL), // Initialize all tasks as Neutral
      workload_offset: 0,
    };
    onChange([...workers, newWorker]);
  };

  const updateWorker = (index: number, updates: Partial<Worker>) => {
    const newWorkers = [...workers];
    newWorkers[index] = { ...newWorkers[index], ...updates };
    onChange(newWorkers);
  };

  const deleteWorker = (index: number) => {
    if (workers.length === 1) {
      alert('Cannot delete the last worker');
      return;
    }
    onChange(workers.filter((_, i) => i !== index));
  };

  const setTaskRating = (workerIndex: number, taskIndex: number, rating: number) => {
    const worker = workers[workerIndex];
    const newPrefs = [...worker.task_preferences];
    newPrefs[taskIndex] = rating;
    updateWorker(workerIndex, { task_preferences: newPrefs });
  };

  return (
    <div className="space-y-4">
      {/* Workers list - Each worker in a Fieldset */}
      {workers.map((worker, workerIndex) => (
        <Fieldset key={workerIndex} legend={
          <div className="flex items-center justify-between w-full gap-3">
            <input
              type="text"
              id={`worker-name-${workerIndex}`}
              name={`worker-name-${workerIndex}`}
              value={worker.name}
              onChange={(e) => updateWorker(workerIndex, { name: e.target.value })}
              className="bg-transparent border border-gray-300 font-semibold text-base focus:outline-none focus:ring-2 focus:ring-primary-500 rounded px-2 py-1 flex-1"
              placeholder="Worker name"
              autoComplete="name"
            />
            <div className="flex items-center gap-2">
              <label 
                htmlFor={`workload-offset-${workerIndex}`}
                className={`text-xs font-medium whitespace-nowrap ${isDarkMode ? 'text-gray-300' : 'text-gray-600'}`}
              >
                Offset:
              </label>
              <NumberInput
                id={`workload-offset-${workerIndex}`}
                value={worker.workload_offset}
                min={-10}
                max={10}
                onChange={(val) => updateWorker(workerIndex, { workload_offset: typeof val === 'number' ? val : 0 })}
                className="w-16"
                size="xs"
              />
            </div>
            <ActionIcon
              color="red"
              variant="subtle"
              onClick={() => deleteWorker(workerIndex)}
              title="Delete worker"
              size="lg"
            >
              <IconTrash size={20} />
            </ActionIcon>
          </div>
        }>
          <div className="space-y-4">
            {/* Accordion for Days Off and Task Preferences */}
            <Accordion 
              multiple
              styles={{
                item: {
                  border: 'none',
                },
              }}
            >
              {/* Days Off Accordion */}
              <Accordion.Item value="daysoff">
                <Accordion.Control onClick={() => {
                  console.log('[WorkersManager] Days Off clicked for worker:', worker.name);
                }}>
                  <span className="text-sm font-medium">Days Off ({worker.days_off.length})</span>
                </Accordion.Control>
                <Accordion.Panel>
                  <DaysOffPicker
                    numDays={numDays}
                    selectedDays={worker.days_off}
                    startDate={startDate}
                    displayMode={displayDaysAs}
                    onChange={(days) => updateWorker(workerIndex, { days_off: days })}
                  />
                </Accordion.Panel>
              </Accordion.Item>

              {/* Task Preferences Accordion */}
              {tasks.length > 0 && worker.task_preferences.length > 0 && (
                <Accordion.Item value="preferences">
                  <Accordion.Control onClick={() => {
                    console.log('[WorkersManager] Task Preferences clicked for worker:', worker.name);
                    console.log('[WorkersManager] Worker preferences:', worker.task_preferences);
                    console.log('[WorkersManager] Tasks:', tasks.map(t => t.name));
                  }}>
                    <span className="text-sm font-medium">Task Preferences</span>
                  </Accordion.Control>
                  <Accordion.Panel>
                    <p className="text-xs text-gray-600 mb-3">
                      Rate each task: Like (preferred), Neutral (no preference), or Dislike (avoid if possible)
                    </p>
                    <div className="space-y-2">
                      {tasks.map((task, taskIndex) => {
                        const rating = worker.task_preferences[taskIndex] || RATING_NEUTRAL;
                        
                        return (
                          <div key={taskIndex} className={`flex items-center justify-between p-2 rounded border ${
                            isDarkMode ? 'bg-gray-700 border-gray-600' : 'bg-white border-gray-200'
                          }`}>
                            <span className={`text-sm font-medium flex-1 ${isDarkMode ? 'text-gray-100' : 'text-gray-900'}`}>{task.name}</span>
                            <div className="flex gap-1">
                              <button
                                onClick={() => {
                                  console.log('[WorkersManager] LIKE clicked:', worker.name, task.name);
                                  setTaskRating(workerIndex, taskIndex, RATING_LIKE);
                                }}
                                className={`p-2 rounded transition-colors ${
                                  rating === RATING_LIKE
                                    ? 'bg-primary-500 text-white'
                                    : isDarkMode
                                      ? 'bg-gray-600 text-gray-300 hover:bg-primary-900'
                                      : 'bg-white text-gray-600 hover:bg-primary-50'
                                }`}
                                title="Like"
                              >
                                <IconMoodSmile size={16} />
                              </button>
                              <button
                                onClick={() => {
                                  console.log('[WorkersManager] NEUTRAL clicked:', worker.name, task.name);
                                  setTaskRating(workerIndex, taskIndex, RATING_NEUTRAL);
                                }}
                                className={`p-2 rounded transition-colors ${
                                  rating === RATING_NEUTRAL
                                    ? isDarkMode ? 'bg-gray-500 text-white' : 'bg-gray-400 text-white'
                                    : isDarkMode
                                      ? 'bg-gray-600 text-gray-300 hover:bg-gray-500'
                                      : 'bg-white text-gray-600 hover:bg-gray-100'
                                }`}
                                title="Neutral"
                              >
                                <IconMoodEmpty size={16} />
                              </button>
                              <button
                                onClick={() => {
                                  console.log('[WorkersManager] DISLIKE clicked:', worker.name, task.name);
                                  setTaskRating(workerIndex, taskIndex, RATING_DISLIKE);
                                }}
                                className={`p-2 rounded transition-colors ${
                                  rating === RATING_DISLIKE
                                    ? isDarkMode ? 'bg-rose-600 text-white' : 'bg-rose-400 text-white'
                                    : isDarkMode
                                      ? 'bg-gray-600 text-gray-300 hover:bg-rose-900'
                                      : 'bg-white text-gray-600 hover:bg-rose-50'
                                }`}
                                title="Dislike"
                              >
                                <IconMoodSad size={16} />
                              </button>
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  </Accordion.Panel>
                </Accordion.Item>
              )}
            </Accordion>
          </div>
        </Fieldset>
      ))}

      {/* Add button */}
      <div className="flex justify-center pt-2">
        <button
          onClick={addWorker}
          className="px-4 py-2 bg-primary-500 hover:bg-primary-600 text-white rounded transition-colors text-sm font-medium"
        >
          + Add Worker
        </button>
      </div>

    </div>
  );
};