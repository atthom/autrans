import React, { useState } from 'react';
import { Accordion } from '@mantine/core';
import { Button } from './common';
import { scheduleApi } from '../api/client';
import { downloadFile, generateExportFilename } from '../utils/helpers';
import type { ScheduleRequest } from '../types';

interface ExportPanelProps {
  scheduleRequest: ScheduleRequest;
  tripName: string;
  startDate: string;
  numDays: number;
  isDarkMode?: boolean;
}

export const ExportPanel: React.FC<ExportPanelProps> = ({
  scheduleRequest,
  tripName,
  startDate,
  numDays,
  isDarkMode = false,
}) => {
  const [isExportingICS, setIsExportingICS] = useState(false);
  const [isExportingCSV, setIsExportingCSV] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleExportICS = async () => {
    setIsExportingICS(true);
    setError(null);
    
    try {
      const exportPayload = {
        workers: scheduleRequest.workers,
        tasks: scheduleRequest.tasks,
        nb_days: scheduleRequest.nb_days,
        balance_daysoff: scheduleRequest.balance_daysoff,
        start_date: startDate,
        trip_name: tripName,
      };

      const blob = await scheduleApi.exportICS(exportPayload);
      const filename = generateExportFilename(tripName, startDate, numDays, 'ics');
      downloadFile(blob, filename);
    } catch (err: any) {
      setError(err.response?.data?.error || 'Failed to export ICS file');
    } finally {
      setIsExportingICS(false);
    }
  };

  const handleExportCSV = async () => {
    setIsExportingCSV(true);
    setError(null);
    
    try {
      const exportPayload = {
        workers: scheduleRequest.workers,
        tasks: scheduleRequest.tasks,
        nb_days: scheduleRequest.nb_days,
        balance_daysoff: scheduleRequest.balance_daysoff,
        start_date: startDate,
        trip_name: tripName,
      };

      const blob = await scheduleApi.exportCSV(exportPayload);
      const filename = generateExportFilename(tripName, startDate, numDays, 'csv');
      downloadFile(blob, filename);
    } catch (err: any) {
      setError(err.response?.data?.error || 'Failed to export CSV file');
    } finally {
      setIsExportingCSV(false);
    }
  };

  return (
    <div>
      {error && (
        <div className={`mb-6 p-4 border rounded-lg ${
          isDarkMode 
            ? 'bg-red-900/30 border-red-700 text-red-200' 
            : 'bg-red-50 border-red-200 text-red-800'
        }`}>
          <strong>Error:</strong> {error}
        </div>
      )}

      <h3 className={`text-lg font-semibold mb-4 ${isDarkMode ? 'text-gray-100' : 'text-gray-800'}`}>Choose your export format:</h3>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
        {/* iCalendar Export */}
        <div>
          <Button
            onClick={handleExportICS}
            disabled={isExportingICS}
            variant="primary"
            className="w-full mb-4"
          >
            {isExportingICS ? 'Exporting...' : '📅 Download iCalendar (.ics)'}
          </Button>

          <div className={`text-sm ${isDarkMode ? 'text-gray-300' : 'text-gray-700'}`}>
            <p className="font-medium mb-2">Compatible with:</p>
            <ul className="list-none space-y-1">
              <li>- Microsoft Outlook</li>
              <li>- Google Calendar</li>
              <li>- Apple Calendar</li>
              <li>- Any calendar app</li>
            </ul>
          </div>
        </div>

        {/* CSV Export */}
        <div>
          <Button
            onClick={handleExportCSV}
            disabled={isExportingCSV}
            variant="primary"
            className="w-full mb-4"
          >
            {isExportingCSV ? 'Exporting...' : '📊 Download CSV'}
          </Button>

          <div className={`text-sm ${isDarkMode ? 'text-gray-300' : 'text-gray-700'}`}>
            <p className="font-medium mb-2">Compatible with:</p>
            <ul className="list-none space-y-1">
              <li>- Microsoft Excel</li>
              <li>- Google Sheets</li>
              <li>- LibreOffice Calc</li>
              <li>- Any spreadsheet app</li>
            </ul>
          </div>
        </div>
      </div>

      <hr className={`my-6 ${isDarkMode ? 'border-gray-600' : 'border-gray-300'}`} />

      {/* Import Instructions */}
      <h3 className={`text-lg font-semibold mb-4 ${isDarkMode ? 'text-gray-100' : 'text-gray-800'}`}>📖 Import Instructions</h3>
      
      <Accordion>
        <Accordion.Item value="ics">
          <Accordion.Control>
            <span className={`font-medium ${isDarkMode ? 'text-gray-100' : 'text-gray-900'}`}>📅 How to import iCalendar (.ics) files</span>
          </Accordion.Control>
          <Accordion.Panel>
          <div className={`p-4 text-sm space-y-4 ${isDarkMode ? 'text-gray-300' : 'text-gray-700'}`}>
            <div>
              <p className="font-semibold mb-1">Microsoft Outlook:</p>
              <ol className="list-decimal list-inside ml-2 space-y-1">
                <li>Open Outlook</li>
                <li>Go to File → Open & Export → Import/Export</li>
                <li>Select "Import an iCalendar (.ics) file"</li>
                <li>Browse to the downloaded file</li>
              </ol>
            </div>
            <div>
              <p className="font-semibold mb-1">Google Calendar:</p>
              <ol className="list-decimal list-inside ml-2 space-y-1">
                <li>Open Google Calendar</li>
                <li>Click the gear icon → Settings</li>
                <li>Select "Import & Export" from the left menu</li>
                <li>Click "Select file from your computer"</li>
                <li>Choose the downloaded .ics file</li>
              </ol>
            </div>
            <div>
              <p className="font-semibold mb-1">Apple Calendar:</p>
              <ol className="list-decimal list-inside ml-2 space-y-1">
                <li>Open Calendar app</li>
                <li>Go to File → Import</li>
                <li>Select the downloaded .ics file</li>
              </ol>
            </div>
          </div>
          </Accordion.Panel>
        </Accordion.Item>

        <Accordion.Item value="csv">
          <Accordion.Control>
            <span className={`font-medium ${isDarkMode ? 'text-gray-100' : 'text-gray-900'}`}>📊 How to open CSV files</span>
          </Accordion.Control>
          <Accordion.Panel>
          <div className={`p-4 text-sm space-y-4 ${isDarkMode ? 'text-gray-300' : 'text-gray-700'}`}>
            <div>
              <p className="font-semibold mb-1">Microsoft Excel:</p>
              <ol className="list-decimal list-inside ml-2 space-y-1">
                <li>Open Excel</li>
                <li>Go to File → Open</li>
                <li>Select the downloaded .csv file</li>
              </ol>
            </div>
            <div>
              <p className="font-semibold mb-1">Google Sheets:</p>
              <ol className="list-decimal list-inside ml-2 space-y-1">
                <li>Open Google Sheets</li>
                <li>Go to File → Import</li>
                <li>Upload the .csv file</li>
              </ol>
            </div>
            <div>
              <p className="font-semibold mb-1">Double-click:</p>
              <p className="ml-2">Most systems will open CSV files in your default spreadsheet app</p>
            </div>
          </div>
          </Accordion.Panel>
        </Accordion.Item>
      </Accordion>
    </div>
  );
};