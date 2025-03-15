import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '../../lib/supabase';
import { 
  Search, Download, Filter, Plus, Edit, Trash2, 
  Mail, Phone, Building2, Tag, Star, AlertTriangle, ChevronLeft, ChevronRight,
  ChevronDown, ChevronUp, X, Check, FileText
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

interface Customer {
  id: string;
  first_name: string;
  last_name: string;
  email: string;
  phone: string;
  company_name?: string;
  company_nip?: string;
  created_at: string;
  last_activity?: string;
  total_rentals?: number;
  total_value?: number;
  status?: string;
  tags?: string[];
}

interface Filter {
  status: string[];
  dateRange: string;
  minValue: string;
  search: string;
}

const AdminCustomers: React.FC = () => {
  const navigate = useNavigate();
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [sortField, setSortField] = useState<string>('created_at');
  const [sortDirection, setSortDirection] = useState<'asc' | 'desc'>('desc');
  const [showFilters, setShowFilters] = useState(false);
  const [filters, setFilters] = useState<Filter>({
    status: [],
    dateRange: '30days',
    minValue: '',
    search: ''
  });

  const itemsPerPage = 10;

  useEffect(() => {
    loadCustomers();
  }, [page, sortField, sortDirection, filters]);

  const loadCustomers = async () => {
    try {
      setLoading(true);
      
      let query = supabase
        .from('customers')
        .select(`
          *,
          customer_profiles!left (
            lead_status,
            lead_source,
            lifetime_value,
            avg_rental_duration,
            total_rentals,
            last_contact_date
          ),
          customer_activities!left (
            activity_type,
            created_at
          )
        `, { count: 'exact' });

      // Zastosuj filtry
      if (filters.search) {
        query = query.or(`
          first_name.ilike.%${filters.search}%,
          last_name.ilike.%${filters.search}%,
          email.ilike.%${filters.search}%,
          phone.ilike.%${filters.search}%,
          company_name.ilike.%${filters.search}%,
          company_nip.ilike.%${filters.search}%
        `);
      }

      if (filters.status.length > 0) {
        query = query.in('customer_profiles.lead_status', filters.status);
      }

      if (filters.minValue) {
        query = query.gte('customer_profiles.lifetime_value', parseFloat(filters.minValue));
      }

      switch (filters.dateRange) {
        case '7days':
          query = query.gte('created_at', new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString());
          break;
        case '30days':
          query = query.gte('created_at', new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString());
          break;
        case '90days':
          query = query.gte('created_at', new Date(Date.now() - 90 * 24 * 60 * 60 * 1000).toISOString());
          break;
      }

      // Sortowanie i paginacja
      query = query
        .order(sortField, { ascending: sortDirection === 'asc' })
        .range((page - 1) * itemsPerPage, page * itemsPerPage - 1);

      const { data, count, error } = await query;

      if (error) throw error;

      setCustomers(data || []);
      setTotalPages(Math.ceil((count || 0) / itemsPerPage));
      setError(null);
    } catch (err) {
      console.error('Error loading customers:', err);
      setError('Nie udało się załadować listy klientów');
    } finally {
      setLoading(false);
    }
  };

  const handleSort = (field: string) => {
    if (field === sortField) {
      setSortDirection(sortDirection === 'asc' ? 'desc' : 'asc');
    } else {
      setSortField(field);
      setSortDirection('asc');
    }
  };

  const exportToCSV = () => {
    const headers = [
      'ID',
      'Imię',
      'Nazwisko',
      'Email',
      'Telefon',
      'Firma',
      'NIP',
      'Data utworzenia',
      'Status',
      'Liczba wypożyczeń',
      'Wartość wypożyczeń'
    ];

    const csvContent = [
      headers.join(','),
      ...customers.map(customer => [
        customer.id,
        customer.first_name,
        customer.last_name,
        customer.email,
        customer.phone,
        customer.company_name || '',
        customer.company_nip || '',
        new Date(customer.created_at).toLocaleDateString(),
        customer.customer_profiles?.[0]?.status || '',
        customer.customer_profiles?.[0]?.total_rentals || 0,
        customer.customer_profiles?.[0]?.lifetime_value || 0
      ].join(','))
    ].join('\n');

    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = `klienci_${new Date().toISOString().split('T')[0]}.csv`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  return (
    <div className="space-y-6">
      {/* Nagłówek z wyszukiwarką i filtrami */}
      <div className="flex flex-col md:flex-row gap-4 justify-between items-start md:items-center">
        <div className="flex-1 w-full md:w-auto">
          <div className="relative">
            <input
              type="text"
              placeholder="Szukaj klientów..."
              className="w-full pl-10 pr-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-solrent-orange"
              value={filters.search}
              onChange={(e) => setFilters({ ...filters, search: e.target.value })}
            />
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
          </div>
        </div>
        
        <div className="flex gap-2 w-full md:w-auto">
          <button
            onClick={() => setShowFilters(!showFilters)}
            className="px-4 py-2 border rounded-lg hover:bg-gray-50 flex items-center gap-2"
          >
            <Filter className="w-5 h-5" />
            <span className="hidden md:inline">Filtry</span>
          </button>
          
          <button
            onClick={exportToCSV}
            className="px-4 py-2 border rounded-lg hover:bg-gray-50 flex items-center gap-2"
          >
            <Download className="w-5 h-5" />
            <span className="hidden md:inline">Eksportuj</span>
          </button>

          <button
            onClick={() => navigate('new')}
            className="px-4 py-2 bg-solrent-orange text-white rounded-lg hover:bg-orange-700 flex items-center gap-2"
          >
            <Plus className="w-5 h-5" />
            <span className="hidden md:inline">Dodaj klienta</span>
          </button>
        </div>
      </div>

      {/* Panel filtrów */}
      <AnimatePresence>
        {showFilters && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: 'auto', opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            className="overflow-hidden bg-white rounded-lg shadow p-4"
          >
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Status
                </label>
                <select
                  multiple
                  value={filters.status}
                  onChange={(e) => {
                    const values = Array.from(e.target.selectedOptions, option => option.value);
                    setFilters({ ...filters, status: values });
                  }}
                  className="w-full p-2 border rounded-lg"
                >
                  <option value="lead">Lead</option>
                  <option value="customer">Klient</option>
                  <option value="inactive">Nieaktywny</option>
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Okres
                </label>
                <select
                  value={filters.dateRange}
                  onChange={(e) => setFilters({ ...filters, dateRange: e.target.value })}
                  className="w-full p-2 border rounded-lg"
                >
                  <option value="7days">Ostatnie 7 dni</option>
                  <option value="30days">Ostatnie 30 dni</option>
                  <option value="90days">Ostatnie 90 dni</option>
                  <option value="all">Wszystkie</option>
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Min. wartość wypożyczeń
                </label>
                <input
                  type="number"
                  value={filters.minValue}
                  onChange={(e) => setFilters({ ...filters, minValue: e.target.value })}
                  className="w-full p-2 border rounded-lg"
                  placeholder="np. 1000"
                />
              </div>

              <div className="flex items-end">
                <button
                  onClick={() => setFilters({
                    status: [],
                    dateRange: '30days',
                    minValue: '',
                    search: ''
                  })}
                  className="w-full p-2 border rounded-lg text-gray-600 hover:bg-gray-50"
                >
                  Resetuj filtry
                </button>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Tabela klientów */}
      <div className="bg-white rounded-lg shadow overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th 
                  className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer"
                  onClick={() => handleSort('last_name')}
                >
                  <div className="flex items-center gap-2">
                    Klient
                    {sortField === 'last_name' && (
                      sortDirection === 'asc' ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />
                    )}
                  </div>
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Kontakt
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Firma
                </th>
                <th 
                  className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer"
                  onClick={() => handleSort('customer_profiles.status')}
                >
                  <div className="flex items-center gap-2">
                    Status
                    {sortField === 'customer_profiles.status' && (
                      sortDirection === 'asc' ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />
                    )}
                  </div>
                </th>
                <th 
                  className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer"
                  onClick={() => handleSort('customer_profiles.total_rentals')}
                >
                  <div className="flex items-center gap-2">
                    Wypożyczenia
                    {sortField === 'customer_profiles.total_rentals' && (
                      sortDirection === 'asc' ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />
                    )}
                  </div>
                </th>
                <th 
                  className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer"
                  onClick={() => handleSort('customer_profiles.lifetime_value')}
                >
                  <div className="flex items-center gap-2">
                    Wartość
                    {sortField === 'customer_profiles.lifetime_value' && (
                      sortDirection === 'asc' ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />
                    )}
                  </div>
                </th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Akcje
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {loading ? (
                <tr>
                  <td colSpan={7} className="px-6 py-4 text-center">
                    <div className="flex justify-center">
                      <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-solrent-orange"></div>
                    </div>
                  </td>
                </tr>
              ) : customers.length === 0 ? (
                <tr>
                  <td colSpan={7} className="px-6 py-4 text-center text-gray-500">
                    Nie znaleziono klientów spełniających kryteria
                  </td>
                </tr>
              ) : (
                customers.map(customer => (
                  <tr 
                    key={customer.id}
                    className="hover:bg-gray-50 cursor-pointer"
                    onClick={() => navigate(`${customer.id}`)}
                  >
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="flex items-center">
                        <div>
                          <div className="text-sm font-medium text-gray-900">
                            {customer.first_name} {customer.last_name}
                          </div>
                          <div className="text-sm text-gray-500">
                            ID: {customer.id.split('-')[0]}
                          </div>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm text-gray-900 flex flex-col gap-1">
                        <div className="flex items-center gap-1">
                          <Mail className="w-4 h-4 text-gray-400" />
                          {customer.email}
                        </div>
                        <div className="flex items-center gap-1">
                          <Phone className="w-4 h-4 text-gray-400" />
                          {customer.phone}
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      {customer.company_name && (
                        <div className="text-sm text-gray-900">
                          <div className="flex items-center gap-1">
                            <Building2 className="w-4 h-4 text-gray-400" />
                            {customer.company_name}
                          </div>
                          <div className="text-sm text-gray-500">
                            NIP: {customer.company_nip}
                          </div>
                        </div>
                      )}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${
                        customer.customer_profiles?.lead_status === 'hot' ? 'bg-red-100 text-red-800' :
                        customer.customer_profiles?.lead_status === 'warm' ? 'bg-yellow-100 text-yellow-800' :
                        customer.customer_profiles?.lead_status === 'converted' ? 'bg-green-100 text-green-800' :
                        'bg-gray-100 text-gray-800'
                      }`}>
                        {customer.customer_profiles?.lead_status === 'hot' ? 'Gorący lead' :
                         customer.customer_profiles?.lead_status === 'warm' ? 'Zainteresowany' :
                         customer.customer_profiles?.lead_status === 'converted' ? 'Klient' :
                         customer.customer_profiles?.lead_status === 'cold' ? 'Zimny lead' :
                         'Nowy'}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {customer.customer_profiles?.total_rentals || 0}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      {(customer.customer_profiles?.lifetime_value || 0).toFixed(2)} zł
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                      <div className="flex justify-end space-x-2" onClick={e => e.stopPropagation()}>
                        <button
                          onClick={() => navigate(`${customer.id}/edit`)}
                          className="text-indigo-600 hover:text-indigo-900"
                        >
                          <Edit className="w-5 h-5" />
                        </button>
                        <button
                          onClick={() => {/* TODO: Implement delete */}}
                          className="text-red-600 hover:text-red-900"
                        >
                          <Trash2 className="w-5 h-5" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {/* Paginacja */}
        <div className="bg-white px-4 py-3 flex items-center justify-between border-t border-gray-200 sm:px-6">
          <div className="flex-1 flex justify-between sm:hidden">
            <button
              onClick={() => setPage(page => Math.max(1, page - 1))}
              disabled={page === 1}
              className="relative inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Poprzednia
            </button>
            <button
              onClick={() => setPage(page => Math.min(totalPages, page + 1))}
              disabled={page === totalPages}
              className="ml-3 relative inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Następna
            </button>
          </div>
          <div className="hidden sm:flex-1 sm:flex sm:items-center sm:justify-between">
            <div>
              <p className="text-sm text-gray-700">
                Wyświetlanie{' '}
                <span className="font-medium">{(page - 1) * itemsPerPage + 1}</span>
                {' '}-{' '}
                <span className="font-medium">
                  {Math.min(page * itemsPerPage, customers.length)}
                </span>
                {' '}z{' '}
                <span className="font-medium">{customers.length}</span>
                {' '}wyników
              </p>
            </div>
            <div>
              <nav className="relative z-0 inline-flex rounded-md shadow-sm -space-x-px" aria-label="Pagination">
                <button
                  onClick={() => setPage(1)}
                  disabled={page === 1}
                  className="relative inline-flex items-center px-2 py-2 rounded-l-md border border-gray-300 bg-white text-sm font-medium text-gray-500 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <span className="sr-only">Pierwsza</span>
                  <ChevronDown className="h-5 w-5 rotate-90" />
                </button>
                <button
                  onClick={() => setPage(page => Math.max(1, page - 1))}
                  disabled={page === 1}
                  className="relative inline-flex items-center px-2 py-2 border border-gray-300 bg-white text-sm font-medium text-gray-500 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <span className="sr-only">Poprzednia</span>
                  <ChevronLeft className="h-5 w-5" />
                </button>
                {Array.from({ length: totalPages }, (_, i) => i + 1)
                  .filter(p => Math.abs(p - page) < 2 || p === 1 || p === totalPages)
                  .map((p, i, arr) => {
                    if (i > 0 && arr[i - 1] !== p - 1) {
                      return [
                        <span
                          key={`ellipsis-${p}`}
                          className="relative inline-flex items-center px-4 py-2 border border-gray-300 bg-white text-sm font-medium text-gray-700"
                        >
                          ...
                        </span>,
                        <button
                          key={p}
                          onClick={() => setPage(p)}
                          className={`relative inline-flex items-center px-4 py-2 border text-sm font-medium ${
                            p === page
                              ? 'z-10 bg-solrent-orange border-solrent-orange text-white'
                              : 'border-gray-300 bg-white text-gray-700 hover:bg-gray-50'
                          }`}
                        >
                          {p}
                        </button>
                      ];
                    }
                    return (
                      <button
                        key={p}
                        onClick={() => setPage(p)}
                        className={`relative inline-flex items-center px-4 py-2 border text-sm font-medium ${
                          p === page
                            ? 'z-10 bg-solrent-orange border-solrent-orange text-white'
                            : 'border-gray-300 bg-white text-gray-700 hover:bg-gray-50'
                        }`}
                      >
                        {p}
                      </button>
                    );
                  })}
                <button
                  onClick={() => setPage(page => Math.min(totalPages, page + 1))}
                  disabled={page === totalPages}
                  className="relative inline-flex items-center px-2 py-2 border border-gray-300 bg-white text-sm font-medium text-gray-500 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <span className="sr-only">Następna</span>
                  <ChevronRight className="h-5 w-5" />
                </button>
                <button
                  onClick={() => setPage(totalPages)}
                  disabled={page === totalPages}
                  className="relative inline-flex items-center px-2 py-2 rounded-r-md border border-gray-300 bg-white text-sm font-medium text-gray-500 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <span className="sr-only">Ostatnia</span>
                  <ChevronDown className="h-5 w-5 -rotate-90" />
                </button>
              </nav>
            </div>
          </div>
        </div>
      </div>

      {error && (
        <div className="fixed bottom-4 right-4 bg-red-50 text-red-700 px-4 py-3 rounded-lg shadow-lg flex items-center">
          <AlertTriangle className="w-5 h-5 mr-2" />
          <span>{error}</span>
          <button
            onClick={() => setError(null)}
            className="ml-4 text-red-500 hover:text-red-600"
          >
            <X className="w-4 h-4" />
          </button>
        </div>
      )}
    </div>
  );
};

export default AdminCustomers