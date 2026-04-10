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
  // Parse start date
  const parseDate = (dateStr: string): Date => {
    const [year, month, day] = dateStr.split('-').map(Number);
    return new Date(year, month - 1, day);
  };

  const tripStartDate = parseDate(startDate);
  const tripEndDate = new Date(tripStartDate);
  tripEndDate.setDate(tripStartDate.getDate() + numDays - 1);

  // Track the date to focus the calendar on
  const [calendarDate, setCalendarDate] = useState<Date>(tripStartDate);

  // When planning range changes, refocus calendar
  useEffect(() => {
    setCalendarDate(tripStartDate);
  }, [startDate, numDays]);

  // Convert day numbers to Date objects
  const selectedDates = selectedDays.map(dayNum => {
    const date = new Date(tripStartDate);
    date.setDate(tripStartDate.getDate() + dayNum - 1);
    return date;
  });

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

  return (
    <Accordion>
      <Accordion.Item value="task-days">
        <Accordion.Control>
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
                onChange={handleChange}
                date={calendarDate}
                onDateChange={(date) => setCalendarDate(typeof date === 'string' ? new Date(date) : date)}
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