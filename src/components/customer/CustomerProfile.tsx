import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { supabase } from '../../lib/supabase';
import {
  User,
  Phone,
  Mail,
  Building2,
  Tag,
  Edit,
  Trash2,
  Ban,
  AlertTriangle,
  ChevronDown,
  DollarSign,
  Package,
  Calendar,
  BarChart2,
  FileText,
  Clock,
  ArrowUpRight,
  ArrowDownRight,
  Download,
  Save,
  X,
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

interface CustomerProfile {
  id: string;
  first_name: string;
  last_name: string;
  email: string;
  phone: string;
  company_name?: string;
  company_nip?: string;
  company_street?: string;
  company_postal_code?: string;
  company_city?: string;
  created_at: string;
  profile: {
    lead_status: string;
    lifetime_value: number;
    total_rentals: number;
    avg_rental_duration: number;
    last_contact_date?: string;
    notes?: string;
    tags?: string[];
  };
  activities: Array<{
    id: string;
    type: string;
    description: string;
    created_at: string;
    amount?: number;
    tags?: string[];
  }>;
  rentals: Array<{
    id: string;
    start_date: string;
    end_date: string;
    total_price: number;
    status: string;
    items: Array<{
      equipment_name: string;
      quantity: number;
    }>;
  }>;
}

const CustomerProfile: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [profile, setProfile] = useState<CustomerProfile | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState('overview');
  const [showNotes, setShowNotes] = useState(false);
  const [newNote, setNewNote] = useState('');
  const [dateRange, setDateRange] = useState('30days');
  const [isEditing, setIsEditing] = useState(false);
  const [editedData, setEditedData] = useState<Partial<CustomerProfile> | null>(
    null
  );
  const [showDeleteConfirmation, setShowDeleteConfirmation] = useState(false);
  const [showBlockConfirmation, setShowBlockConfirmation] = useState(false);
  const [blockReason, setBlockReason] = useState('');
  const [validationErrors, setValidationErrors] = useState<
    Record<string, string>
  >({});
  const [selectedCategories, setSelectedCategories] = useState<string[]>([]);
  const [isCompany, setIsCompany] = useState(false);

  useEffect(() => {
    loadCustomerProfile();
  }, [id]);

  useEffect(() => {
    if (profile) {
      setEditedData({
        company_street: profile.company_street || '',
        company_postal_code: profile.company_postal_code || '',
        company_city: profile.company_city || '',
        company_name: profile.company_name || '',
        company_nip: profile.company_nip || '',
      });
    }
  }, [profile]);

  const validateForm = () => {
    const errors: Record<string, string> = {};

    if (
      editedData?.company_nip &&
      !editedData.company_nip.match(/^\d{3}-\d{3}-\d{2}-\d{2}$/)
    ) {
      errors.company_nip = 'Nieprawidłowy format NIP (XXX-XXX-XX-XX)';
    }

    if (
      editedData?.company_postal_code &&
      !editedData.company_postal_code.match(/^\d{2}-\d{3}$/)
    ) {
      errors.company_postal_code =
        'Nieprawidłowy format kodu pocztowego (XX-XXX)';
    }

    setValidationErrors(errors);
    return Object.keys(errors).length === 0;
  };

  const handleSaveChanges = async () => {
    if (!editedData) return;

    if (!validateForm()) {
      setError('Proszę poprawić błędy w formularzu');
      return;
    }

    try {
      const { error } = await supabase
        .from('customers')
        .update(editedData)
        .eq('id', id);

      if (error) throw error;

      await loadCustomerProfile();
      setIsEditing(false);
      setError(null);
    } catch (err) {
      console.error('Error updating customer:', err);
      setError('Nie udało się zapisać zmian');
    }
  };

  useEffect(() => {
    if (profile) {
      setEditedData({
        first_name: profile.first_name,
        last_name: profile.last_name,
        email: profile.email,
        phone: profile.phone,
        status: profile.status || 'active',
        company_name: profile.company_name,
        company_nip: profile.company_nip,
        company_street: profile.company_street,
        company_postal_code: profile.company_postal_code,
        company_city: profile.company_city,
      });
      setIsCompany(!!profile.company_name);
    }
  }, [profile]);

  const loadCustomerProfile = async () => {
    try {
      setLoading(true);

      // Pobierz dane klienta
      const { data: customerData, error: customerError } = await supabase
        .from('customers')
        .select(
          `
          *,
          profile:customer_profiles!left(*),
          activities:customer_activities(
            id,
            type:activity_type,
            description,
            created_at,
            amount,
            tags:customer_activity_tags(
              tag:customer_tags(*)
            )
          ),
          rentals:reservations(
            id,
            start_date,
            end_date,
            total_price,
            status,
            items:reservation_items(
              equipment:equipment(name),
              quantity
            )
          )
        `
        )
        .eq('id', id)
        .single();

      if (customerError) throw customerError;

      setProfile(customerData);
      setError(null);
    } catch (err) {
      console.error('Error loading customer profile:', err);
      setError('Nie udało się załadować profilu klienta');
    } finally {
      setLoading(false);
    }
  };

  const handleSaveNote = async () => {
    if (!newNote.trim()) return;

    try {
      const { error } = await supabase.from('customer_activities').insert({
        customer_id: id,
        activity_type: 'note',
        description: newNote,
        created_by: (await supabase.auth.getUser()).data.user?.id,
      });

      if (error) throw error;

      setNewNote('');
      loadCustomerProfile();
    } catch (err) {
      console.error('Error saving note:', err);
      setError('Nie udało się zapisać notatki');
    }
  };

  const handleStatusChange = async (newStatus: string) => {
    try {
      const { error } = await supabase.from('customer_profiles').upsert({
        id,
        lead_status: newStatus,
        updated_at: new Date().toISOString(),
      });

      if (error) throw error;

      loadCustomerProfile();
    } catch (err) {
      console.error('Error updating status:', err);
      setError('Nie udało się zaktualizować statusu');
    }
  };

  const handleCancelEdit = () => {
    if (profile) {
      setEditedData({
        first_name: profile.first_name,
        last_name: profile.last_name,
        email: profile.email,
        phone: profile.phone,
        company_street: profile.company_street || '',
        company_postal_code: profile.company_postal_code || '',
        company_city: profile.company_city || '',
        company_name: profile.company_name || '',
        company_nip: profile.company_nip || '',
      });
    }
    setIsEditing(false);
    setValidationErrors({});
  };

  const handleDelete = async () => {
    try {
      const { error } = await supabase.from('customers').delete().eq('id', id);

      if (error) throw error;

      // Przekieruj do listy klientów po pomyślnym usunięciu
      navigate('/admin/panel/customers', {
        replace: true,
        state: { message: 'Klient został pomyślnie usunięty' },
      });
    } catch (err) {
      console.error('Error deleting customer:', err);
      setError('Nie udało się usunąć klienta');
      setShowDeleteConfirmation(false);
    }
  };

  const handleBlock = async () => {
    try {
      const { error } = await supabase.rpc('block_customer', {
        p_customer_id: id,
        p_reason: blockReason,
      });

      if (error) throw error;

      setShowBlockConfirmation(false);
      setBlockReason('');
      loadCustomerProfile();
    } catch (err) {
      console.error('Error blocking customer:', err);
      setError('Nie udało się zablokować klienta');
    }
  };

  const handleUnblock = async () => {
    try {
      const { error } = await supabase.rpc('unblock_customer', {
        p_customer_id: id,
      });

      if (error) throw error;

      loadCustomerProfile();
    } catch (err) {
      console.error('Error unblocking customer:', err);
      setError('Nie udało się odblokować klienta');
    }
  };

  if (loading) {
    return (
      <div className="flex justify-center items-center h-screen">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-solrent-orange"></div>
      </div>
    );
  }

  if (!profile) {
    return (
      <div className="p-6">
        <div className="bg-red-50 text-red-700 p-4 rounded-lg flex items-center">
          <AlertTriangle className="w-5 h-5 mr-2" />
          <span>Nie znaleziono profilu klienta</span>
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto p-6 space-y-6">
      {/* Nagłówek */}
      <div className="flex justify-between items-start">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">
            {isEditing ? (
              <div className="flex gap-2">
                <input
                  type="text"
                  value={editedData?.first_name || ''}
                  onChange={(e) =>
                    setEditedData((prev) => ({
                      ...prev,
                      first_name: e.target.value,
                    }))
                  }
                  className="px-3 py-1.5 border rounded-lg"
                  placeholder="Imię"
                />
                <input
                  type="text"
                  value={editedData?.last_name || ''}
                  onChange={(e) =>
                    setEditedData((prev) => ({
                      ...prev,
                      last_name: e.target.value,
                    }))
                  }
                  className="px-3 py-1.5 border rounded-lg"
                  placeholder="Nazwisko"
                />
              </div>
            ) : (
              `${profile.first_name} ${profile.last_name}`
            )}
          </h1>
          <div className="mt-1 flex items-center gap-4">
            <span
              className={`px-2 py-1 rounded-full text-sm font-medium ${
                profile.profile?.lead_status === 'hot'
                  ? 'bg-red-100 text-red-800'
                  : profile.profile?.lead_status === 'warm'
                  ? 'bg-yellow-100 text-yellow-800'
                  : profile.profile?.lead_status === 'converted'
                  ? 'bg-green-100 text-green-800'
                  : 'bg-gray-100 text-gray-800'
              }`}
            >
              {profile.profile?.lead_status === 'hot'
                ? 'Gorący lead'
                : profile.profile?.lead_status === 'warm'
                ? 'Zainteresowany'
                : profile.profile?.lead_status === 'converted'
                ? 'Klient'
                : 'Nowy'}
            </span>
            <span className="text-sm text-gray-500">
              Klient od: {new Date(profile.created_at).toLocaleDateString()}
            </span>
          </div>
        </div>
        <div className="flex gap-2">
          <button
            onClick={() =>
              isEditing ? handleCancelEdit() : setIsEditing(true)
            }
            className="px-3 py-1.5 text-sm border rounded-lg hover:bg-gray-50 flex items-center gap-1.5"
          >
            {isEditing ? (
              <>
                <X className="w-4 h-4" />
                Anuluj
              </>
            ) : (
              <>
                <Edit className="w-4 h-4" />
                Edytuj
              </>
            )}
          </button>
          {isEditing && (
            <button
              onClick={handleSaveChanges}
              className="px-3 py-1.5 text-sm bg-solrent-orange text-white rounded-lg hover:bg-orange-700 flex items-center gap-1.5"
            >
              <Save className="w-4 h-4" />
              Zapisz
            </button>
          )}
          <button
            className="px-3 py-1.5 text-sm border rounded-lg hover:bg-gray-50 flex items-center gap-1.5 text-yellow-600 border-yellow-200 hover:bg-yellow-50"
            onClick={() =>
              profile.status === 'inactive'
                ? handleUnblock()
                : setShowBlockConfirmation(true)
            }
          >
            <Ban className="w-4 h-4" />
            {profile.status === 'inactive' ? 'Odblokuj' : 'Zablokuj'}
          </button>
          <button
            onClick={() => setShowDeleteConfirmation(true)}
            className="px-3 py-1.5 text-sm border rounded-lg hover:bg-gray-50 flex items-center gap-1.5 text-red-600 border-red-200 hover:bg-red-50 transition-colors"
          >
            <Trash2 className="w-4 h-4" />
            Usuń
          </button>
        </div>
      </div>

      {/* Główna zawartość */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Dane kontaktowe */}
        <div className="bg-white rounded-lg shadow p-6">
          <h2 className="text-lg font-medium text-gray-900 mb-4">
            Dane kontaktowe
          </h2>
          {isEditing && (
            <div className="mb-4">
              <label className="flex items-center gap-2">
                <input
                  type="checkbox"
                  checked={isCompany}
                  onChange={(e) => setIsCompany(e.target.checked)}
                  className="rounded border-gray-300 text-solrent-orange focus:ring-solrent-orange"
                />
                <span className="text-sm text-gray-700">Klient firmowy</span>
              </label>
            </div>
          )}
          <div className="space-y-4">
            <div className="flex items-center gap-3">
              <div className="flex items-center gap-3 w-full">
                <Mail className="w-5 h-5 text-gray-400 flex-shrink-0" />
                {isEditing ? (
                  <input
                    type="email"
                    value={editedData?.email || ''}
                    onChange={(e) =>
                      setEditedData((prev) => ({
                        ...prev,
                        email: e.target.value,
                      }))
                    }
                    className="w-full px-3 py-1.5 border rounded-lg"
                    placeholder="Email"
                  />
                ) : (
                  <span>{profile.email}</span>
                )}
              </div>
            </div>
            {validationErrors.email && (
              <p className="text-sm text-red-600 ml-8">
                {validationErrors.email}
              </p>
            )}
            <div className="flex items-center gap-3">
              <div className="flex items-center gap-3 w-full">
                <Phone className="w-5 h-5 text-gray-400 flex-shrink-0" />
                {isEditing ? (
                  <input
                    type="tel"
                    value={editedData?.phone || ''}
                    onChange={(e) =>
                      setEditedData((prev) => ({
                        ...prev,
                        phone: e.target.value,
                      }))
                    }
                    className="w-full px-3 py-1.5 border rounded-lg"
                  />
                ) : (
                  <span>{profile.phone}</span>
                )}
              </div>
              {validationErrors.phone && (
                <p className="text-sm text-red-600 ml-8">
                  {validationErrors.phone}
                </p>
              )}
            </div>
            {validationErrors.phone && (
              <p className="text-sm text-red-600 ml-8">
                {validationErrors.phone}
              </p>
            )}
            {profile.company_name && (
              <div className="pt-4 border-t">
                <div className="flex items-center gap-3 mb-2">
                  <Building2 className="w-5 h-5 text-gray-400 flex-shrink-0" />
                  {isEditing ? (
                    <input
                      type="text"
                      value={editedData?.company_name || ''}
                      onChange={(e) =>
                        setEditedData((prev) => ({
                          ...prev,
                          company_name: e.target.value,
                        }))
                      }
                      className="w-full px-3 py-1.5 border rounded-lg"
                      placeholder="Nazwa firmy"
                    />
                  ) : (
                    <span className="font-medium">{profile.company_name}</span>
                  )}
                </div>
                <div className="text-sm text-gray-600 ml-8 space-y-1">
                  {isEditing ? (
                    <>
                      <div className="mb-2">
                        <input
                          type="text"
                          value={editedData?.company_nip || ''}
                          onChange={(e) =>
                            setEditedData((prev) => ({
                              ...prev,
                              company_nip: e.target.value,
                            }))
                          }
                          className="w-full px-3 py-1.5 border rounded-lg"
                          placeholder="NIP"
                        />
                      </div>
                      {validationErrors.company_nip && (
                        <p className="text-sm text-red-600">
                          {validationErrors.company_nip}
                        </p>
                      )}
                      {validationErrors.company_nip && (
                        <p className="text-sm text-red-600">
                          {validationErrors.company_nip}
                        </p>
                      )}
                      <div className="mb-2">
                        <input
                          type="text"
                          value={editedData?.company_street || ''}
                          onChange={(e) =>
                            setEditedData((prev) => ({
                              ...prev,
                              company_street: e.target.value,
                            }))
                          }
                          className="w-full px-3 py-1.5 border rounded-lg"
                          placeholder="Ulica i numer"
                        />
                      </div>
                      <div className="grid grid-cols-2 gap-2">
                        <input
                          type="text"
                          value={editedData?.company_postal_code || ''}
                          onChange={(e) =>
                            setEditedData((prev) => ({
                              ...prev,
                              company_postal_code: e.target.value,
                            }))
                          }
                          className="w-full px-3 py-1.5 border rounded-lg"
                          placeholder="Kod pocztowy"
                        />
                        <input
                          type="text"
                          value={editedData?.company_city || ''}
                          onChange={(e) =>
                            setEditedData((prev) => ({
                              ...prev,
                              company_city: e.target.value,
                            }))
                          }
                          className="w-full px-3 py-1.5 border rounded-lg"
                          placeholder="Miejscowość"
                        />
                      </div>
                      {validationErrors.company_postal_code && (
                        <p className="text-sm text-red-600">
                          {validationErrors.company_postal_code}
                        </p>
                      )}
                      {validationErrors.company_postal_code && (
                        <p className="text-sm text-red-600">
                          {validationErrors.company_postal_code}
                        </p>
                      )}
                    </>
                  ) : (
                    <>
                      <p>NIP: {profile.company_nip}</p>
                      <p>{profile.company_street}</p>
                      <p>
                        {profile.company_postal_code} {profile.company_city}
                      </p>
                    </>
                  )}
                </div>
              </div>
            )}
            <div className="pt-4 border-t">
              <div className="flex items-center gap-3 mb-2">
                <Tag className="w-5 h-5 text-gray-400" />
                <span className="font-medium">Tagi</span>
              </div>
              <div className="flex flex-wrap gap-2">
                {profile.profile?.tags?.map((tag) => (
                  <span
                    key={tag}
                    className="px-2 py-1 bg-gray-100 text-gray-700 rounded-full text-sm"
                  >
                    {tag}
                  </span>
                ))}
                <button className="px-2 py-1 border border-dashed border-gray-300 rounded-full text-sm text-gray-500 hover:border-gray-400">
                  + Dodaj tag
                </button>
              </div>
            </div>
          </div>
        </div>

        {/* KPI i statystyki */}
        <div className="bg-white rounded-lg shadow p-6">
          <h2 className="text-lg font-medium text-gray-900 mb-4">Wskaźniki</h2>
          <div className="grid grid-cols-2 gap-4">
            <div className="p-4 bg-gray-50 rounded-lg">
              <div className="text-sm text-gray-500">Wartość wypożyczeń</div>
              <div className="mt-1 flex items-end gap-2">
                <div className="text-2xl font-bold text-gray-900">
                  {profile.profile?.lifetime_value?.toFixed(2)} zł
                </div>
                <div className="text-sm text-green-600 flex items-center">
                  <ArrowUpRight className="w-4 h-4" />
                  12%
                </div>
              </div>
            </div>
            <div className="p-4 bg-gray-50 rounded-lg">
              <div className="text-sm text-gray-500">Liczba wypożyczeń</div>
              <div className="mt-1 flex items-end gap-2">
                <div className="text-2xl font-bold text-gray-900">
                  {profile.profile?.total_rentals || 0}
                </div>
                <div className="text-sm text-green-600 flex items-center">
                  <ArrowUpRight className="w-4 h-4" />
                  8%
                </div>
              </div>
            </div>
            <div className="p-4 bg-gray-50 rounded-lg">
              <div className="text-sm text-gray-500">Średni czas wynajmu</div>
              <div className="mt-1 flex items-end gap-2">
                <div className="text-2xl font-bold text-gray-900">
                  {profile.profile?.avg_rental_duration?.toFixed(1)} dni
                </div>
              </div>
            </div>
            <div className="p-4 bg-gray-50 rounded-lg">
              <div className="text-sm text-gray-500">Ostatnia aktywność</div>
              <div className="mt-1">
                <div className="text-sm font-medium text-gray-900">
                  {profile.profile?.last_contact_date
                    ? new Date(
                        profile.profile.last_contact_date
                      ).toLocaleDateString()
                    : 'Brak'}
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Notatki */}
        <div className="bg-white rounded-lg shadow p-6">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-lg font-medium text-gray-900">Notatki</h2>
            <button
              onClick={() => setShowNotes(!showNotes)}
              className="text-gray-400 hover:text-gray-600"
            >
              <ChevronDown
                className={`w-5 h-5 transform transition-transform ${
                  showNotes ? 'rotate-180' : ''
                }`}
              />
            </button>
          </div>
          <AnimatePresence>
            {showNotes && (
              <motion.div
                initial={{ height: 0, opacity: 0 }}
                animate={{ height: 'auto', opacity: 1 }}
                exit={{ height: 0, opacity: 0 }}
                transition={{ duration: 0.2 }}
                className="space-y-4"
              >
                <textarea
                  value={newNote}
                  onChange={(e) => setNewNote(e.target.value)}
                  placeholder="Dodaj notatkę..."
                  className="w-full px-3 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-solrent-orange"
                  rows={3}
                />
                <button
                  onClick={handleSaveNote}
                  disabled={!newNote.trim()}
                  className="w-full px-4 py-2 bg-solrent-orange text-white rounded-lg hover:bg-orange-700 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  Zapisz notatkę
                </button>
                <div className="space-y-3 mt-4">
                  {profile.activities
                    ?.filter((activity) => activity.type === 'note')
                    .map((note) => (
                      <div key={note.id} className="bg-gray-50 p-3 rounded-lg">
                        <p className="text-sm text-gray-900">
                          {note.description}
                        </p>
                        <p className="text-xs text-gray-500 mt-1">
                          {new Date(note.created_at).toLocaleString()}
                        </p>
                      </div>
                    ))}
                </div>
              </motion.div>
            )}
          </AnimatePresence>
        </div>

        {/* Historia wypożyczeń */}
        <div className="lg:col-span-3 bg-white rounded-lg shadow overflow-hidden">
          <div className="p-6 border-b">
            <div className="flex items-center justify-between">
              <h2 className="text-lg font-medium text-gray-900">
                Historia wypożyczeń
              </h2>
              <div className="flex gap-2">
                <select
                  value={dateRange}
                  onChange={(e) => setDateRange(e.target.value)}
                  className="px-3 py-1.5 border rounded-lg text-sm"
                >
                  <option value="30days">Ostatnie 30 dni</option>
                  <option value="90days">Ostatnie 90 dni</option>
                  <option value="12months">Ostatnie 12 miesięcy</option>
                  <option value="all">Wszystkie</option>
                </select>
                <button className="px-3 py-1.5 border rounded-lg text-sm hover:bg-gray-50 flex items-center gap-1.5">
                  <Download className="w-4 h-4" />
                  Eksportuj
                </button>
              </div>
            </div>
          </div>
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Data
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Sprzęt
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Status
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Wartość
                  </th>
                  <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Akcje
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {profile.rentals?.map((rental) => (
                  <tr key={rental.id} className="hover:bg-gray-50">
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm text-gray-900">
                        {new Date(rental.start_date).toLocaleDateString()}
                      </div>
                      <div className="text-sm text-gray-500">
                        {new Date(rental.end_date).toLocaleDateString()}
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <div className="text-sm text-gray-900">
                        {rental.items.map((item) => (
                          <div key={item.equipment.name}>
                            {item.equipment.name} (x{item.quantity})
                          </div>
                        ))}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span
                        className={`px-2 py-1 inline-flex text-xs leading-5 font-semibold rounded-full ${
                          rental.status === 'completed'
                            ? 'bg-green-100 text-green-800'
                            : rental.status === 'cancelled'
                            ? 'bg-red-100 text-red-800'
                            : rental.status === 'pending'
                            ? 'bg-yellow-100 text-yellow-800'
                            : 'bg-blue-100 text-blue-800'
                        }`}
                      >
                        {rental.status === 'completed'
                          ? 'Zakończone'
                          : rental.status === 'cancelled'
                          ? 'Anulowane'
                          : rental.status === 'pending'
                          ? 'Oczekujące'
                          : 'W trakcie'}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      {rental.total_price.toFixed(2)} zł
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                      <button
                        onClick={() =>
                          navigate(`/admin/panel/reservations/${rental.id}`)
                        }
                        className="text-indigo-600 hover:text-indigo-900"
                      >
                        Szczegóły
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>

      {/* Modal potwierdzenia usunięcia */}
      {showDeleteConfirmation && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg shadow-xl max-w-md w-full mx-4 overflow-hidden">
            <div className="p-6">
              <h3 className="text-xl font-semibold text-gray-900 mb-4">
                Czy na pewno chcesz usunąć tego klienta?
              </h3>
              <div className="bg-red-50 p-4 rounded-lg mb-6">
                <p className="text-red-800 font-medium mb-2">UWAGA:</p>
                <p className="text-red-700 text-sm">
                  Ta operacja jest nieodwracalna. Wszystkie dane klienta,
                  włącznie z historią transakcji, zostaną trwale usunięte bez
                  możliwości przywrócenia.
                </p>
              </div>
              <div className="flex justify-end gap-3">
                <button
                  onClick={() => setShowDeleteConfirmation(false)}
                  className="px-4 py-2 text-gray-700 bg-gray-100 rounded-lg hover:bg-gray-200 transition-colors"
                >
                  Anuluj
                </button>
                <button
                  onClick={handleDelete}
                  className="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors"
                >
                  Tak, usuń
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Modal potwierdzenia blokady */}
      {showBlockConfirmation && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg shadow-xl max-w-md w-full mx-4 overflow-hidden">
            <div className="p-6">
              <h3 className="text-xl font-semibold text-gray-900 mb-4">
                Czy na pewno chcesz zablokować tego klienta?
              </h3>
              <div className="bg-yellow-50 p-4 rounded-lg mb-4">
                <p className="text-yellow-800 font-medium mb-2">UWAGA:</p>
                <p className="text-yellow-700 text-sm">
                  Zablokowany klient nie będzie mógł tworzyć nowych rezerwacji.
                  Istniejące rezerwacje pozostaną bez zmian.
                </p>
              </div>
              <div className="mb-4">
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Powód blokady
                </label>
                <textarea
                  value={blockReason}
                  onChange={(e) => setBlockReason(e.target.value)}
                  className="w-full px-3 py-2 border rounded-lg"
                  rows={3}
                  placeholder="Podaj powód blokady..."
                />
              </div>
              <div className="flex justify-end gap-3">
                <button
                  onClick={() => {
                    setShowBlockConfirmation(false);
                    setBlockReason('');
                  }}
                  className="px-4 py-2 text-gray-700 bg-gray-100 rounded-lg hover:bg-gray-200 transition-colors"
                >
                  Anuluj
                </button>
                <button
                  onClick={handleBlock}
                  disabled={!blockReason.trim()}
                  className="px-4 py-2 bg-yellow-600 text-white rounded-lg hover:bg-yellow-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  Zablokuj
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {error && (
        <div className="fixed bottom-4 right-4 bg-red-50 text-red-700 px-4 py-3 rounded-lg shadow-lg flex items-center">
          <AlertTriangle className="w-5 h-5 mr-2" />
          <span>{error}</span>
        </div>
      )}
    </div>
  );
};

export default CustomerProfile;
