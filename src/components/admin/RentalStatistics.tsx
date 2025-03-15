import React, { useState, useEffect } from 'react';
import { supabase } from '../../lib/supabase';
import { 
  Package, Users, Calendar, FileText, Download,
  BarChart2, PieChart, TrendingUp, AlertTriangle,
  Filter, FileDown
} from 'lucide-react';
import { jsPDF } from 'jspdf';
import 'jspdf-autotable';

interface StatCardProps {
  icon: React.ElementType;
  title: string;
  value: string | number;
  description: string;
  trend?: 'up' | 'down';
  percentage?: number;
}

const StatCard: React.FC<StatCardProps> = ({ icon: Icon, title, value, description, trend, percentage }) => (
  <div className="bg-white rounded-lg shadow p-6">
    <div className="flex items-center justify-between">
      <div className="flex items-center">
        <Icon className="w-6 h-6 text-gray-500 mr-3" />
        <div>
          <h3 className="text-sm font-medium text-gray-500">{title}</h3>
          <div className="text-2xl font-semibold">{value}</div>
        </div>
      </div>
      {trend && percentage && (
        <div className={`flex items-center ${trend === 'up' ? 'text-green-500' : 'text-red-500'}`}>
          <TrendingUp className={`w-4 h-4 ${trend === 'down' && 'rotate-180'}`} />
          <span className="text-sm ml-1">{percentage}%</span>
        </div>
      )}
    </div>
    <p className="mt-2 text-sm text-gray-500">{description}</p>
  </div>
);

