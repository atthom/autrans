/**
 * Utility functions for the Autrans application
 */

/**
 * Calculate Euclidean distance between two RGB colors
 */
const colorDistance = (color1: string, color2: string): number => {
  const r1 = parseInt(color1.slice(1, 3), 16);
  const g1 = parseInt(color1.slice(3, 5), 16);
  const b1 = parseInt(color1.slice(5, 7), 16);
  
  const r2 = parseInt(color2.slice(1, 3), 16);
  const g2 = parseInt(color2.slice(3, 5), 16);
  const b2 = parseInt(color2.slice(5, 7), 16);
  
  return Math.sqrt(
    Math.pow(r1 - r2, 2) +
    Math.pow(g1 - g2, 2) +
    Math.pow(b1 - b2, 2)
  );
};

/**
 * Generate a random pastel color (legacy function, kept for backward compatibility)
 */
export const generatePastelColor = (): string => {
  const r = Math.floor(Math.random() * 128 + 127);
  const g = Math.floor(Math.random() * 128 + 127);
  const b = Math.floor(Math.random() * 128 + 127);
  return `#${r.toString(16).padStart(2, '0')}${g.toString(16).padStart(2, '0')}${b.toString(16).padStart(2, '0')}`;
};

/**
 * Generate a distinct pastel color that's far from existing colors
 * Distance requirement decreases as more colors are added
 * When threshold drops to 30 or below, distance checking is disabled
 * 
 * @param existingColors - Array of existing color hex strings
 * @returns A new distinct pastel color
 */
export const generateDistinctPastelColor = (existingColors: string[] = []): string => {
  const baseDistance = 120;
  const decreaseRate = 5;
  const disableThreshold = 30;
  
  // Calculate required distance
  const requiredDistance = baseDistance - (existingColors.length * decreaseRate);
  
  // Generate simple random color (helper function)
  const generateRandomPastelColor = () => {
    const r = Math.floor(Math.random() * 128 + 127);
    const g = Math.floor(Math.random() * 128 + 127);
    const b = Math.floor(Math.random() * 128 + 127);
    return `#${r.toString(16).padStart(2, '0')}${g.toString(16).padStart(2, '0')}${b.toString(16).padStart(2, '0')}`;
  };
  
  // If no existing colors or threshold disabled, return random color
  if (existingColors.length === 0 || requiredDistance <= disableThreshold) {
    return generateRandomPastelColor();
  }
  
  // Try to find a color that meets the distance requirement
  const MAX_ATTEMPTS = 100;
  let bestColor = '';
  let bestMinDistance = 0;
  
  for (let attempt = 0; attempt < MAX_ATTEMPTS; attempt++) {
    const color = generateRandomPastelColor();
    
    // Find MINIMUM distance to ANY existing color
    const minDistanceToExisting = Math.min(
      ...existingColors.map(existing => colorDistance(color, existing))
    );
    
    // If this color is far enough from ALL colors, use it
    if (minDistanceToExisting >= requiredDistance) {
      return color;
    }
    
    // Track the best candidate (farthest from all existing colors)
    if (minDistanceToExisting > bestMinDistance) {
      bestMinDistance = minDistanceToExisting;
      bestColor = color;
    }
  }
  
  // Return best candidate found
  return bestColor;
};

/**
 * Format a date as YYYY-MM-DD
 */
export const formatDate = (date: Date): string => {
  return date.toISOString().split('T')[0];
};

/**
 * Parse a date string (YYYY-MM-DD) to Date object
 */
export const parseDate = (dateString: string): Date => {
  return new Date(dateString + 'T00:00:00');
};

/**
 * Get day name from date
 */
export const getDayName = (date: Date): string => {
  return date.toLocaleDateString('en-US', { weekday: 'long' });
};

/**
 * Get formatted date string (DD/MM/YYYY)
 */
export const getFormattedDate = (date: Date): string => {
  return date.toLocaleDateString('en-GB');
};

/**
 * Generate array of dates from start date and number of days
 */
