import React from 'react';

interface CardProps {
  children: React.ReactNode;
  title?: string;
  className?: string;
  expanded?: boolean;
  onToggle?: () => void;
}

export const Card: React.FC<CardProps> = ({
  children,
  title,
  className = '',
  expanded,
  onToggle,
}) => {
  const isCollapsible = expanded !== undefined && onToggle !== undefined;

  return (
    <div className={`bg-white dark:bg-gray-800 rounded-lg shadow-md border border-gray-200 dark:border-gray-700 ${className}`}>
      {title && (
        <div
          className={`px-4 py-3 border-b border-gray-200 dark:border-gray-700 font-semibold text-gray-800 dark:text-gray-100 ${
            isCollapsible ? 'cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-700 flex items-center justify-between' : ''
          }`}
          onClick={isCollapsible ? onToggle : undefined}
        >
          <span>{title}</span>
          {isCollapsible && (
            <span className="text-gray-500 dark:text-gray-400">
              {expanded ? '▼' : '▶'}
            </span>
          )}
        </div>
      )}
      {(!isCollapsible || expanded) && (
        <div className="p-4">{children}</div>
      )}
    </div>
  );
};

interface SectionHeaderProps {
  icon?: string;
  title: string;
  description?: string;
}

export const SectionHeader: React.FC<SectionHeaderProps> = ({
  icon,
  title,
  description,
}) => {
  return (
    <div className="bg-primary-500 dark:bg-primary-600 text-white rounded-lg px-6 py-4 mb-6">
      <div className="flex items-center gap-2">
        {icon && <span className="text-2xl">{icon}</span>}
        <h2 className="text-2xl font-bold">{title}</h2>
      </div>
      {description && (
        <p className="mt-1 text-primary-100 dark:text-primary-200">{description}</p>
      )}
    </div>
  );
};
