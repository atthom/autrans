import React from 'react';
import { Modal, Button } from './common';
import type { FailureResponse } from '../types';

interface ErrorDialogProps {
  isOpen: boolean;
  onClose: () => void;
  error: FailureResponse;
  tasks?: Array<[string, number, number, ...number[]]>;  // New format: [name, num_workers, difficulty, ...selected_days]
  workers?: Array<[string, number[], number[], number]>;
  numDays?: number;
}

export const ErrorDialog: React.FC<ErrorDialogProps> = ({
  isOpen,
  onClose,
  error,
  tasks = [],
  workers = [],
  numDays = 0,
}) => {
  const details = error.details;

  // Calculate global metrics
  const numTasks = tasks.length;
  const totalSlots = tasks.reduce((sum, task) => sum + task[1], 0);
  const numWorkers = workers.length;
  const avgWorkload = numWorkers > 0 ? (totalSlots / numWorkers).toFixed(1) : 'N/A';

  // Parse conflict analysis if available
  let diagnosticData: any = null;
  if (details?.conflict_analysis && details.conflict_analysis.length > 0) {
    try {
      diagnosticData = JSON.parse(details.conflict_analysis[0]);
    } catch (e) {
      // Fallback to raw text
    }
  }

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title="Schedule is not feasible"
      size="lg"
      footer={
        <div className="flex justify-center">
          <Button onClick={onClose} variant="primary">
            OK
          </Button>
        </div>
      }
    >
      <div className="space-y-6">
        {/* Global Metrics */}
        {numDays > 0 && (
          <div>
            <h3 className="text-lg font-semibold text-gray-800 dark:text-gray-200 mb-3">📊 Global Metrics</h3>
            <div className="grid grid-cols-3 md:grid-cols-6 gap-3">
              <div className="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded p-3 text-center">
                <div className="text-2xl font-bold text-primary-500 dark:text-primary-400">{numDays}</div>
                <div className="text-xs text-gray-600 dark:text-gray-400">Days</div>
              </div>
              <div className="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded p-3 text-center">
                <div className="text-2xl font-bold text-primary-500 dark:text-primary-400">{numWorkers}</div>
                <div className="text-xs text-gray-600 dark:text-gray-400">Workers</div>
              </div>
              <div className="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded p-3 text-center">
                <div className="text-2xl font-bold text-primary-500 dark:text-primary-400">{numTasks}</div>
                <div className="text-xs text-gray-600 dark:text-gray-400">Tasks</div>
              </div>
              <div className="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded p-3 text-center">
                <div className="text-2xl font-bold text-primary-500 dark:text-primary-400">{totalSlots}</div>
                <div className="text-xs text-gray-600 dark:text-gray-400">Task Slots</div>
              </div>
              <div className="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded p-3 text-center">
                <div className="text-2xl font-bold text-primary-500 dark:text-primary-400">{avgWorkload}</div>
                <div className="text-xs text-gray-600 dark:text-gray-400">Daily Workload</div>
              </div>
              <div className="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded p-3 text-center">
                <div className="text-2xl font-bold text-primary-500 dark:text-primary-400">
                  {details?.constraints?.length || 0}
                </div>
                <div className="text-xs text-gray-600 dark:text-gray-400">Constraints</div>
              </div>
            </div>
          </div>
        )}

        {/* Schedule Analysis */}
        {diagnosticData && (
          <div>
            <h3 className="text-lg font-semibold text-gray-800 dark:text-gray-200 mb-3">
              {diagnosticData.title || 'Schedule Analysis'}
            </h3>
            
            {/* Warnings */}
            {diagnosticData.warnings && diagnosticData.warnings.length > 0 && (
              <div className="mb-4">
                <h4 className="text-md font-semibold text-gray-800 dark:text-gray-200 mb-2">⚠️ Warnings</h4>
                <div className="space-y-2">
                  {diagnosticData.warnings.map((warning: string, index: number) => (
                    <div key={index} className="p-3 bg-yellow-50 dark:bg-yellow-900/30 border border-yellow-200 dark:border-yellow-700 rounded text-yellow-800 dark:text-yellow-200">
                      {warning}
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Suggestions */}
            {diagnosticData.suggestions && diagnosticData.suggestions.length > 0 && (
              <div>
                <h4 className="text-md font-semibold text-gray-800 dark:text-gray-200 mb-2">💡 Suggestions</h4>
                <div className="space-y-2">
                  {diagnosticData.suggestions.map((suggestion: string, index: number) => (
                    <div key={index} className="p-3 bg-green-50 dark:bg-green-900/30 border border-green-200 dark:border-green-700 rounded text-green-800 dark:text-green-200">
                      {suggestion}
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        )}

        {/* Day by Day Breakdown */}
        {details?.capacity?.daily_breakdown && details.capacity.daily_breakdown.length > 0 && (
          <div>
            <h3 className="text-lg font-semibold text-gray-800 dark:text-gray-200 mb-3">Day by Day Breakdown</h3>
            <div className="overflow-x-auto">
              <table className="w-full border-collapse text-sm">
                <thead>
                  <tr className="bg-gray-100 dark:bg-gray-700">
                    <th className="border border-gray-300 dark:border-gray-600 px-3 py-2 text-center dark:text-gray-200">Day</th>
                    <th className="border border-gray-300 dark:border-gray-600 px-3 py-2 text-center dark:text-gray-200">Task Slots</th>
                    <th className="border border-gray-300 dark:border-gray-600 px-3 py-2 text-center dark:text-gray-200">Workers Available</th>
                    <th className="border border-gray-300 dark:border-gray-600 px-3 py-2 text-center dark:text-gray-200">Workers Unavailable</th>
                  </tr>
                </thead>
                <tbody>
                  {details.capacity.daily_breakdown.map((dayInfo: any, index: number) => (
                    <tr key={index} className="hover:bg-gray-50 dark:hover:bg-gray-700">
                      <td className="border border-gray-300 dark:border-gray-600 px-3 py-2 text-center dark:text-gray-300">{dayInfo.day}</td>
                      <td className="border border-gray-300 dark:border-gray-600 px-3 py-2 text-center dark:text-gray-300">{dayInfo.slots_needed}</td>
                      <td className="border border-gray-300 dark:border-gray-600 px-3 py-2 text-center dark:text-gray-300">{dayInfo.workers_available}</td>
                      <td className="border border-gray-300 dark:border-gray-600 px-3 py-2 text-center dark:text-gray-300">
                        {dayInfo.workers_off?.length > 0 ? dayInfo.workers_off.join(', ') : '-'}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* Constraint Details */}
        {details?.constraints && details.constraints.length > 0 && (
          <details className="bg-gray-50 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded p-4">
            <summary className="font-medium text-gray-900 dark:text-gray-100 cursor-pointer">
              Constraint Details ({details.constraints.length})
            </summary>
            <div className="mt-3 space-y-1 text-sm text-gray-700 dark:text-gray-300">
              {details.constraints.slice(0, 10).map((constraint: string, index: number) => (
                <div key={index}>• {constraint}</div>
              ))}
              {details.constraints.length > 10 && (
                <div className="text-gray-500 dark:text-gray-400 italic">
                  ... and {details.constraints.length - 10} more
                </div>
              )}
            </div>
          </details>
        )}

        {/* Failed Level */}
        {details?.failed_level !== undefined && details.failed_level !== null && (
          <div className="text-sm text-gray-600 dark:text-gray-400 text-center">
            Failed at relaxation level {details.failed_level}
          </div>
        )}

        {/* Fallback: Basic message if no detailed diagnostics */}
        {!diagnosticData && !details?.capacity && (
          <div className="p-4 bg-gray-50 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded">
            <p className="text-gray-700 dark:text-gray-300">{error.msg}</p>
          </div>
        )}
      </div>
    </Modal>
  );
};