import React from 'react';

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'danger';
  size?: 'sm' | 'md' | 'lg';
  icon?: React.ReactNode;
  children: React.ReactNode;
  isDarkMode?: boolean;
}

export const Button: React.FC<ButtonProps> = ({
  variant = 'primary',
  size = 'md',
  icon,
  children,
  className = '',
  disabled,
  isDarkMode = false,
  ...props
}) => {
  const baseStyles = 'font-medium rounded-lg transition-colors duration-200 flex items-center justify-center gap-2';
  
  const getVariantStyles = () => {
    if (variant === 'primary') {
      return `${isDarkMode ? 'bg-primary-600 hover:bg-primary-700' : 'bg-primary-500 hover:bg-primary-600'} text-white ${disabled ? (isDarkMode ? 'bg-gray-600' : 'bg-gray-300') : ''} disabled:cursor-not-allowed`;
    }
    if (variant === 'secondary') {
      return `${isDarkMode ? 'bg-gray-600 hover:bg-gray-500 text-gray-100' : 'bg-gray-200 hover:bg-gray-300 text-gray-800'} ${disabled ? (isDarkMode ? 'bg-gray-700' : 'bg-gray-100') : ''} disabled:cursor-not-allowed`;
    }
    if (variant === 'danger') {
      return `${isDarkMode ? 'bg-rose-600 hover:bg-rose-700' : 'bg-rose-400 hover:bg-rose-500'} text-white ${disabled ? (isDarkMode ? 'bg-gray-600' : 'bg-gray-300') : ''} disabled:cursor-not-allowed`;
    }
    return '';
  };
  
  const sizeStyles = {
    sm: 'px-3 py-1.5 text-sm',
    md: 'px-4 py-2 text-base',
    lg: 'px-6 py-3 text-lg',
  };
  
  return (
    <button
      className={`${baseStyles} ${getVariantStyles()} ${sizeStyles[size]} ${className}`}
      disabled={disabled}
      {...props}
    >
      {icon && <span>{icon}</span>}
      {children}
    </button>
  );
};