import React from 'react';
import {
  DndContext,
  closestCenter,
  KeyboardSensor,
  PointerSensor,
  useSensor,
  useSensors,
} from '@dnd-kit/core';
import type { DragEndEvent } from '@dnd-kit/core';
import {
  arrayMove,
  SortableContext,
  sortableKeyboardCoordinates,
  useSortable,
  verticalListSortingStrategy,
} from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';
import { Tooltip } from '@mantine/core';
import { Button } from './common';
import type { Constraint } from '../types';

interface ConstraintsManagerProps {
  constraints: Constraint[];
  onChange: (constraints: Constraint[]) => void;
  isDarkMode: boolean;
}

const CONSTRAINT_DESCRIPTIONS: Record<string, string> = {
  'Task Coverage': 'Each task must have the required number of workers',
  'No Consecutive Tasks': 'Workers do at most one task per day',
  'Days Off': 'Workers cannot work on their days off',
  'Overall Equity': 'Fair distribution of total workload',
  'Daily Equity': 'Similar amount of work per day',
  'Task Diversity': 'Everyone participates in each task',
  'Worker Preference': 'Respect worker task preferences',
  'One Task Per Day': 'Workers can do at most 1 task per day (stricter than No Consecutive Tasks)',
};

interface SortableConstraintItemProps {
  constraint: Constraint;
  onStatusChange: (status: 'Hard' | 'Soft' | 'Off') => void;
  isDarkMode: boolean;
}

const SortableConstraintItem: React.FC<SortableConstraintItemProps> = ({
  constraint,
  onStatusChange,
  isDarkMode,
}) => {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id: constraint.name });

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.5 : 1,
  };

  const currentStatus = !constraint.enabled
    ? 'Off'
    : constraint.type === 'hard'
    ? 'Hard'
    : 'Soft';

  return (
    <div
      ref={setNodeRef}
      style={style}
      className={`grid grid-cols-12 gap-2 items-center p-2 rounded ${
        isDarkMode ? 'bg-gray-700' : 'bg-gray-50'
      } ${isDragging ? 'shadow-lg z-50' : ''}`}
    >
      {/* Drag handle */}
      <div className="col-span-1 flex justify-center">
        <button
          {...attributes}
          {...listeners}
          className="cursor-grab active:cursor-grabbing text-gray-400 hover:text-gray-600 px-1"
          title="Drag to reorder"
        >
          <svg
            width="16"
            height="16"
            viewBox="0 0 16 16"
            fill="currentColor"
            xmlns="http://www.w3.org/2000/svg"
          >
            <circle cx="6" cy="4" r="1.5" />
            <circle cx="10" cy="4" r="1.5" />
            <circle cx="6" cy="8" r="1.5" />
            <circle cx="10" cy="8" r="1.5" />
            <circle cx="6" cy="12" r="1.5" />
            <circle cx="10" cy="12" r="1.5" />
          </svg>
        </button>
      </div>

      {/* Constraint name with tooltip */}
      <div className="col-span-5">
        <Tooltip
          label={constraint.description || CONSTRAINT_DESCRIPTIONS[constraint.name]}
          position="top"
          withArrow
        >
          <span className={`font-medium cursor-help ${isDarkMode ? 'text-gray-100' : 'text-gray-900'} ${!constraint.enabled ? 'opacity-50 line-through' : ''}`}>
            {constraint.name}
          </span>
        </Tooltip>
      </div>

      {/* Status buttons */}
      <div className="col-span-6 flex gap-2">
        <Button
          size="sm"
          variant={currentStatus === 'Hard' ? 'primary' : 'secondary'}
          onClick={() => onStatusChange('Hard')}
          className="flex-1"
          isDarkMode={isDarkMode}
        >
          Hard
        </Button>
        <Button
          size="sm"
          variant={currentStatus === 'Soft' ? 'primary' : 'secondary'}
          onClick={() => onStatusChange('Soft')}
          className="flex-1"
          isDarkMode={isDarkMode}
        >
          Soft
        </Button>
        <Button
          size="sm"
          variant={currentStatus === 'Off' ? 'danger' : 'secondary'}
          onClick={() => onStatusChange('Off')}
          className="flex-1"
          isDarkMode={isDarkMode}
        >
          Off
        </Button>
      </div>
    </div>
  );
};

