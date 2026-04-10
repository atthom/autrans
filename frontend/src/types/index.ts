// API Types matching the Julia backend

export interface Task {
  name: string;
  num_workers: number;
  difficulty: number;
  selected_days: number[];  // Array of selected day numbers (e.g., [1, 3, 5, 7])
  color?: string;
}

export interface Worker {
  name: string;
  days_off: number[];
  task_preferences: number[];
  workload_offset: number;
}

export interface Constraint {
  name: string;
  enabled: boolean;
  type: 'hard' | 'soft';
  description: string;
}

export interface ScheduleRequest {
  workers: Array<[string, number[], number[], number]>;
  tasks: Array<[string, number, number, ...number[]]>;  // [name, num_workers, difficulty, ...selected_days]
  nb_days: number;
  task_per_day: string[];
  balance_daysoff: boolean;
  hard_constraints: string[];
  soft_constraints: string[];
}

export interface ScheduleResponse {
  display: {
    columns: string[][];
    colindex: {
      names: string[];
    };
  };
  time: {
    columns: string[][];
    colindex: {
      names: string[];
    };
  };
  jobs: {
    columns: string[][];
    colindex: {
      names: string[];
    };
  };
  capacity_analysis?: {
    num_days: number;
    num_workers: number;
    num_tasks: number;
    total_slots: number;
    utilization_percent: number;
    daily_breakdown: Array<{
      day: number;
      slots_needed: number;
      workers_available: number;
      workers_off: string[];
    }>;
  };
}

export interface FailureResponse {
  msg: string;
  details?: {
    capacity?: any;
    constraints?: string[];
    conflict_analysis?: string[];
    failed_level?: number;
  };
}

export interface AppState {
  tripName: string;
  startDate: string;
  numDays: number;
  tasks: Task[];
  workers: Worker[];
  constraints: Constraint[];
  balanceDaysOff: boolean;
  displayDaysAs: 'numbers' | 'dayOfWeek';
}
