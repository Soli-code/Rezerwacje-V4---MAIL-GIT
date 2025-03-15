import React, { useState, useEffect } from 'react';
import { supabase } from '../../lib/supabase';
import { 
  UserPlus, Phone, Mail, Calendar, FileText, 
  Check, X, AlertTriangle, ArrowUpRight, ArrowDownRight,
  Edit, Trash2, Plus, Filter, Download
} from 'lucide-react';
import { motion } from 'framer-motion';

interface Contact {
  id: string;
  customer_id: string;
  status: 'lead' | 'customer' | 'inactive';
  source: string;
  assigned_to: string;
  last_contact_date: string;
  next_contact_date: string;
  lead_score: number;
  custom_fields: Record<string, any>;
  customer: {
    first_name: string;
    last_name: string;
    email: string;
    phone: string;
  };
}

interface Task {
  id: string;
  contact_id: string;
  title: string;
  description: string;
  due_date: string;
  priority: 'low' | 'medium' | 'high';
  status: 'pending' | 'in_progress' | 'completed' | 'cancelled';
}

const CRMDashboard: React.FC = () => {
  const [contacts, setContacts] = useState<Contact[]>([]);
  const [tasks, setTasks] = useState<Task[]>([]);
  const [selectedContact, setSelectedContact] = useState<Contact | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [filter, setFilter] = useState({
    status: 'all',
    source: 'all',
    assignedTo: 'all'
  });

  useEffect(() => {
    loadCRMData();
  }, [filter]);

  const loadCRMData = async () => {
    try {
      setIsLoading(true);
      
      // Pobierz kontakty
      const { data: contactsData, error: contactsError } = await supabase
        .from('crm_contacts')
        .select(`
          *,
          customer:customers (
            first_name,
            last_name,
            email,
            phone
          )
        `)
        .order('lead_score', { ascending: false });

      if (contactsError) throw contactsError;

      // Pobierz zadania
      const { data: tasksData, error: tasksError } = await supabase
        .from('crm_tasks')
        .select('*')
        .order('due_date', { ascending: true });

      if (tasksError) throw tasksError;

      setContacts(contactsData || []);
      setTasks(tasksData || []);
    } catch (err) {
      console.error('Error loading CRM data:', err);
      setError('Nie udało się załadować danych CRM');
    } finally {
      setIsLoading(false);
    }
  };

  const handleStatusChange = async (contactId: string, newStatus: string) => {
    try {
      const { error } = await supabase
        .from('crm_contacts')
        .update({ status: newStatus })
        .eq('id', contactId);

      if (error) throw error;
      await loadCRMData();
    } catch (err) {
      console.error('Error updating contact status:', err);
      setError('Nie udało się zaktualizować statusu kontaktu');
    }
  };

  const handleTaskStatusChange = async (taskId: string, newStatus: string) => {
    try {
      const { error } = await supabase
        .from('crm_tasks')
        .update({ status: newStatus })
        .eq('id', taskId);

      if (error) throw error;
      await loadCRMData();
    } catch (err) {
      console.error('Error updating task status:', err);
      setError('Nie udało się zaktualizować statusu zadania');
    }
  };

  const calculateConversionRate = () => {
    const customerCount = contacts.filter(c => c.status === 'customer').length;
    const totalCount = contacts.length;
    return totalCount > 0 ? ((customerCount / totalCount) * 100).toFixed(1) : '0.0';
  };

  const calculateAverageLeadScore = () => {
    const totalScore = contacts.reduce((acc, c) => acc + (c.lead_score || 0), 0);
    return contacts.length > 0 ? Math.round(totalScore / contacts.length) : 0;
  };

  const exportContacts = (format: 'pdf' | 'csv') => {
    // Implementacja eksportu kontaktów
  };

  return (
    <div className="space-y-6">
      {/* Nagłówek */}
      <div className="flex justify-between items-center">
        <h2 className="text-2xl font-bold text-gray-900">CRM</h2>
        <div className="flex items-center space-x-4">
          <select
            value={filter.status}
            onChange={(e) => setFilter({ ...filter, status: e.target.value })}
            className="px-4 py-2 border rounded-lg"
          >
            <option value="all">Wszystkie statusy</option>
            <option value="lead">Leady</option>
            <option value="customer">Klienci</option>
            <option value="inactive">Nieaktywni</option>
          </select>
          <button
            onClick={() => exportContacts('pdf')}
            className="px-4 py-2 bg-white border rounded-lg hover:bg-gray-50"
          >
            <Download className="w-5 h-5" />
          </button>
        </div>
      </div>

      {/* Statystyki */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <div className="bg-white rounded-lg shadow p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-500">Aktywne leady</p>
              <p className="text-2xl font-bold">
                {contacts.filter(c => c.status === 'lead').length}
              </p>
            </div>
            <UserPlus className="w-8 h-8 text-blue-500" />
          </div>
        </div>

        <div className="bg-white rounded-lg shadow p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-500">Zadania na dziś</p>
              <p className="text-2xl font-bold">
                {tasks.filter(t => 
                  new Date(t.due_date).toDateString() === new Date().toDateString()
                ).length}
              </p>
            </div>
            <Calendar className="w-8 h-8 text-green-500" />
          </div>
        </div>

        <div className="bg-white rounded-lg shadow p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-500">Konwersja</p>
              <p className="text-2xl font-bold">
                {calculateConversionRate() + '%'}
              </p>
            </div>
            <ArrowUpRight className="w-8 h-8 text-green-500" />
          </div>
        </div>

        <div className="bg-white rounded-lg shadow p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-500">Średni Lead Score</p>
              <p className="text-2xl font-bold">
                {calculateAverageLeadScore().toString()}
              </p>
            </div>
            <FileText className="w-8 h-8 text-orange-500" />
          </div>
        </div>
      </div>

      {/* Lista kontaktów */}
      <div className="bg-white rounded-lg shadow overflow-hidden">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Kontakt
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Status
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Lead Score
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Ostatni kontakt
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Następny kontakt
              </th>
              <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                Akcje
              </th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {contacts.map(contact => (
              <tr key={contact.id} className="hover:bg-gray-50">
                <td className="px-6 py-4 whitespace-nowrap">
                  <div className="flex items-center">
                    <div>
                      <div className="text-sm font-medium text-gray-900">
                        {contact.customer.first_name} {contact.customer.last_name}
                      </div>
                      <div className="text-sm text-gray-500">
                        {contact.customer.email}
                      </div>
                    </div>
                  </div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <span className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${
                    contact.status === 'lead' ? 'bg-yellow-100 text-yellow-800' :
                    contact.status === 'customer' ? 'bg-green-100 text-green-800' :
                    'bg-gray-100 text-gray-800'
                  }`}>
                    {contact.status === 'lead' ? 'Lead' :
                     contact.status === 'customer' ? 'Klient' :
                     'Nieaktywny'}
                  </span>
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <div className="text-sm text-gray-900">{contact.lead_score}</div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {contact.last_contact_date ? 
                    new Date(contact.last_contact_date).toLocaleDateString() : 
                    'Brak'}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {contact.next_contact_date ? 
                    new Date(contact.next_contact_date).toLocaleDateString() : 
                    'Brak'}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                  <button
                    onClick={() => setSelectedContact(contact)}
                    className="text-indigo-600 hover:text-indigo-900"
                  >
                    <Edit className="w-5 h-5" />
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Lista zadań */}
      <div className="bg-white rounded-lg shadow p-6">
        <div className="flex justify-between items-center mb-4">
          <h3 className="text-lg font-medium">Zadania</h3>
          <button
            className="px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700"
          >
            <Plus className="w-5 h-5" />
          </button>
        </div>
        <div className="space-y-4">
          {tasks.map(task => (
            <div
              key={task.id}
              className="flex items-center justify-between p-4 bg-gray-50 rounded-lg"
            >
              <div>
                <h4 className="font-medium">{task.title}</h4>
                <p className="text-sm text-gray-500">{task.description}</p>
                <p className="text-xs text-gray-400">
                  Due: {new Date(task.due_date).toLocaleDateString()}
                </p>
              </div>
              <div className="flex items-center space-x-2">
                <span className={`px-2 py-1 text-xs rounded-full ${
                  task.priority === 'high' ? 'bg-red-100 text-red-800' :
                  task.priority === 'medium' ? 'bg-yellow-100 text-yellow-800' :
                  'bg-green-100 text-green-800'
                }`}>
                  {task.priority}
                </span>
                <button
                  onClick={() => handleTaskStatusChange(task.id, 'completed')}
                  className="text-green-600 hover:text-green-700"
                >
                  <Check className="w-5 h-5" />
                </button>
              </div>
            </div>
          ))}
        </div>
      </div>

      {error && (
        <div className="fixed bottom-4 right-4 bg-red-50 text-red-700 px-4 py-3 rounded-lg shadow-lg flex items-center space-x-2">
          <AlertTriangle className="w-5 h-5" />
          <span>{error}</span>
          <button
            onClick={() => setError(null)}
            className="ml-2 text-red-500 hover:text-red-600"
          >
            <X className="w-4 h-4" />
          </button>
        </div>
      )}
    </div>
  );
};

export default CRMDashboard;