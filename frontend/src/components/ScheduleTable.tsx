import React, { useMemo } from 'react';
import {
  useReactTable,
  getCoreRowModel,
  flexRender,
  type ColumnDef,
} from '@tanstack/react-table';
import { parseTableData, getDayLabel } from '../utils/helpers';
import type { ScheduleResponse } from '../types';

interface ScheduleTableProps {
  scheduleData: ScheduleResponse['display'];
  colors?: string[];
  startDate: string;
  numDays: number;
  displayDaysAs: 'numbers' | 'dayOfWeek';
  isDarkMode?: boolean;
}

type ScheduleRow = {
  task: string;
  [key: string]: string;
};

export const ScheduleTable: React.FC<ScheduleTableProps> = ({ 
  scheduleData, 
  colors = [],
  startDate,
  numDays,
  displayDaysAs,
  isDarkMode = false
}) => {
  const { headers, rows } = parseTableData(scheduleData);

  // Transform day headers based on display mode
  const transformedHeaders = useMemo(() => {
    return headers.map((header, index) => {
      if (index === 0) return header; // Keep first column (task names) as is
      
      // Extract day number from header (e.g., "Day 1" -> 1)
      const dayMatch = header.match(/Day (\d+)/);
      if (dayMatch) {
        const dayNum = parseInt(dayMatch[1]);
        return getDayLabel(dayNum, startDate, displayDaysAs, numDays);
      }
      return header;
    });
  }, [headers, startDate, displayDaysAs, numDays]);

  // Transform data for TanStack Table
  const data = useMemo(() => {
    return rows.map((row) => {
      const rowData: ScheduleRow = { task: row[0] || '' };
      headers.slice(1).forEach((header, i) => {
        rowData[header] = row[i + 1] || '';
      });
      return rowData;
    });
  }, [rows, headers]);

  // Define columns
  const columns = useMemo<ColumnDef<ScheduleRow>[]>(() => {
    const cols: ColumnDef<ScheduleRow>[] = [
      {
        accessorKey: 'task',
        header: transformedHeaders[0],
        size: 150,
        minSize: 120,
        maxSize: 200,
      },
    ];

    headers.slice(1).forEach((header, i) => {
      cols.push({
        accessorKey: header,
        header: transformedHeaders[i + 1],
        size: 120,
      });
    });

    return cols;
  }, [headers, transformedHeaders]);

  const table = useReactTable({
    data,
    columns,
    getCoreRowModel: getCoreRowModel(),
  });

  return (
    <div className="overflow-x-auto">
      <table className="w-full border-collapse">
        <thead>
          {table.getHeaderGroups().map((headerGroup) => (
            <tr key={headerGroup.id} className={isDarkMode ? 'bg-gray-700' : 'bg-gray-200'}>
              {headerGroup.headers.map((header, index) => (
                <th
                  key={header.id}
                  className={`border px-3 py-3 text-left font-semibold ${
                    isDarkMode ? 'border-gray-600 text-gray-100' : 'border-gray-300 text-gray-800'
                  } ${
                    index === 0 ? `sticky left-0 z-10 ${isDarkMode ? 'bg-gray-700' : 'bg-gray-200'}` : ''
                  }`}
                  style={{
                    width: index === 0 ? '150px' : 'auto',
                    maxWidth: index === 0 ? '150px' : 'none',
                  }}
                >
                  {flexRender(header.column.columnDef.header, header.getContext())}
                </th>
              ))}
            </tr>
          ))}
        </thead>
        <tbody>
          {table.getRowModel().rows.map((row, rowIndex) => (
            <tr
              key={row.id}
              className={`transition-colors ${isDarkMode ? 'hover:bg-gray-700' : 'hover:bg-gray-100'}`}
              style={colors[rowIndex] ? { backgroundColor: colors[rowIndex] + '40' } : undefined}
            >
              {row.getVisibleCells().map((cell, cellIndex) => (
                <td
                  key={cell.id}
                  className={`border px-3 py-2 ${
                    isDarkMode ? 'border-gray-600 text-gray-100' : 'border-gray-300'
                  } ${
                    cellIndex === 0
                      ? 'font-semibold sticky left-0 z-10 whitespace-normal break-words'
                      : 'whitespace-pre-wrap text-center'
                  }`}
                  style={
                    cellIndex === 0
                      ? {
                          backgroundColor: colors[rowIndex] ? colors[rowIndex] + '40' : undefined,
                          width: '150px',
                          maxWidth: '150px',
                        }
                      : undefined
                  }
                >
                  {flexRender(cell.column.columnDef.cell, cell.getContext()) || '-'}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};

interface AuditTableProps {
  data: {
    columns: string[][];
    colindex: { names: string[] };
  };
  title: string;
  isDarkMode?: boolean;
}

type AuditRow = {
  [key: string]: string;
};

export const AuditTable: React.FC<AuditTableProps> = ({ data, title, isDarkMode = false }) => {
  const { headers, rows } = parseTableData(data);

  // Transform data for TanStack Table
  const tableData = useMemo(() => {
    return rows.map((row) => {
      const rowData: AuditRow = {};
      headers.forEach((header, i) => {
        rowData[header] = row[i] || '';
      });
      return rowData;
    });
  }, [rows, headers]);

  // Define columns
  const columns = useMemo<ColumnDef<AuditRow>[]>(() => {
    return headers.map((header, index) => ({
      accessorKey: header,
      header: header,
      size: index === 0 ? 100 : 80,
      minSize: index === 0 ? 80 : 60,
      maxSize: index === 0 ? 120 : 100,
    }));
  }, [headers]);

  const table = useReactTable({
    data: tableData,
    columns,
    getCoreRowModel: getCoreRowModel(),
  });

  return (
    <div className="mb-8">
      <h3 className={`text-lg font-semibold mb-3 ${isDarkMode ? 'text-gray-100' : 'text-gray-800'}`}>{title}</h3>
      <div className="overflow-x-auto">
        <table className="w-full border-collapse">
          <thead>
            {table.getHeaderGroups().map((headerGroup) => (
              <tr key={headerGroup.id} className={isDarkMode ? 'bg-gray-700' : 'bg-gray-200'}>
                {headerGroup.headers.map((header, index) => (
                  <th
                    key={header.id}
                    className={`border px-2 py-2 text-center font-semibold text-sm ${
                      isDarkMode ? 'border-gray-600 text-gray-100' : 'border-gray-300 text-gray-800'
                    }`}
                    style={{
                      width: index === 0 ? '100px' : 'auto',
                      maxWidth: index === 0 ? '100px' : 'none',
                    }}
                  >
                    {flexRender(header.column.columnDef.header, header.getContext())}
                  </th>
                ))}
              </tr>
            ))}
          </thead>
          <tbody>
            {table.getRowModel().rows.map((row, rowIndex) => (
              <tr
                key={row.id}
                className={`transition-colors ${
                  isDarkMode ? 'hover:bg-gray-700' : 'hover:bg-gray-100'
                } ${
                  rowIndex % 2 === 0 
                    ? (isDarkMode ? 'bg-gray-800' : 'bg-white')
                    : (isDarkMode ? 'bg-gray-800/50' : 'bg-gray-50')
                }`}
              >
                {row.getVisibleCells().map((cell, cellIndex) => (
                  <td
                    key={cell.id}
                    className={`border px-2 py-1 text-center text-sm ${
                      isDarkMode ? 'border-gray-600 text-gray-100' : 'border-gray-300'
                    } ${
                      cellIndex === 0 ? 'font-semibold whitespace-normal break-words text-left' : ''
                    }`}
                    style={
                      cellIndex === 0
                        ? {
                            width: '100px',
                            maxWidth: '100px',
                          }
                        : undefined
                    }
                  >
                    {flexRender(cell.column.columnDef.cell, cell.getContext()) || '-'}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      
      {/* Legend */}
      <div className={`mt-2 text-sm ${isDarkMode ? 'text-gray-300' : 'text-gray-600'}`}>
        <p><strong>*</strong> = Worker had a day off during this period</p>
        <p>Format: <strong>count (difficulty pts)</strong> - Shows task count and total difficulty points</p>
      </div>
    </div>
  );
};