export const generateDateRange = (startDate: string, numDays: number): Date[] => {
  const dates: Date[] = [];
  const start = parseDate(startDate);
  
  for (let i = 0; i < numDays; i++) {
    const date = new Date(start);
    date.setDate(start.getDate() + i);
    dates.push(date);
  }
  
  return dates;
};

/**
 * Get week number relative to start date
 */
export const getWeekNumber = (date: Date, startDate: Date): number => {
  const diffTime = date.getTime() - startDate.getTime();
  const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24));
  return Math.floor(diffDays / 7);
};

/**
 * Generate day labels with week numbers
 */
export const generateDayLabels = (startDate: string, numDays: number): string[] => {
  const dates = generateDateRange(startDate, numDays);
  const start = parseDate(startDate);
  
  return dates.map((date) => {
    const dayName = getDayName(date);
    const weekNum = getWeekNumber(date, start);
    
    if (weekNum > 0) {
      return `${dayName} (W ${weekNum + 1})`;
    }
    return dayName;
  });
};

/**
 * Compress and encode state to base64
 */
export const encodeState = (state: any): string => {
  const json = JSON.stringify(state);
  // Simple base64 encoding (browser-compatible)
  return btoa(encodeURIComponent(json));
};

/**
 * Decode and decompress state from base64
 */
export const decodeState = (encoded: string): any => {
  try {
    const json = decodeURIComponent(atob(encoded));
    return JSON.parse(json);
  } catch (error) {
    throw new Error('Invalid state code');
  }
};

/**
 * Download a file from blob data
 */
export const downloadFile = (blob: Blob, filename: string) => {
  const url = window.URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  window.URL.revokeObjectURL(url);
};

/**
 * Generate filename for exports
 */
export const generateExportFilename = (
  tripName: string,
  startDate: string,
  numDays: number,
  extension: string
): string => {
  const safeTripName = tripName.replace(/[^a-zA-Z0-9]/g, '_');
  return `Schedule-${safeTripName}-${startDate}-${numDays}days.${extension}`;
};

/**
 * Validate that a schedule is feasible (basic capacity check)
 */
export const validateCapacity = (
  numTasks: number,
  avgWorkersPerTask: number,
  numDays: number,
  numWorkers: number,
  avgDaysOff: number
): { feasible: boolean; message?: string } => {
  const totalSlots = numTasks * avgWorkersPerTask * numDays;
  const avgWorkingDays = numDays - avgDaysOff;
  const totalCapacity = numWorkers * avgWorkingDays;
  
  if (totalSlots > totalCapacity) {
    return {
      feasible: false,
      message: `Not enough capacity: ${totalSlots} slots needed but only ${totalCapacity} available`,
    };
  }
  
  return { feasible: true };
};

/**
 * Parse table data from backend response
 */
export const parseTableData = (response: {
  columns: string[][];
  colindex: { names: string[] };
}): { headers: string[]; rows: string[][] } => {
  const headers = response.colindex.names;
  const rows = response.columns[0].map((_, rowIndex) =>
    response.columns.map((col) => col[rowIndex])
  );
  
  return { headers, rows };
};

/**
 * Get the display label for a day based on the display mode
 * @param dayNum - Day number (1-based)
 * @param startDate - Start date in YYYY-MM-DD format
 * @param displayMode - Display mode ('numbers' or 'dayOfWeek')
 * @param totalDays - Total number of days in the schedule
 * @returns The formatted day label
 */
export const getDayLabel = (
  dayNum: number,
  startDate: string,
  displayMode: 'numbers' | 'dayOfWeek',
  totalDays: number
): string => {
  if (displayMode === 'numbers') {
    return `Day ${dayNum}`;
  }

  // Parse start date and calculate the actual date for this day
  const date = parseDate(startDate);
  date.setDate(date.getDate() + dayNum - 1);

  // Get day of week abbreviation
  const dayName = date.toLocaleDateString('en-US', { weekday: 'short' });

  // Calculate week number (1-based)
  const weekNum = Math.floor((dayNum - 1) / 7) + 1;

  // Show week number if schedule is longer than 7 days
  if (totalDays > 7) {
    return `${dayName} (W${weekNum})`;
  }

  return dayName;
};
