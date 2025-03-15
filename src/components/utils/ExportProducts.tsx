import React from 'react';
import { Download } from 'lucide-react';

const ExportProducts = ({ equipmentData }) => {
  const handleExportCSV = () => {
    // Przygotuj nagłówki CSV
    const headers = ['ID', 'Nazwa', 'Opis', 'Cena', 'Kaucja', 'URL obrazu', 'Kategorie'];
    
    // Przygotuj wiersze danych
    const rows = equipmentData.map(item => [
      item.id,
      item.name,
      item.description,
      item.price,
      item.deposit || '',
      item.image,
      item.categories.join(';')
    ]);
    
    // Połącz nagłówki i wiersze
    const csvContent = [
      headers.join(','),
      ...rows.map(row => 
        row.map(cell => 
          // Escapowanie przecinków i cudzysłowów w tekście
          typeof cell === 'string' && (cell.includes(',') || cell.includes('"')) 
            ? `"${cell.replace(/"/g, '""')}"` 
            : cell
        ).join(',')
      )
    ].join('\n');
    
    // Utwórz i pobierz plik
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = `solrent-produkty-${new Date().toISOString().split('T')[0]}.csv`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  return (
    <button
      onClick={handleExportCSV}
      className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 flex items-center"
    >
      <Download className="w-5 h-5 mr-2" />
      Eksportuj do CSV
    </button>
  );
};

export default ExportProducts;