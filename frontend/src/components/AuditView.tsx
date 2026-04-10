import React from 'react';
import { AuditTable } from './ScheduleTable';
import { getDayLabel } from '../utils/helpers';
import type { ScheduleResponse } from '../types';

interface AuditViewProps {
  scheduleData: ScheduleResponse;
  startDate: string;
  numDays: number;
  displayDaysAs: 'numbers' | 'dayOfWeek';
  isDarkMode?: boolean;
}

export const AuditView: React.FC<AuditViewProps> = ({ scheduleData, startDate, numDays, displayDaysAs, isDarkMode = false }) => {
  const capacity = scheduleData.capacity_analysis;

  return (
    <div className="space-y-8">
      {/* Global Metrics */}
      {capacity && (
        <div>
          <h3 className={`text-xl font-semibold mb-4 ${isDarkMode ? 'text-gray-200' : 'text-gray-800'}`}>📊 Global Metrics</h3>
          <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
            <div className={`border rounded-lg p-4 text-center ${isDarkMode ? 'bg-gray-800 border-gray-700' : 'bg-white border-gray-200'}`}>
              <div className={`text-3xl font-bold ${isDarkMode ? 'text-accent-400' : 'text-accent-500'}`}>{capacity.num_days}</div>
              <div className={`text-sm mt-1 ${isDarkMode ? 'text-gray-400' : 'text-gray-600'}`}>Days</div>
            </div>
            <div className={`border rounded-lg p-4 text-center ${isDarkMode ? 'bg-gray-800 border-gray-700' : 'bg-white border-gray-200'}`}>
              <div className={`text-3xl font-bold ${isDarkMode ? 'text-accent-400' : 'text-accent-500'}`}>{capacity.num_workers}</div>
              <div className={`text-sm mt-1 ${isDarkMode ? 'text-gray-400' : 'text-gray-600'}`}>Workers</div>
            </div>
            <div className={`border rounded-lg p-4 text-center ${isDarkMode ? 'bg-gray-800 border-gray-700' : 'bg-white border-gray-200'}`}>
              <div className={`text-3xl font-bold ${isDarkMode ? 'text-accent-400' : 'text-accent-500'}`}>{capacity.num_tasks}</div>
              <div className={`text-sm mt-1 ${isDarkMode ? 'text-gray-400' : 'text-gray-600'}`}>Tasks</div>
            </div>
            <div className={`border rounded-lg p-4 text-center ${isDarkMode ? 'bg-gray-800 border-gray-700' : 'bg-white border-gray-200'}`}>
              <div className={`text-3xl font-bold ${isDarkMode ? 'text-accent-400' : 'text-accent-500'}`}>{capacity.total_slots}</div>
              <div className={`text-sm mt-1 ${isDarkMode ? 'text-gray-400' : 'text-gray-600'}`}>Task Slots</div>
            </div>
            <div className={`border rounded-lg p-4 text-center ${isDarkMode ? 'bg-gray-800 border-gray-700' : 'bg-white border-gray-200'}`}>
              <div className={`text-3xl font-bold ${isDarkMode ? 'text-accent-400' : 'text-accent-500'}`}>{capacity.utilization_percent}%</div>
              <div className={`text-sm mt-1 ${isDarkMode ? 'text-gray-400' : 'text-gray-600'}`}>Utilization</div>
            </div>
          </div>
        </div>
      )}

      {/* Day by Day Breakdown */}
      {capacity?.daily_breakdown && capacity.daily_breakdown.length > 0 && (
        <div>
          <h3 className={`text-xl font-semibold mb-4 ${isDarkMode ? 'text-gray-200' : 'text-gray-800'}`}>📅 Day by Day Breakdown</h3>
          <div className="overflow-x-auto">
            <table className={`w-full border-collapse ${isDarkMode ? 'bg-gray-800' : 'bg-white'}`}>
              <thead>
                <tr className={isDarkMode ? 'bg-gray-700' : 'bg-gray-100'}>
                  <th className={`border px-4 py-2 text-center font-semibold ${isDarkMode ? 'border-gray-600 text-gray-200' : 'border-gray-300'}`}>Day</th>
                  <th className={`border px-4 py-2 text-center font-semibold ${isDarkMode ? 'border-gray-600 text-gray-200' : 'border-gray-300'}`}>Task Slots</th>
                  <th className={`border px-4 py-2 text-center font-semibold ${isDarkMode ? 'border-gray-600 text-gray-200' : 'border-gray-300'}`}>Workers Available</th>
                  <th className={`border px-4 py-2 text-center font-semibold ${isDarkMode ? 'border-gray-600 text-gray-200' : 'border-gray-300'}`}>Workers Unavailable</th>
                </tr>
              </thead>
              <tbody>
                {capacity.daily_breakdown.map((dayInfo, index) => {
                  const dayLabel = getDayLabel(dayInfo.day, startDate, displayDaysAs, numDays);
                  return (
                    <tr key={index} className={isDarkMode ? 'hover:bg-gray-700' : 'hover:bg-gray-50'}>
                      <td className={`border px-4 py-2 text-center ${isDarkMode ? 'border-gray-600 text-gray-300' : 'border-gray-300'}`}>{dayLabel}</td>
                      <td className={`border px-4 py-2 text-center ${isDarkMode ? 'border-gray-600 text-gray-300' : 'border-gray-300'}`}>{dayInfo.slots_needed}</td>
                      <td className={`border px-4 py-2 text-center ${isDarkMode ? 'border-gray-600 text-gray-300' : 'border-gray-300'}`}>{dayInfo.workers_available}</td>
                      <td className={`border px-4 py-2 text-center ${isDarkMode ? 'border-gray-600 text-gray-300' : 'border-gray-300'}`}>
                        {dayInfo.workers_off.length > 0 ? dayInfo.workers_off.join(', ') : '-'}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}

      <hr className={isDarkMode ? 'border-gray-700' : 'border-gray-300'} />

      {/* Schedule Grid */}
      <AuditTable data={scheduleData.display} title="Schedule" isDarkMode={isDarkMode} />

      {/* Affectation per day */}
      <AuditTable data={scheduleData.time} title="Affectation per day" isDarkMode={isDarkMode} />

      {/* Affectation per task */}
      <AuditTable data={scheduleData.jobs} title="Affectation per task" isDarkMode={isDarkMode} />

      <hr className={`my-6 ${isDarkMode ? 'border-gray-700' : 'border-gray-300'}`} />

      {/* Legend */}
      <h3 className={`text-lg font-semibold mb-4 ${isDarkMode ? 'text-gray-200' : 'text-gray-800'}`}>📖 Legend</h3>
      <div className={`text-sm space-y-4 ${isDarkMode ? 'text-gray-300' : 'text-gray-700'}`}>
        <div>
          <p className="font-semibold mb-2">Understanding the Audit Tables:</p>
          <ul className="list-none space-y-1 ml-2">
            <li>- <strong>Schedule:</strong> Shows which workers are assigned to each task on each day</li>
            <li>- <strong>Affectation per day:</strong> Shows how many tasks each worker does per day (and total difficulty points)</li>
            <li>- <strong>Affectation per task:</strong> Shows how many times each worker does each task (and total difficulty points)</li>
          </ul>
        </div>
        
        <div>
          <p className="font-semibold mb-2">Notation:</p>
          <ul className="list-none space-y-1 ml-2">
            <li>- <strong>*</strong> (asterisk) = Worker had a day off on that day/task period</li>
            <li>- Numbers with * indicate work done despite having days off in that period</li>
            <li>- <strong>Format:</strong> <code className={`px-1 rounded ${isDarkMode ? 'bg-gray-700' : 'bg-gray-100'}`}>count (difficulty pts)</code> - Shows both task count and total difficulty points</li>
            <li>- <strong>Example:</strong> <code className={`px-1 rounded ${isDarkMode ? 'bg-gray-700' : 'bg-gray-100'}`}>3 (7 pts)</code> means 3 tasks with a combined difficulty of 7 points</li>
            <li>- TOTAL row/column shows the sum across all days/tasks</li>
          </ul>
        </div>

        <div>
          <p className="font-semibold mb-2">Task Difficulty:</p>
          <ul className="list-none space-y-1 ml-2">
            <li>- Each task has a difficulty value (default: 1)</li>
            <li>- Higher difficulty = more challenging/time-consuming task</li>
            <li>- Workload is balanced by difficulty points, not just task count</li>
            <li>- Example: 2 easy tasks (2 pts) ≈ 1 hard task (2 pts)</li>
          </ul>
        </div>
      </div>
    </div>
  );
};