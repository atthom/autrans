import React, { useEffect, useState } from 'react';
import { DatePicker } from '@mantine/dates';
import { IconX } from '@tabler/icons-react';

interface DaysOffPickerProps {
  numDays: number;
  selectedDays: number[];
  startDate: string;
  displayMode: 'numbers' | 'dayOfWeek';
  onChange: (days: number[]) => void;
}

export const DaysOffPicker: React.FC<DaysOffPickerProps> = ({
  numDays,
  selectedDays,
  startDate,
  onChange,
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

  // When planning range changes, refocus calendar and clear selections
  useEffect(() => {
    setCalendarDate(tripStartDate);
    // Clear days off when range changes
    if (selectedDays.length > 0) {
      onChange([]);
    }
  }, [startDate, numDays]);

  // Convert day numbers to Date objects
  const selectedDates = selectedDays.map(dayNum => {
    const date = new Date(tripStartDate);
    date.setDate(tripStartDate.getDate() + dayNum - 1);
    return date;
  });

  // Convert Date objects back to day numbers
  const handleChange = (value: Date[] | string[]) => {
    // Convert strings to Dates if needed
    const dates = value.map(v => typeof v === 'string' ? new Date(v) : v);
    
    const dayNumbers = dates
      .map(date => {
        const diffTime = date.getTime() - tripStartDate.getTime();
        const dayNum = Math.floor(diffTime / (1000 * 60 * 60 * 24)) + 1;
        return dayNum;
      })
      .filter(day => day >= 1 && day <= numDays)
      .sort((a, b) => a - b);
    
    onChange(dayNumbers);
  };

  const clearAll = () => {
    onChange([]);
  };

  return (
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
      <div className="flex items-center justify-between text-xs">
        <button
          onClick={clearAll}
          className="px-3 py-1.5 bg-gray-100 dark:bg-gray-700 hover:bg-gray-200 dark:hover:bg-gray-600 text-gray-700 dark:text-gray-200 rounded transition-colors flex items-center gap-1"
        >
          <IconX size={14} />
          Clear
        </button>
        <span className="text-gray-600 font-medium">
          {selectedDays.length} {selectedDays.length === 1 ? 'day' : 'days'} off
        </span>
      </div>
    </div>
  );
};