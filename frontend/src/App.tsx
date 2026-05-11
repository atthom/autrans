import { useState, useEffect, useMemo } from 'react';
import { Accordion } from '@mantine/core';
import { IconSun, IconMoon } from '@tabler/icons-react';
import './App.css';
import { Settings } from './components/Settings';
import { TasksManager } from './components/TasksManager';
import { WorkersManager } from './components/WorkersManager';
import { ConstraintsManager } from './components/ConstraintsManager';
import { StateManager } from './components/StateManager';
import { AllScheduleTabs } from './components/AllScheduleTabs';
import { ErrorDialog } from './components/ErrorDialog';
import { scheduleApi, isFailureResponse } from './api/client';
import { generateDistinctPastelColor, formatDate } from './utils/helpers';
import type { AppState, ScheduleResponse, ScheduleRequest, FailureResponse } from './types';

function App() {
  console.log('[App] RENDER');
  
  // Dark mode state
  const [isDarkModeActive, setIsDarkModeActive] = useState(() => {
    const saved = localStorage.getItem('darkMode');
    return saved ? JSON.parse(saved) : false;
  });

  // Apply dark mode class to document
  useEffect(() => {
    console.log('[App] useEffect [isDarkModeActive]', isDarkModeActive);
    if (isDarkModeActive) {
      document.documentElement.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
    }
    localStorage.setItem('darkMode', JSON.stringify(isDarkModeActive));
  }, [isDarkModeActive]);

  const switchModes = (mode: 'light' | 'dark') => {
    if (mode === 'light') {
      setIsDarkModeActive(false);
    } else if (mode === 'dark') {
      setIsDarkModeActive(true);
    }
  };

  const toggleDarkMode = () => {
    switchModes(isDarkModeActive ? 'light' : 'dark');
  };

  // Initialize default state
  const [state, setState] = useState<AppState>(() => {
    const RATING_NEUTRAL = 2;
    const colors: string[] = [];
    const tasks = [
      { name: 'Cooking', num_workers: 2, difficulty: 1, selected_days: [1, 2, 3, 4, 5, 6, 7], color: (() => { const c = generateDistinctPastelColor(colors); colors.push(c); return c; })() },
      { name: 'Cleaning', num_workers: 2, difficulty: 1, selected_days: [1, 2, 3, 4, 5, 6, 7], color: (() => { const c = generateDistinctPastelColor(colors); colors.push(c); return c; })() },
      { name: 'Shopping', num_workers: 1, difficulty: 1, selected_days: [1, 2, 3, 4, 5, 6, 7], color: (() => { const c = generateDistinctPastelColor(colors); colors.push(c); return c; })() },
    ];
    
    // Initialize workers with task_preferences matching task count
    const workers = [
      { name: 'Alex', days_off: [], task_preferences: tasks.map(() => RATING_NEUTRAL), workload_offset: 0 },
      { name: 'Benjamin', days_off: [], task_preferences: tasks.map(() => RATING_NEUTRAL), workload_offset: 0 },
      { name: 'Caroline', days_off: [], task_preferences: tasks.map(() => RATING_NEUTRAL), workload_offset: 0 },
      { name: 'Diane', days_off: [], task_preferences: tasks.map(() => RATING_NEUTRAL), workload_offset: 0 },
      { name: 'Esteban', days_off: [], task_preferences: tasks.map(() => RATING_NEUTRAL), workload_offset: 0 },
      { name: 'Frank', days_off: [], task_preferences: tasks.map(() => RATING_NEUTRAL), workload_offset: 0 },
    ];
    
    return {
      tripName: 'My Trip',
      startDate: formatDate(new Date()),
      numDays: 7,
      tasks,
      workers,
      constraints: [
      { name: 'Task Coverage', enabled: true, type: 'hard', description: 'Each task must have the required number of workers' },
      { name: 'No Consecutive Tasks', enabled: true, type: 'hard', description: 'Workers do at most one task per day' },
      { name: 'Days Off', enabled: true, type: 'hard', description: 'Workers cannot work on their days off' },
      { name: 'Overall Equity', enabled: true, type: 'soft', description: 'Fair distribution of total workload' },
      { name: 'Daily Equity', enabled: true, type: 'soft', description: 'Similar amount of work per day' },
      { name: 'Task Diversity', enabled: true, type: 'soft', description: 'Everyone participates in each task' },
      { name: 'Worker Preference', enabled: false, type: 'soft', description: 'Respect worker task preferences' },
      { name: 'One Task Per Day', enabled: false, type: 'hard', description: 'Workers can do at most 1 task per day' },
      ],
      balanceDaysOff: true,
      displayDaysAs: 'numbers',
    };
  });

  const [scheduleData, setScheduleData] = useState<ScheduleResponse | null>(null);
  const [scheduleRequest, setScheduleRequest] = useState<ScheduleRequest | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<FailureResponse | null>(null);
  const [showErrorDialog, setShowErrorDialog] = useState(false);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);

  // Update state handlers
  const updateState = (updates: Partial<AppState>) => {
    console.log('[App] updateState called with:', Object.keys(updates));
    if (updates.workers) {
      console.log('[App] updateState - workers update:', updates.workers.map(w => ({
        name: w.name,
        prefsLength: w.task_preferences?.length
      })));
    }
    console.log('[App] updateState - calling setState');
    setState(prev => {
      console.log('[App] setState callback executing');
      const newState = { ...prev, ...updates };
      console.log('[App] setState callback complete');
      return newState;
    });
    console.log('[App] updateState complete');
    
    // Only clear schedule if non-cosmetic settings change
    // displayDaysAs is purely cosmetic and doesn't affect the schedule calculation
    const cosmeticOnlyChange = Object.keys(updates).length === 1 && 'displayDaysAs' in updates;
    
    if (!cosmeticOnlyChange) {
      // Clear schedule data when settings change to prevent state mismatches
      setScheduleData(null);
      setScheduleRequest(null);
      setError(null);
      setSuccessMessage(null);
    }
  };

  // REMOVED: Problematic useEffect that was causing infinite loops
  // Task preferences are now initialized in WorkersManager when workers are added

  const handleLoadState = useMemo(() => (loadedState: AppState) => {
    const RATING_NEUTRAL = 2;
    
    // Ensure all workers have correct task_preferences length
    const workersWithPreferences = loadedState.workers.map(worker => {
      if (!worker.task_preferences || worker.task_preferences.length !== loadedState.tasks.length) {
        return {
          ...worker,
          task_preferences: loadedState.tasks.map(() => RATING_NEUTRAL)
        };
      }
      // Filter out any null values from loaded state
      return {
        ...worker,
        task_preferences: worker.task_preferences.map(p => p === null ? RATING_NEUTRAL : p)
      };
    });
    
    setState({
      ...loadedState,
      workers: workersWithPreferences,
      displayDaysAs: loadedState.displayDaysAs || 'numbers', // Default to 'numbers' if missing
    });
    setScheduleData(null);
    setScheduleRequest(null);
    setError(null);
  }, []);

  // Map constraint names to backend format
  const constraintNameMap: Record<string, string> = {
    'Task Coverage': 'TaskCoverage',
    'No Consecutive Tasks': 'NoConsecutiveTasks',
    'Days Off': 'DaysOff',
    'Overall Equity': 'OverallEquity',
    'Daily Equity': 'DailyEquity',
    'Task Diversity': 'TaskDiversity',
    'Worker Preference': 'WorkerPreference',
    'One Task Per Day': 'OneTaskPerDay',
  };

  const handleSubmit = async () => {
    console.log('[App] ========== handleSubmit CALLED ==========');
    console.log('[App] isLoading before:', isLoading);
    
    setIsLoading(true);
    setError(null);
    setSuccessMessage(null);
    setScheduleData(null);
    
    // Scroll to top of page
    window.scrollTo({ top: 0, behavior: 'smooth' });

    try {
      // Build request payload
      const enabledConstraints = state.constraints.filter(c => c.enabled);
      const hardConstraints = enabledConstraints
        .filter(c => c.type === 'hard')
        .map(c => constraintNameMap[c.name]);
      const softConstraints = enabledConstraints
        .filter(c => c.type === 'soft')
        .map(c => constraintNameMap[c.name]);

      // Convert tasks to backend format: [name, num_workers, difficulty, ...selected_days]
      const tasks = state.tasks.map(task => [
        task.name,
        task.num_workers,
        task.difficulty,
        ...task.selected_days,
      ] as [string, number, number, ...number[]]);

      // Convert workers to backend format: [name, days_off, task_preferences, workload_offset]
      // Filter out any null values that might have been introduced from loaded state
      const workers: Array<[string, number[], number[], number]> = state.workers.map(worker => [
        worker.name,
        worker.days_off.filter((d): d is number => d !== null && d !== undefined),
        worker.task_preferences.filter((p): p is number => p !== null && p !== undefined),
        worker.workload_offset,
      ]);

      const request: ScheduleRequest = {
        workers,
        tasks,
        nb_days: state.numDays,
        task_per_day: tasks.map(t => t[0]),
        balance_daysoff: state.balanceDaysOff,
        hard_constraints: hardConstraints,
        soft_constraints: softConstraints,
      };

      console.log('[App] Sending request:', JSON.stringify(request, null, 2));
      setScheduleRequest(request);

      const response = await scheduleApi.generateSchedule(request);
      console.log('[App] Received response:', response);
      setScheduleData(response);
      setSuccessMessage('✅ Schedule generated successfully!');
      
      // Auto-hide success message after 5 seconds
      setTimeout(() => setSuccessMessage(null), 5000);
    } catch (err: any) {
      if (isFailureResponse(err)) {
        setError(err.response.data);
        setShowErrorDialog(true);
      } else {
        setError({
          msg: err.message || 'An unexpected error occurred',
          details: undefined,
        });
        setShowErrorDialog(true);
      }
    } finally {
      setIsLoading(false);
    }
  };

  const taskColors = useMemo(() => {
    return state.tasks.map(t => t.color || '#cccccc');
  }, [state.tasks]);

  return (
    <div className={`min-h-screen transition-colors duration-200 ${isDarkModeActive ? 'bg-gray-900' : 'bg-gray-100'}`}>
      {/* Header */}
      <div className={`text-white py-6 shadow-lg ${isDarkModeActive ? 'bg-primary-700' : 'bg-primary-600'}`}>
        <div className="container mx-auto px-4 relative">
          <h1 className="text-4xl font-bold text-center">Autrans</h1>
          <h2 className={`text-xl text-center mt-2 ${isDarkModeActive ? 'text-primary-200' : 'text-primary-100'}`}>Automated Scheduling Tool</h2>
          
          {/* Dark Mode Toggle */}
          <button
            onClick={toggleDarkMode}
            className={`absolute right-4 top-1/2 -translate-y-1/2 p-2 rounded-lg transition-colors ${
              isDarkModeActive 
                ? 'bg-primary-600 hover:bg-primary-500' 
                : 'bg-primary-700 hover:bg-primary-800'
            }`}
            title={isDarkModeActive ? 'Switch to light mode' : 'Switch to dark mode'}
          >
            {isDarkModeActive ? <IconSun size={24} /> : <IconMoon size={24} />}
          </button>
        </div>
      </div>

      {/* Main Content */}
      <div className="container mx-auto pl-2 pr-4 py-8">
        <div className="flex flex-col lg:flex-row gap-6">
          {/* Left Panel - Settings (Fixed width, floats left) */}
          <div className="lg:w-[480px] flex-shrink-0">
            <div className={`rounded-lg shadow-md border overflow-hidden transition-colors duration-200 ${
              isDarkModeActive ? 'bg-gray-800 border-gray-700' : 'bg-white border-gray-200'
            }`}>
              {/* Card Header */}
              <div className={`text-white px-6 py-4 ${isDarkModeActive ? 'bg-primary-600' : 'bg-primary-500'}`}>
                <h2 className="text-xl font-bold">⚙️ Settings</h2>
              </div>

              {/* Collapsible Sections */}
              <Accordion
                multiple
                defaultValue={['general', 'tasks', 'workers']}
                onChange={(value) => {
                  console.log('[App] Main Accordion onChange:', value);
                }}
              >
                {/* General Settings */}
                <Accordion.Item value="general">
                  <Accordion.Control onClick={() => console.log('[App] General Settings accordion clicked')}>
                    <span className={`font-semibold ${isDarkModeActive ? 'text-gray-100' : 'text-gray-900'}`}>General Settings</span>
                  </Accordion.Control>
                  <Accordion.Panel>
                    <Settings state={state} onChange={updateState} isDarkMode={isDarkModeActive} />
                  </Accordion.Panel>
                </Accordion.Item>

                {/* Tasks */}
                <Accordion.Item value="tasks">
                  <Accordion.Control onClick={() => console.log('[App] Tasks accordion clicked')}>
                    <span className={`font-semibold ${isDarkModeActive ? 'text-gray-100' : 'text-gray-900'}`}>📋 Tasks</span>
                  </Accordion.Control>
                  <Accordion.Panel>
                    <TasksManager
                      tasks={state.tasks}
                      numDays={state.numDays}
                      startDate={state.startDate}
                      onChange={(tasks) => updateState({ tasks })}
                      isDarkMode={isDarkModeActive}
                    />
                  </Accordion.Panel>
                </Accordion.Item>

                {/* Workers */}
                <Accordion.Item value="workers">
                  <Accordion.Control onClick={() => console.log('[App] Workers accordion clicked')}>
                    <span className={`font-semibold ${isDarkModeActive ? 'text-gray-100' : 'text-gray-900'}`}>👥 Workers</span>
                  </Accordion.Control>
                  <Accordion.Panel>
                    <WorkersManager
                      workers={state.workers}
                      tasks={state.tasks}
                      startDate={state.startDate}
                      numDays={state.numDays}
                      displayDaysAs={state.displayDaysAs}
                      onChange={(workers) => updateState({ workers })}
                      isDarkMode={isDarkModeActive}
                    />
                  </Accordion.Panel>
                </Accordion.Item>

                {/* Constraint Settings */}
                <Accordion.Item value="constraints">
                  <Accordion.Control onClick={() => console.log('[App] Constraints accordion clicked')}>
                    <span className={`font-semibold ${isDarkModeActive ? 'text-gray-100' : 'text-gray-900'}`}>🔧 Constraint Settings</span>
                  </Accordion.Control>
                  <Accordion.Panel>
                    <ConstraintsManager
                      constraints={state.constraints}
                      onChange={(constraints) => updateState({ constraints })}
                      isDarkMode={isDarkModeActive}
                    />
                  </Accordion.Panel>
                </Accordion.Item>

                {/* State Management */}
                <Accordion.Item value="state">
                  <Accordion.Control onClick={() => console.log('[App] State Management accordion clicked')}>
                    <span className={`font-semibold ${isDarkModeActive ? 'text-gray-100' : 'text-gray-900'}`}>💾 State Management</span>
                  </Accordion.Control>
                  <Accordion.Panel>
                    <StateManager currentState={state} onLoadState={handleLoadState} isDarkMode={isDarkModeActive} />
                  </Accordion.Panel>
                </Accordion.Item>
              </Accordion>

              {/* Submit Button */}
              <div className={`p-6 border-t ${
                isDarkModeActive ? 'bg-gray-900 border-gray-700' : 'bg-gray-50 border-gray-200'
              }`}>
                <button
                  onClick={() => {
                    console.log('[App] ========== BUTTON CLICKED ==========');
                    console.log('[App] isLoading:', isLoading);
                    console.log('[App] Calling handleSubmit...');
                    handleSubmit();
                  }}
                  disabled={isLoading}
                  className={`w-full text-white font-bold py-3 px-8 rounded-lg text-lg shadow-lg transition-colors duration-200 ${
                    isLoading
                      ? isDarkModeActive ? 'bg-gray-600' : 'bg-gray-400'
                      : isDarkModeActive 
                        ? 'bg-primary-600 hover:bg-primary-700' 
                        : 'bg-primary-500 hover:bg-primary-600'
                  }`}
                >
                  {isLoading ? 'Generating...' : 'Submit'}
                </button>
              </div>
            </div>
          </div>

          {/* Right Panel - Results (Takes remaining space) */}
          <div className="flex-1 min-w-0 space-y-6">
            {/* Success Message */}
            {successMessage && (
              <div className={`rounded-lg p-4 border ${
                isDarkModeActive 
                  ? 'bg-green-900/30 border-green-700 text-green-200' 
                  : 'bg-green-50 border-green-200 text-green-800'
              }`}>
                {successMessage}
              </div>
            )}

            {/* All Schedule Tabs (includes Table, Daily, Audit, Export, Help) */}
            <AllScheduleTabs
              scheduleData={scheduleData}
              scheduleRequest={scheduleRequest}
              startDate={state.startDate}
              numDays={state.numDays}
              tripName={state.tripName}
              colors={taskColors}
              displayDaysAs={state.displayDaysAs}
              isLoading={isLoading}
              isDarkMode={isDarkModeActive}
            />
          </div>
        </div>
      </div>

      {/* Error Dialog */}
      {error && (
        <ErrorDialog
          isOpen={showErrorDialog}
          onClose={() => setShowErrorDialog(false)}
          error={error}
          tasks={scheduleRequest?.tasks}
          workers={scheduleRequest?.workers}
          numDays={state.numDays}
        />
      )}
    </div>
  );
}

export default App;