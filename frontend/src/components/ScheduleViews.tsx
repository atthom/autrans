import React from 'react';
import { Tabs, SectionHeader } from './common';
import { ScheduleTable } from './ScheduleTable';
import { DailySchedule } from './DailySchedule';
import { AuditView } from './AuditView';
import type { ScheduleResponse } from '../types';

interface ScheduleViewsProps {
  scheduleData: ScheduleResponse;
  startDate: string;
  numDays: number;
  colors: string[];
  displayDaysAs: 'numbers' | 'dayOfWeek';
  isDarkMode: boolean;
}

export const ScheduleViews: React.FC<ScheduleViewsProps> = ({
  scheduleData,
  startDate,
  numDays,
  colors,
  displayDaysAs,
  isDarkMode,
}) => {
  const tabs = [
    {
      id: 'table',
      label: 'Table Schedule',
      icon: '📋',
      content: (
        <div>
          <SectionHeader
            icon="📋"
            title="Table Schedule"
            description="Grid view of task assignments"
          />
          <ScheduleTable 
            scheduleData={scheduleData.display} 
            colors={colors}
            startDate={startDate}
            numDays={numDays}
            displayDaysAs={displayDaysAs}
          />
        </div>
      ),
    },
    {
      id: 'daily',
      label: 'Daily Schedule',
      icon: '📅',
      content: (
        <div>
          <SectionHeader
            icon="📅"
            title="Daily Schedule"
            description="Day-by-day view with task cards"
          />
          <DailySchedule
            scheduleData={scheduleData.display}
            startDate={startDate}
            numDays={numDays}
            colors={colors}
            displayDaysAs={displayDaysAs}
          />
        </div>
      ),
    },
    {
      id: 'audit',
      label: 'Audit',
      icon: '📊',
      content: (
        <div>
          <SectionHeader
            icon="📊"
            title="Audit"
            description="Detailed metrics and workload analysis"
          />
          <AuditView 
            scheduleData={scheduleData} 
            startDate={startDate} 
            numDays={numDays}
            displayDaysAs={displayDaysAs}
          />
        </div>
      ),
    },
  ];

  return (
    <div className="bg-white dark:bg-gray-800 rounded-lg shadow-md border border-gray-200 dark:border-gray-700 p-6">
      <Tabs tabs={tabs} defaultTab="table" isDarkMode={isDarkMode} />
    </div>
  );
};