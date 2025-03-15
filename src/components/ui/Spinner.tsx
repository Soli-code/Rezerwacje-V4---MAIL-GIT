import React from 'react';

type SpinnerSize = 'sm' | 'md' | 'lg';

interface SpinnerProps {
  size?: SpinnerSize;
  className?: string;
  color?: string;
}

const Spinner: React.FC<SpinnerProps> = ({
  size = 'md',
  className = '',
  color = 'text-solrent-orange',
}) => {
  const sizeClasses = {
    sm: 'w-4 h-4',
    md: 'w-6 h-6',
    lg: 'w-8 h-8',
  };

  return (
    <div className={`inline-block animate-spin rounded-full border-2 border-solid border-current border-r-transparent ${sizeClasses[size]} ${color} ${className}`} role="status">
      <span className="sr-only">Ładowanie...</span>
    </div>
  );
};

export default Spinner; 