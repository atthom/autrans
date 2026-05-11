import React, { useMemo } from 'react';
import { generateDateRange, getFormattedDate, getDayLabel } from '../utils/helpers';
import { parseTableData } from '../utils/helpers';
import type { ScheduleResponse } from '../types';

interface DailyScheduleProps {
  scheduleData: ScheduleResponse['display'];
  startDate: string;
  numDays: number;
  colors?: string[];
  displayDaysAs: 'numbers' | 'dayOfWeek';
  isDarkMode?: boolean;
}

export const DailySchedule: React.FC<DailyScheduleProps> = React.memo(({
  scheduleData,
  startDate,
  numDays,
  colors = [],
  displayDaysAs,
  isDarkMode = false,
}) => {
  const { headers, rows } = useMemo(() => parseTableData(scheduleData), [scheduleData]);
  const dates = generateDateRange(startDate, numDays);

  // headers[0] is "Tasks", rest are day columns
  const dayColumns = headers.slice(1);

  return (
    <div className="space-y-6">
      {dayColumns.map((_, dayIndex) => {
        const date = dates[dayIndex];
        const dateStr = getFormattedDate(date);
        const displayLabel = getDayLabel(dayIndex + 1, startDate, displayDaysAs, numDays);

        return (
          <div key={dayIndex} className={`border-b pb-6 last:border-b-0 ${isDarkMode ? 'border-gray-700' : 'border-gray-200'}`}>
            <h3 className={`text-xl font-semibold mb-4 ${isDarkMode ? 'text-primary-400' : 'text-primary-600'}`}>
              {dateStr} - {displayLabel}
            </h3>

            <div className="space-y-3">
              {rows.map((row, taskIndex) => {
                const taskName = row[0];
                const assignments = row[dayIndex + 1]; // +1 because first column is task name

                if (!assignments || !assignments.trim()) {
                  return null; // Skip empty assignments
                }

                const color = colors[taskIndex] || '#e5e7eb';
                const workerNames = assignments.split(', ');

                return (
                  <div
                    key={taskIndex}
                    className={`rounded-lg border p-4 shadow-sm ${isDarkMode ? 'border-gray-600' : 'border-gray-300'}`}
                    style={{ backgroundColor: color }}
                  >
                    <div className={`font-semibold mb-2 ${isDarkMode ? 'text-gray-100' : 'text-gray-900'}`}>{taskName}</div>
                    <div className="space-y-1">
                      {workerNames.map((name, idx) => (
                        <div key={idx} className={isDarkMode ? 'text-gray-200' : 'text-gray-800'}>
                          {name}
                        </div>
                      ))}
                    </div>
                  </div>
                );
              })}

              {/* Show message if no tasks for this day */}
              {rows.every((row) => !row[dayIndex + 1] || !row[dayIndex + 1].trim()) && (
                <div className={`text-center py-8 italic ${isDarkMode ? 'text-gray-400' : 'text-gray-500'}`}>
                  No tasks scheduled for this day
                </div>
              )}
            </div>
          </div>
        );
      })}
    </div>
  );
});

DailySchedule.displayName = 'DailySchedule';
