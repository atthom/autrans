import React, { useEffect, useState } from 'react';
import { Accordion } from '@mantine/core';
import { DatePicker } from '@mantine/dates';
import { IconCheck, IconX } from '@tabler/icons-react';

interface TaskDayPickerProps {
  numDays: number;
  selectedDays: number[];
  startDate: string;
  onChange: (days: number[]) => void;
  isDarkMode: boolean;
}

export const TaskDayPicker: React.FC<TaskDayPickerProps> = ({
  numDays,
  selectedDays,
  startDate,
  onChange,
  isDarkMode,
}) => {
  const renderStart = performance.now();
  console.log('[TaskDayPicker] RENDER START', { 
    timestamp: renderStart,
    numDays, 
    selectedDaysCount: selectedDays.length,
    selectedDays 
  });
  
  // Parse start date
  console.log('[TaskDayPicker] Before parseDate');
  const parseDate = (dateStr: string): Date => {
    const [year, month, day] = dateStr.split('-').map(Number);
    return new Date(year, month - 1, day);
  };

  console.log('[TaskDayPicker] Calling parseDate with:', startDate);
  const tripStartDate = parseDate(startDate);
  console.log('[TaskDayPicker] After parseDate, creating tripEndDate');
  
  const tripEndDate = new Date(tripStartDate);
  tripEndDate.setDate(tripStartDate.getDate() + numDays - 1);
  console.log('[TaskDayPicker] tripEndDate created');

  // Track the date to focus the calendar on
  console.log('[TaskDayPicker] Before useState for calendarDate');
  const [calendarDate, setCalendarDate] = useState<Date>(tripStartDate);
  console.log('[TaskDayPicker] After useState for calendarDate');

  // When planning range changes, refocus calendar
  useEffect(() => {
    console.log('[TaskDayPicker] useEffect [startDate, numDays]', { startDate, numDays });
    setCalendarDate(tripStartDate);
  }, [startDate, numDays]);

  // Convert day numbers to Date objects
  console.log('[TaskDayPicker] Before mapping selectedDates');
  const selectedDates = selectedDays.map(dayNum => {
    const date = new Date(tripStartDate);
    date.setDate(tripStartDate.getDate() + dayNum - 1);
    return date;
  });
  console.log('[TaskDayPicker] After mapping selectedDates, count:', selectedDates.length);

  // Convert Date objects back to day numbers
  const handleChange = (value: Date[] | string[]) => {
    // Prevent empty selection
    if (!value || value.length === 0) {
      return;
    }

    const dates = value.map(v => typeof v === 'string' ? new Date(v) : v);
    
    const dayNumbers = dates
      .map(date => {
        const diffTime = date.getTime() - tripStartDate.getTime();
        const dayNum = Math.floor(diffTime / (1000 * 60 * 60 * 24)) + 1;
        return dayNum;
      })
      .filter(day => day >= 1 && day <= numDays)
      .sort((a, b) => a - b);
    
    // Ensure at least one day is selected
    if (dayNumbers.length > 0) {
      onChange(dayNumbers);
    }
  };

  const selectAll = () => {
    const allDays = Array.from({ length: numDays }, (_, i) => i + 1);
    onChange(allDays);
  };

  const clearAll = () => {
    // Keep at least one day selected (day 1)
    onChange([1]);
  };

  const isAllSelected = selectedDays.length === numDays;
  const headerText = isAllSelected 
    ? `Task Days: All days (${numDays})` 
    : `Task Days: ${selectedDays.length} of ${numDays} days`;

  console.log('[TaskDayPicker] Before return/render JSX');
  const renderEnd = performance.now();
  console.log('[TaskDayPicker] Render took:', renderEnd - renderStart, 'ms');
  
  return (
    <Accordion>
      <Accordion.Item value="task-days">
        <Accordion.Control onClick={() => {
          console.log('[TaskDayPicker] Task Days accordion clicked');
          console.log('[TaskDayPicker] Selected days:', selectedDays);
          console.log('[TaskDayPicker] Total days:', numDays);
          console.log('[TaskDayPicker] Accordion.Panel will render next');
        }}>
          <span className={`font-medium ${isDarkMode ? 'text-gray-100' : 'text-gray-900'}`}>
            {headerText}
          </span>
        </Accordion.Control>
        <Accordion.Panel>
          <div className="space-y-3">
            {/* Date Picker - Multiple Selection */}
            <div className="flex justify-center">
              <DatePicker
                type="multiple"
                value={selectedDates}
                onChange={(value) => {
                  console.log('[TaskDayPicker] DatePicker onChange called with:', value);
                  handleChange(value);
                  console.log('[TaskDayPicker] DatePicker onChange completed');
                }}
                date={calendarDate}
                onDateChange={(date) => {
                  console.log('[TaskDayPicker] DatePicker onDateChange called');
                  setCalendarDate(typeof date === 'string' ? new Date(date) : date);
                }}
                minDate={tripStartDate}
                maxDate={tripEndDate}
              />
            </div>

            {/* Action buttons and summary */}
            <div className="flex items-center justify-between text-xs gap-2">
              <div className="flex gap-2">
                <button
                  onClick={selectAll}
                  disabled={isAllSelected}
                  className={`px-3 py-1.5 rounded transition-colors flex items-center gap-1 ${
                    isAllSelected
                      ? 'bg-gray-100 text-gray-400 cursor-not-allowed'
                      : isDarkMode
                      ? 'bg-gray-700 hover:bg-gray-600 text-gray-200'
                      : 'bg-gray-100 hover:bg-gray-200 text-gray-700'
                  }`}
                >
                  <IconCheck size={14} />
                  Select All
                </button>
                <button
                  onClick={clearAll}
                  disabled={selectedDays.length === 1}
                  className={`px-3 py-1.5 rounded transition-colors flex items-center gap-1 ${
                    selectedDays.length === 1
                      ? isDarkMode
                        ? 'bg-gray-800 text-gray-600 cursor-not-allowed'
                        : 'bg-gray-100 text-gray-400 cursor-not-allowed'
                      : isDarkMode
                      ? 'bg-gray-700 hover:bg-gray-600 text-gray-200'
                      : 'bg-gray-100 hover:bg-gray-200 text-gray-700'
                  }`}
                >
                  <IconX size={14} />
                  Clear
                </button>
              </div>
              <span className={`font-medium ${isDarkMode ? 'text-gray-300' : 'text-gray-600'}`}>
                {selectedDays.length} {selectedDays.length === 1 ? 'day' : 'days'} selected
              </span>
            </div>

            {/* Validation message */}
            {selectedDays.length === 1 && (
              <div className={`text-xs italic ${isDarkMode ? 'text-gray-400' : 'text-gray-500'}`}>
                Note: At least one day must be selected
              </div>
            )}
          </div>
        </Accordion.Panel>
      </Accordion.Item>
    </Accordion>
  );
};