export const ConstraintsManager: React.FC<ConstraintsManagerProps> = ({
  constraints,
  onChange,
  isDarkMode,
}) => {
  const sensors = useSensors(
    useSensor(PointerSensor),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    })
  );

  // Group constraints by status
  const hardConstraints = constraints.filter(c => c.enabled && c.type === 'hard');
  const softConstraints = constraints.filter(c => c.enabled && c.type === 'soft');
  const offConstraints = constraints.filter(c => !c.enabled);

  const updateConstraint = (constraintName: string, updates: Partial<Constraint>) => {
    const index = constraints.findIndex(c => c.name === constraintName);
    if (index === -1) return;

    const newConstraints = [...constraints];
    newConstraints[index] = { ...newConstraints[index], ...updates };
    
    // Auto-sort: group by status (Hard, Soft, Off)
    const sorted = [
      ...newConstraints.filter(c => c.enabled && c.type === 'hard'),
      ...newConstraints.filter(c => c.enabled && c.type === 'soft'),
      ...newConstraints.filter(c => !c.enabled),
    ];
    
    onChange(sorted);
  };

  const handleStatusChange = (constraintName: string, status: 'Hard' | 'Soft' | 'Off') => {
    if (status === 'Off') {
      updateConstraint(constraintName, { enabled: false });
    } else {
      updateConstraint(constraintName, { enabled: true, type: status.toLowerCase() as 'hard' | 'soft' });
    }
  };

  const handleDragEnd = (event: DragEndEvent) => {
    const { active, over } = event;

    if (over && active.id !== over.id) {
      // Only allow reordering within soft constraints
      const oldIndex = softConstraints.findIndex(c => c.name === active.id);
      const newIndex = softConstraints.findIndex(c => c.name === over.id);

      if (oldIndex !== -1 && newIndex !== -1) {
        const reorderedSoft = arrayMove(softConstraints, oldIndex, newIndex);
        
        // Rebuild full list: Hard + reordered Soft + Off
        const newConstraints = [
          ...hardConstraints,
          ...reorderedSoft,
          ...offConstraints,
        ];
        
        onChange(newConstraints);
      }
    }
  };

  // Render a non-sortable constraint item
  const renderFixedItem = (constraint: Constraint) => {
    const currentStatus = !constraint.enabled
      ? 'Off'
      : constraint.type === 'hard'
      ? 'Hard'
      : 'Soft';

    return (
      <div
        key={constraint.name}
        className={`grid grid-cols-12 gap-2 items-center p-2 rounded ${isDarkMode ? 'bg-gray-700' : 'bg-gray-50'}`}
      >
        {/* No drag handle for fixed items */}
        <div className="col-span-1"></div>

        {/* Constraint name with tooltip */}
        <div className="col-span-5">
          <Tooltip
            label={constraint.description || CONSTRAINT_DESCRIPTIONS[constraint.name]}
            position="top"
            withArrow
          >
            <span className={`font-medium cursor-help ${isDarkMode ? 'text-gray-100' : 'text-gray-900'} ${!constraint.enabled ? 'opacity-50 line-through' : ''}`}>
              {constraint.name}
            </span>
          </Tooltip>
        </div>

        {/* Status buttons */}
        <div className="col-span-6 flex gap-2">
          <Button
            size="sm"
            variant={currentStatus === 'Hard' ? 'primary' : 'secondary'}
            onClick={() => handleStatusChange(constraint.name, 'Hard')}
            className="flex-1"
            isDarkMode={isDarkMode}
          >
            Hard
          </Button>
          <Button
            size="sm"
            variant={currentStatus === 'Soft' ? 'primary' : 'secondary'}
            onClick={() => handleStatusChange(constraint.name, 'Soft')}
            className="flex-1"
            isDarkMode={isDarkMode}
          >
            Soft
          </Button>
          <Button
            size="sm"
            variant={currentStatus === 'Off' ? 'danger' : 'secondary'}
            onClick={() => handleStatusChange(constraint.name, 'Off')}
            className="flex-1"
            isDarkMode={isDarkMode}
          >
            Off
          </Button>
        </div>
      </div>
    );
  };

  return (
    <div className="space-y-6">
      {/* Hard Constraints Section */}
      {hardConstraints.length > 0 && (
        <div>
          <div className="flex items-center gap-2 mb-3">
            <div className={`flex-1 h-px ${isDarkMode ? 'bg-gray-600' : 'bg-gray-300'}`}></div>
            <span className={`text-sm font-semibold px-2 ${isDarkMode ? 'text-gray-300' : 'text-gray-600'}`}>Hard Constraints (Must be satisfied)</span>
            <div className={`flex-1 h-px ${isDarkMode ? 'bg-gray-600' : 'bg-gray-300'}`}></div>
          </div>
          <div className="space-y-2">
            {hardConstraints.map(constraint => renderFixedItem(constraint))}
          </div>
        </div>
      )}

      {/* Soft Constraints Section - Sortable */}
      {softConstraints.length > 0 && (
        <div>
          <div className="flex items-center gap-2 mb-3">
            <div className={`flex-1 h-px ${isDarkMode ? 'bg-gray-600' : 'bg-gray-300'}`}></div>
            <span className={`text-sm font-semibold px-2 ${isDarkMode ? 'text-gray-300' : 'text-gray-600'}`}>Soft Constraints (Sort by importance)</span>
            <div className={`flex-1 h-px ${isDarkMode ? 'bg-gray-600' : 'bg-gray-300'}`}></div>
          </div>
          <DndContext
            sensors={sensors}
            collisionDetection={closestCenter}
            onDragEnd={handleDragEnd}
          >
            <SortableContext
              items={softConstraints.map(c => c.name)}
              strategy={verticalListSortingStrategy}
            >
              <div className="space-y-2">
                {softConstraints.map((constraint) => (
                  <SortableConstraintItem
                    key={constraint.name}
                    constraint={constraint}
                    onStatusChange={(status) => handleStatusChange(constraint.name, status)}
                    isDarkMode={isDarkMode}
                  />
                ))}
              </div>
            </SortableContext>
          </DndContext>
        </div>
      )}

      {/* Off Constraints Section */}
      {offConstraints.length > 0 && (
        <div>
          <div className="flex items-center gap-2 mb-3">
            <div className={`flex-1 h-px ${isDarkMode ? 'bg-gray-600' : 'bg-gray-300'}`}></div>
            <span className={`text-sm font-semibold px-2 ${isDarkMode ? 'text-gray-300' : 'text-gray-600'}`}>Disabled Constraints (Not in use)</span>
            <div className={`flex-1 h-px ${isDarkMode ? 'bg-gray-600' : 'bg-gray-300'}`}></div>
          </div>
          <div className="space-y-2">
            {offConstraints.map(constraint => renderFixedItem(constraint))}
          </div>
        </div>
      )}
    </div>
  );
};
