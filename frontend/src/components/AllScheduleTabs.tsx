import React from 'react';
import { Skeleton } from '@mantine/core';
import { Tabs } from './common';
import { ScheduleTable } from './ScheduleTable';
import { DailySchedule } from './DailySchedule';
import { AuditView } from './AuditView';
import { ExportPanel } from './ExportPanel';
import { HelpPanel } from './HelpPanel';
import type { ScheduleResponse, ScheduleRequest } from '../types';

interface AllScheduleTabsProps {
  scheduleData: ScheduleResponse | null;
  scheduleRequest: ScheduleRequest | null;
  startDate: string;
  numDays: number;
  tripName: string;
  colors: string[];
  displayDaysAs: 'numbers' | 'dayOfWeek';
  isLoading: boolean;
  isDarkMode: boolean;
}

export const AllScheduleTabs: React.FC<AllScheduleTabsProps> = ({
  scheduleData,
  scheduleRequest,
  startDate,
  numDays,
  tripName,
  colors,
  displayDaysAs,
  isLoading,
  isDarkMode,
}) => {
  // Skeleton loading component
  const LoadingSkeleton = () => (
    <div className="space-y-4">
      <Skeleton height={50} radius="md" />
      <Skeleton height={40} radius="md" />
      <Skeleton height={40} radius="md" />
      <Skeleton height={40} radius="md" />
      <Skeleton height={40} radius="md" />
      <Skeleton height={40} radius="md" />
      <Skeleton height={40} width="80%" radius="md" />
    </div>
  );

  const tabs = [
    {
      id: 'table',
      label: 'Table Schedule',
      icon: '📋',
      content: (
        <div>
          <div className={`text-white rounded-lg px-6 py-3 text-center mb-5 ${isDarkMode ? 'bg-primary-600' : 'bg-primary-500'}`}>
            <h2 className="text-2xl font-bold m-0">Table Schedule</h2>
          </div>
          {isLoading ? (
            <LoadingSkeleton />
          ) : scheduleData ? (
            <ScheduleTable 
              scheduleData={scheduleData.display} 
              colors={colors}
              startDate={startDate}
              numDays={numDays}
              displayDaysAs={displayDaysAs}
              isDarkMode={isDarkMode}
            />
          ) : (
            <div className={`text-center py-8 ${isDarkMode ? 'text-gray-400' : 'text-gray-500'}`}>
              📋 Generate a schedule first to view the table schedule
            </div>
          )}
        </div>
      ),
    },
    {
      id: 'daily',
      label: 'Daily Schedule',
      icon: '📅',
      content: (
        <div>
          <div className={`text-white rounded-lg px-6 py-3 text-center mb-5 ${isDarkMode ? 'bg-primary-600' : 'bg-primary-500'}`}>
            <h2 className="text-2xl font-bold m-0">Daily Schedule</h2>
          </div>
          {isLoading ? (
            <LoadingSkeleton />
          ) : scheduleData ? (
            <DailySchedule
              scheduleData={scheduleData.display}
              startDate={startDate}
              numDays={numDays}
              colors={colors}
              displayDaysAs={displayDaysAs}
              isDarkMode={isDarkMode}
            />
          ) : (
            <div className={`text-center py-8 ${isDarkMode ? 'text-gray-400' : 'text-gray-500'}`}>
              📅 Generate a schedule first to view the daily schedule
            </div>
          )}
        </div>
      ),
    },
    {
      id: 'audit',
      label: 'Audit',
      icon: '📊',
      content: (
        <div>
          <div className={`text-white rounded-lg px-6 py-3 text-center mb-5 ${isDarkMode ? 'bg-primary-600' : 'bg-primary-500'}`}>
            <h2 className="text-2xl font-bold m-0">Audit</h2>
          </div>
          {isLoading ? (
            <LoadingSkeleton />
          ) : scheduleData ? (
            <AuditView 
              scheduleData={scheduleData} 
              startDate={startDate} 
              numDays={numDays}
              displayDaysAs={displayDaysAs}
              isDarkMode={isDarkMode}
            />
          ) : (
            <div className={`text-center py-8 ${isDarkMode ? 'text-gray-400' : 'text-gray-500'}`}>
              📊 Generate a schedule first to view the audit information
            </div>
          )}
        </div>
      ),
    },
    {
      id: 'export',
      label: 'Export',
      icon: '💾',
      content: (
        <div>
          <div className={`text-white rounded-lg px-6 py-3 text-center mb-5 ${isDarkMode ? 'bg-primary-600' : 'bg-primary-500'}`}>
            <h2 className="text-2xl font-bold m-0">📥 Export Your Schedule</h2>
          </div>
          {scheduleData && scheduleRequest ? (
            <ExportPanel
              scheduleRequest={scheduleRequest}
              tripName={tripName}
              startDate={startDate}
              numDays={numDays}
              isDarkMode={isDarkMode}
            />
          ) : (
            <div className={`text-center py-8 ${isDarkMode ? 'text-gray-400' : 'text-gray-500'}`}>
              📋 Generate a schedule first to enable export options
            </div>
          )}
        </div>
      ),
    },
    {
      id: 'help',
      label: 'Help',
      icon: '📚',
      content: <HelpPanel isDarkMode={isDarkMode} />,
    },
  ];

  return (
    <div className={`rounded-lg shadow-md border p-6 transition-colors duration-200 ${
      isDarkMode ? 'bg-gray-800 border-gray-700' : 'bg-white border-gray-200'
    }`}>
      <Tabs tabs={tabs} defaultTab="table" isDarkMode={isDarkMode} />
    </div>
  );
};