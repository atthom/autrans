import axios from 'axios';
import type { ScheduleRequest, ScheduleResponse, FailureResponse } from '../types';

const api = axios.create({
  baseURL: import.meta.env.DEV ? '' : '', // Proxy handles this in dev, same origin in prod
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