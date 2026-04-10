import React, { useState } from 'react';
import { Textarea } from '@mantine/core';
import { Button } from './common';
import { encodeState, decodeState } from '../utils/helpers';
import type { AppState } from '../types';

interface StateManagerProps {
  currentState: AppState;
  onLoadState: (state: AppState) => void;
  isDarkMode: boolean;
}

export const StateManager: React.FC<StateManagerProps> = ({ currentState, onLoadState, isDarkMode }) => {
  const [stateCode, setStateCode] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const handleGenerateState = () => {
    try {
      // Clear input first
      setStateCode('');
      
      // Exclude runtime-only data
      const stateToSave = {
        tripName: currentState.tripName,
        startDate: currentState.startDate,
        numDays: currentState.numDays,
        tasks: currentState.tasks,
        workers: currentState.workers,
        constraints: currentState.constraints,
        balanceDaysOff: currentState.balanceDaysOff,
      };

      const encoded = encodeState(stateToSave);
      setStateCode(encoded);
      setSuccess('State code generated!');
      setError(null);
      
      // Auto-hide success message
      setTimeout(() => setSuccess(null), 2000);
    } catch (err) {
      setError('Failed to generate state code');
      setSuccess(null);
    }
  };

  const handleLoadState = () => {
    if (!stateCode.trim()) {
      setError('Please paste or generate a state code first');
      return;
    }

    try {
      const decoded = decodeState(stateCode.trim());
      
      // Validate the decoded state has required fields
      if (!decoded.tripName || !decoded.startDate || !decoded.numDays) {
        throw new Error('Invalid state code: missing required fields');
      }

      onLoadState(decoded);
      setSuccess('State loaded successfully!');
      setError(null);
      setStateCode('');
      
      // Auto-hide success message
      setTimeout(() => setSuccess(null), 2000);
    } catch (err: any) {
      setError(err.message || 'Invalid state code');
      setSuccess(null);
    }
  };

  const handleCopyToClipboard = async () => {
    if (!stateCode.trim()) {
      setError('No state code to copy');
      return;
    }
    
    try {
      await navigator.clipboard.writeText(stateCode);
      setSuccess('Copied to clipboard!');
      setTimeout(() => setSuccess(null), 2000);
    } catch (err) {
      setError('Failed to copy to clipboard');
    }
  };

  return (
    <div className="space-y-4">
      {error && (
        <div className={`p-3 rounded text-sm border ${
          isDarkMode 
            ? 'bg-red-900/30 border-red-700 text-red-200' 
            : 'bg-red-50 border-red-200 text-red-800'
        }`}>
          {error}
        </div>
      )}

      {success && (
        <div className={`p-3 rounded text-sm border ${
          isDarkMode 
            ? 'bg-green-900/30 border-green-700 text-green-200' 
            : 'bg-green-50 border-green-200 text-green-800'
        }`}>
          {success}
        </div>
      )}

      <Textarea
        value={stateCode}
        onChange={(e) => setStateCode(e.target.value)}
        placeholder="Paste state code here or generate one..."
        rows={3}
        classNames={{ input: 'font-mono text-xs' }}
      />

      <div className="flex gap-2">
        <Button onClick={handleGenerateState} variant="secondary" size="sm" isDarkMode={isDarkMode}>
          Generate
        </Button>
        <Button onClick={handleLoadState} disabled={!stateCode.trim()} size="sm" isDarkMode={isDarkMode}>
          Load
        </Button>
        <Button onClick={handleCopyToClipboard} disabled={!stateCode.trim()} variant="secondary" size="sm" isDarkMode={isDarkMode}>
          Copy
        </Button>
      </div>
    </div>
  );
};