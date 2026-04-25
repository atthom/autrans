import axios from 'axios';
import type { ScheduleRequest, ScheduleResponse, FailureResponse } from '../types';

// Get API URL from environment variable or use default
// In development: uses Vite proxy (empty string)
// In production/mobile: uses VITE_API_URL environment variable
const getBaseURL = () => {
  // If VITE_API_URL is set, use it (for production/mobile)
  if (import.meta.env.VITE_API_URL) {
    return import.meta.env.VITE_API_URL;
  }
  // Otherwise use empty string (for local dev with proxy)
  return '';
};

const api = axios.create({
  baseURL: getBaseURL(),
  headers: {
    'Content-Type': 'application/json',
  },
});

export const scheduleApi = {
  /**
   * Generate a schedule
   */
  async generateSchedule(request: ScheduleRequest): Promise<ScheduleResponse> {
    const response = await api.post<ScheduleResponse>('/schedule', request);
    return response.data;
  },

  /**
   * Export schedule as iCalendar
   */
  async exportICS(request: {
    workers: Array<[string, number[], number[], number]>;
    tasks: Array<[string, number, number, ...number[]]>;
    nb_days: number;
    balance_daysoff: boolean;
    start_date: string;
    trip_name: string;
  }): Promise<Blob> {
    const response = await api.post('/export/ics', request, {
      responseType: 'blob',
    });
    return response.data;
  },

  /**
   * Export schedule as CSV
   */
  async exportCSV(request: {
    workers: Array<[string, number[], number[], number]>;
    tasks: Array<[string, number, number, ...number[]]>;
    nb_days: number;
    balance_daysoff: boolean;
    start_date: string;
    trip_name: string;
  }): Promise<Blob> {
    const response = await api.post('/export/csv', request, {
      responseType: 'blob',
    });
    return response.data;
  },
};

// Error handling helper
export function isFailureResponse(error: any): error is { response: { data: FailureResponse } } {
  return error.response?.data?.msg !== undefined;
}

export default api;