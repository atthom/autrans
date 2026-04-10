import React, { useState } from 'react';
import { DatePickerInput } from '@mantine/dates';
import type { AppState } from '../types';

interface SettingsProps {
  state: AppState;
  onChange: (updates: Partial<AppState>) => void;
  isDarkMode: boolean;
}

// Parse the date string (YYYY-MM-DD) to Date object
const parseDate = (dateStr: string): Date => {
  const [year, month, day] = dateStr.split('-').map(Number);
  return new Date(year, month - 1, day);
};

// Format Date object to YYYY-MM-DD string
const formatDate = (date: Date): string => {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
};

export const Settings: React.FC<SettingsProps> = ({ state, onChange, isDarkMode }) => {
  // Initialize date range from state
  const initialStart = parseDate(state.startDate);
  const initialEnd = new Date(initialStart);
  initialEnd.setDate(initialStart.getDate() + state.numDays - 1);

  // Simple state management - let DatePickerInput control its own state
  const [value, setValue] = useState<[Date | null, Date | null]>([initialStart, initialEnd]);

  return (
    <div className="space-y-4">
      {/* Schedule Range and Display Days - Same Row */}
      <div className="grid grid-cols-1 md:grid-cols-12 gap-4 items-end">
        <div className="md:col-span-7">
          <DatePickerInput
            type="range"
            label={
              <span className={`text-sm font-medium ${isDarkMode ? 'text-gray-300' : 'text-gray-600'}`}>
                Schedule Range ({(() => {
                  if (value && value[0] && value[1]) {
                    const diffTime = value[1].getTime() - value[0].getTime();
                    const days = Math.ceil(diffTime / (1000 * 60 * 60 * 24)) + 1;
                    return `${days} ${days === 1 ? 'day' : 'days'}`;
                  }
                  return `${state.numDays} ${state.numDays === 1 ? 'day' : 'days'}`;
                })()})
              </span>
            }
            placeholder="Select date range"
            value={value}
            minDate={value[0] || new Date()}
            maxDate={value[0] 
              ? new Date(value[0].getTime() + 20 * 24 * 60 * 60 * 1000)
              : new Date(Date.now() + 90 * 24 * 60 * 60 * 1000)
            }
            onChange={(newValue) => {
              // Convert strings to Dates if needed
              const convertedValue: [Date | null, Date | null] = newValue
                ? [
                    newValue[0] ? (typeof newValue[0] === 'string' ? new Date(newValue[0]) : newValue[0]) : null,
                    newValue[1] ? (typeof newValue[1] === 'string' ? new Date(newValue[1]) : newValue[1]) : null
                  ]
                : [null, null];
              
              setValue(convertedValue); // Update local state directly
              
              // Extract and save to app state when both dates are selected
              if (convertedValue[0] && convertedValue[1]) {
                const [start, end] = convertedValue;
                // Calculate number of days (inclusive)
                const diffTime = end.getTime() - start.getTime();
                const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24)) + 1;
                
                // Clamp between 1-20 days
                const clampedDays = Math.min(Math.max(diffDays, 1), 20);
                
                onChange({ 
                  startDate: formatDate(start),
                  numDays: clampedDays
                });
              }
            }}
            valueFormat="MMM DD, YYYY"
            classNames={{
              input: 'border-gray-300 focus:border-primary-500 focus:ring-primary-500'
            }}
          />
        </div>

        {/* Display Days As Toggle */}
        <div className="md:col-span-5">
          <span 
            id="display-days-label"
            className={`block text-sm font-medium mb-2 ${isDarkMode ? 'text-gray-300' : 'text-gray-600'}`}
          >
            Display:
          </span>
          <div 
            role="group"
            aria-labelledby="display-days-label"
            className={`inline-flex rounded-lg border overflow-hidden w-full ${
              isDarkMode ? 'border-gray-600' : 'border-gray-200'
            }`}
          >
            <button
              onClick={() => onChange({ displayDaysAs: 'numbers' })}
              className={`flex-1 px-4 py-2 text-sm font-medium transition-colors ${
                state.displayDaysAs === 'numbers'
                  ? 'bg-primary-500 text-white'
                  : isDarkMode
                    ? 'bg-gray-600 text-gray-100 hover:bg-gray-500'
                    : 'bg-white text-gray-700 hover:bg-gray-50'
              }`}
            >
              Numbers
            </button>
            <button
              onClick={() => onChange({ displayDaysAs: 'dayOfWeek' })}
              className={`flex-1 px-4 py-2 text-sm font-medium transition-colors ${
                state.displayDaysAs === 'dayOfWeek'
                  ? 'bg-primary-500 text-white'
                  : isDarkMode
                    ? 'bg-gray-600 text-gray-100 hover:bg-gray-500'
                    : 'bg-white text-gray-700 hover:bg-gray-50'
              } ${isDarkMode ? 'border-l border-gray-600' : 'border-l border-gray-200'}`}
            >
              Days
            </button>
          </div>
        </div>
      </div>

      {/* Balance Mode - Full Width */}
      <div>
        <span 
          id="balance-mode-label"
          className={`block text-sm font-medium mb-2 ${isDarkMode ? 'text-gray-300' : 'text-gray-600'}`}
        >
          Balance Mode:
        </span>
        <div 
          role="group"
          aria-labelledby="balance-mode-label"
          className={`inline-flex rounded-lg border overflow-hidden ${
            isDarkMode ? 'border-gray-600' : 'border-gray-200'
          }`}
        >
          <button
            onClick={() => onChange({ balanceDaysOff: true })}
            className={`px-4 py-2 text-sm font-medium transition-colors ${
              state.balanceDaysOff
                ? 'bg-primary-500 text-white'
                : isDarkMode
                  ? 'bg-gray-600 text-gray-100 hover:bg-gray-500'
                  : 'bg-white text-gray-700 hover:bg-gray-50'
            }`}
          >
            Proportional
          </button>
          <button
            onClick={() => onChange({ balanceDaysOff: false })}
            className={`px-4 py-2 text-sm font-medium transition-colors ${
              !state.balanceDaysOff
                ? 'bg-primary-500 text-white'
                : isDarkMode
                  ? 'bg-gray-600 text-gray-100 hover:bg-gray-500'
                  : 'bg-white text-gray-700 hover:bg-gray-50'
            } ${isDarkMode ? 'border-l border-gray-600' : 'border-l border-gray-200'}`}
          >
            Equal
          </button>
        </div>
      </div>
    </div>
  );
};