const RentalStatistics: React.FC = () => {
  const [dateRange, setDateRange] = useState('30days');
  const [stats, setStats] = useState({
    activeRentals: 0,
    monthlyRentals: 0,
    avgDuration: 0,
    totalRevenue: 0,
    popularEquipment: [] as any[],
    monthlyStats: [] as any[],
    equipmentCategories: [] as any[],
    overdueRentals: [] as any[],
    topCustomers: [] as any[]
  });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    loadStatistics();
  }, [dateRange]);

  const loadStatistics = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase.rpc('get_rental_statistics', {
        p_date_range: dateRange
      });

      if (error) throw error;

      setStats({
        activeRentals: data?.activeRentals || 0,
        monthlyRentals: data?.monthlyRentals || 0,
        avgDuration: data?.avgDuration || 0,
        totalRevenue: data?.totalRevenue || 0,
        popularEquipment: data?.popularEquipment || [],
        monthlyStats: data?.monthlyStats || [],
        equipmentCategories: data?.equipmentCategories || [],
        overdueRentals: data?.overdueRentals || [],
        topCustomers: data?.topCustomers || []
      });
      setError(null);
    } catch (err) {
      console.error('Error loading statistics:', err);
      setError('Nie udało się załadować statystyk');
    } finally {
      setLoading(false);
    }
  };

  const exportToPDF = () => {
    const doc = new jsPDF();
    
    // Tytuł
    doc.setFontSize(20);
    doc.text('Raport statystyk wypożyczeń', 20, 20);
    
    // Data raportu
    doc.setFontSize(12);
    doc.text(`Wygenerowano: ${new Date().toLocaleString('pl-PL')}`, 20, 30);
    
    // Główne wskaźniki
    doc.setFontSize(14);
    doc.text('Główne wskaźniki:', 20, 45);
    
    const mainStats = [
      ['Aktywne wypożyczenia', stats.activeRentals.toString()],
      ['Wypożyczenia w tym miesiącu', stats.monthlyRentals.toString()],
      ['Średni czas wypożyczenia', `${stats.avgDuration.toFixed(1)} dni`],
      ['Całkowity przychód', `${stats.totalRevenue.toFixed(2)} zł`]
    ];
    
    (doc as any).autoTable({
      startY: 50,
      head: [['Wskaźnik', 'Wartość']],
      body: mainStats,
      theme: 'grid'
    });
    
    // Najpopularniejszy sprzęt
    doc.text('Najpopularniejszy sprzęt:', 20, (doc as any).lastAutoTable.finalY + 15);
    
    const popularEquipment = stats.popularEquipment.map(item => [
      item.name,
      item.count.toString(),
      `${item.percentage}%`
    ]);
    
    (doc as any).autoTable({
      startY: (doc as any).lastAutoTable.finalY + 20,
      head: [['Nazwa', 'Liczba wypożyczeń', 'Udział']],
      body: popularEquipment,
      theme: 'grid'
    });
    
    doc.save('raport-wypozyczen.pdf');
  };

  const exportToCSV = () => {
    const csvContent = [
      ['Raport statystyk wypożyczeń'],
      ['Wygenerowano:', new Date().toLocaleString('pl-PL')],
      [],
      ['Główne wskaźniki'],
      ['Aktywne wypożyczenia', stats.activeRentals],
      ['Wypożyczenia w tym miesiącu', stats.monthlyRentals],
      ['Średni czas wypożyczenia', stats.avgDuration.toFixed(1)],
      ['Całkowity przychód', stats.totalRevenue.toFixed(2)],
      [],
      ['Najpopularniejszy sprzęt'],
      ['Nazwa', 'Liczba wypożyczeń', 'Udział %'],
      ...stats.popularEquipment.map(item => [
        item.name,
        item.count,
        item.percentage
      ])
    ].map(row => row.join(',')).join('\n');

    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = 'raport-wypozyczen.csv';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  if (loading) {
    return (
      <div className="flex justify-center items-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-solrent-orange"></div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-red-50 p-4 rounded-lg text-red-700 flex items-center">
        <AlertTriangle className="w-5 h-5 mr-2" />
        <p>{error}</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Nagłówek z filtrowaniem i eksportem */}
      <div className="flex justify-between items-center">
        <div className="flex items-center space-x-4">
          <h2 className="text-2xl font-bold text-gray-900">Statystyki wypożyczeń</h2>
          <select
            value={dateRange}
            onChange={(e) => setDateRange(e.target.value)}
            className="px-4 py-2 border rounded-lg"
          >
            <option value="7days">Ostatnie 7 dni</option>
            <option value="30days">Ostatnie 30 dni</option>
            <option value="90days">Ostatnie 90 dni</option>
            <option value="12months">Ostatnie 12 miesięcy</option>
          </select>
        </div>
        <div className="flex space-x-2">
          <button
            onClick={exportToPDF}
            className="flex items-center px-4 py-2 bg-white border rounded-lg hover:bg-gray-50"
          >
            <FileDown className="w-5 h-5 mr-2" />
            PDF
          </button>
          <button
            onClick={exportToCSV}
            className="flex items-center px-4 py-2 bg-white border rounded-lg hover:bg-gray-50"
          >
            <Download className="w-5 h-5 mr-2" />
            CSV
          </button>
        </div>
      </div>

      {/* Główne wskaźniki */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <StatCard
          icon={Package}
          title="Aktywne wypożyczenia"
          value={stats.activeRentals}
          description="Obecnie wypożyczony sprzęt"
          trend="up"
          percentage={8}
        />
        <StatCard
          icon={Calendar}
          title="Wypożyczenia w tym miesiącu"
          value={stats.monthlyRentals}
          description="Wzrost o 15% m/m"
          trend="up"
          percentage={15}
        />
        <StatCard
          icon={Calendar}
          title="Średni czas wypożyczenia"
          value={`${stats.avgDuration.toFixed(1)} dni`}
          description="Średnia z ostatnich 30 dni"
        />
        <StatCard
          icon={FileText}
          title="Całkowity przychód"
          value={`${stats.totalRevenue.toFixed(2)} zł`}
          description="W wybranym okresie"
          trend="up"
          percentage={12}
        />
      </div>

      {/* Wykresy */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Miesięczny wykres wypożyczeń */}
        <div className="bg-white rounded-lg shadow p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-medium text-gray-900">
              Liczba wypożyczeń w czasie
            </h3>
            <BarChart2 className="w-5 h-5 text-gray-400" />
          </div>
          <div className="h-64 flex items-center justify-center text-gray-500">
            Wykres będzie dostępny wkrótce
          </div>
        </div>

        {/* Wykres kategorii sprzętu */}
        <div className="bg-white rounded-lg shadow p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-medium text-gray-900">
              Podział na kategorie sprzętu
            </h3>
            <PieChart className="w-5 h-5 text-gray-400" />
          </div>
          <div className="h-64 flex items-center justify-center text-gray-500">
            Wykres będzie dostępny wkrótce
          </div>
        </div>
      </div>

      {/* Szczegółowe zestawienia */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Najpopularniejszy sprzęt */}
        <div className="bg-white rounded-lg shadow p-6">
          <h3 className="text-lg font-medium text-gray-900 mb-4">
            Najpopularniejszy sprzęt
          </h3>
          <div className="space-y-4">
            {stats.popularEquipment.map((item, index) => (
              <div key={index} className="flex items-center">
                <div className="w-8 text-sm text-gray-500">{index + 1}.</div>
                <div className="flex-1">
                  <div className="text-sm font-medium text-gray-900">
                    {item.name}
                  </div>
                  <div className="text-sm text-gray-500">
                    {item.count} wypożyczeń
                  </div>
                </div>
                <div className="w-24 h-2 bg-gray-100 rounded-full overflow-hidden">
                  <div 
                    className="h-full bg-green-500" 
                    style={{ width: `${item.percentage}%` }}
                  />
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Najczęściej wypożyczający klienci */}
        <div className="bg-white rounded-lg shadow p-6">
          <h3 className="text-lg font-medium text-gray-900 mb-4">
            Najczęściej wypożyczający klienci
          </h3>
          <div className="space-y-4">
            {stats.topCustomers.map((customer, index) => (
              <div key={index} className="flex items-center">
                <div className="w-8 text-sm text-gray-500">{index + 1}.</div>
                <div className="flex-1">
                  <div className="text-sm font-medium text-gray-900">
                    {customer.name}
                  </div>
                  <div className="text-sm text-gray-500">
                    {customer.rentals} wypożyczeń, {customer.totalValue} zł
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Przeterminowane wypożyczenia */}
      <div className="bg-white rounded-lg shadow p-6">
        <h3 className="text-lg font-medium text-gray-900 mb-4">
          Przeterminowane wypożyczenia
        </h3>
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead>
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Klient
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Sprzęt
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Data zwrotu
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Opóźnienie (dni)
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {stats.overdueRentals.map((rental, index) => (
                <tr key={index}>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="text-sm font-medium text-gray-900">
                      {rental.customerName}
                    </div>
                    <div className="text-sm text-gray-500">
                      {rental.customerPhone}
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="text-sm text-gray-900">
                      {rental.equipmentName}
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="text-sm text-gray-900">
                      {new Date(rental.returnDate).toLocaleDateString()}
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="text-sm font-medium text-red-600">
                      {rental.daysOverdue}
                    </div>
                  </td>
                </tr>
              ))}
              {stats.overdueRentals.length === 0 && (
                <tr>
                  <td colSpan={4} className="px-6 py-4 text-center text-gray-500">
                    Brak przeterminowanych wypożyczeń
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};

export default RentalStatistics;