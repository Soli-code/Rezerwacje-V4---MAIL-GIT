import React from 'react';
import { Download, FileText } from 'lucide-react';

interface ExportProductsProps {
  onExport: (format: 'csv' | 'pdf') => void;
}

const ExportProducts: React.FC<ExportProductsProps> = ({ onExport }) => {
  return (
    <div className="flex space-x-2">
      <button
        onClick={() => onExport('csv')}
        className="px-3 py-1.5 bg-green-600 text-white rounded-md hover:bg-green-700 flex items-center gap-1.5 text-sm"
      >
        <Download className="w-4 h-4" />
        Eksportuj CSV
      </button>
      <button
        onClick={() => onExport('pdf')}
        className="px-3 py-1.5 bg-blue-600 text-white rounded-md hover:bg-blue-700 flex items-center gap-1.5 text-sm"
      >
        <FileText className="w-4 h-4" />
        Eksportuj PDF
      </button>
    </div>
  );
};

export default ExportProducts; 