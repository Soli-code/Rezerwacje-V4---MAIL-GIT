import React, { useState, useEffect } from 'react';
import { Plus, Edit, Trash2, Calendar, Monitor, Save } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { motion } from 'framer-motion';

interface Advertisement {
  id: string;
  title: string;
  content: string;
  image_url: string;
  product_id: string;
  start_date: string;
  end_date: string;
  is_active: boolean;
  display_order: number;
  device_type: 'desktop' | 'mobile' | 'all';
}

const AdminAdvertisements: React.FC = () => {
  const [ads, setAds] = useState<Advertisement[]>([]);
  const [editingAd, setEditingAd] = useState<Advertisement | null>(null);
  const [products, setProducts] = useState<Array<{ id: string; name: string }>>([]);
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    fetchAds();
    fetchProducts();
  }, []);

  const fetchAds = async () => {
    const { data, error } = await supabase
      .from('advertisements')
      .select('*')
      .order('display_order', { ascending: true });

    if (error) {
      console.error('Error fetching ads:', error);
      return;
    }

    setAds(data || []);
  };

  const fetchProducts = async () => {
    const { data, error } = await supabase
      .from('equipment')
      .select('id, name');

    if (error) {
      console.error('Error fetching products:', error);
      return;
    }

    setProducts(data || []);
  };

  const handleSave = async (ad: Advertisement) => {
    setIsLoading(true);
    try {
      if (ad.id) {
        // Aktualizacja istniejącej reklamy
        const { error } = await supabase
          .from('advertisements')
          .update({
            title: ad.title,
            content: ad.content,
            image_url: ad.image_url,
            product_id: ad.product_id,
            start_date: ad.start_date,
            end_date: ad.end_date,
            is_active: ad.is_active,
            device_type: ad.device_type,
            display_order: ad.display_order
          })
          .eq('id', ad.id);

        if (error) throw error;
      } else {
        // Dodawanie nowej reklamy
        const { error } = await supabase
          .from('advertisements')
          .insert([{
            ...ad,
            display_order: ads.length
          }]);

        if (error) throw error;
      }

      await fetchAds();
      setEditingAd(null);
    } catch (error) {
      console.error('Error saving ad:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const handleDelete = async (id: string) => {
    if (!window.confirm('Czy na pewno chcesz usunąć tę reklamę?')) return;

    const { error } = await supabase
      .from('advertisements')
      .delete()
      .eq('id', id);

    if (error) {
      console.error('Error deleting ad:', error);
      return;
    }

    await fetchAds();
  };

  return (
    <div className="p-6">
      <div className="flex justify-between items-center mb-6">
        <h2 className="text-2xl font-semibold text-gray-900">Zarządzanie reklamami</h2>
        <button
          onClick={() => setEditingAd({
            id: '',
            title: '',
            content: '',
            image_url: '',
            product_id: '',
            start_date: new Date().toISOString(),
            end_date: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
            is_active: true,
            display_order: ads.length,
            device_type: 'all'
          })}
          className="flex items-center px-4 py-2 bg-solrent-orange text-white rounded-lg hover:bg-orange-700"
        >
          <Plus className="w-5 h-5 mr-2" />
          Dodaj reklamę
        </button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {ads.map(ad => (
          <motion.div
            key={ad.id}
            layout
            className="bg-white rounded-lg shadow-lg overflow-hidden"
          >
            {ad.image_url && (
              <img
                src={ad.image_url}
                alt={ad.title}
                className="w-full h-48 object-cover"
              />
            )}
            <div className="p-4">
              <h3 className="font-medium text-lg mb-2">{ad.title}</h3>
              <p className="text-gray-600 text-sm mb-4">{ad.content}</p>
              
              <div className="flex items-center text-sm text-gray-500 mb-2">
                <Calendar className="w-4 h-4 mr-2" />
                <span>
                  {new Date(ad.start_date).toLocaleDateString()} - {new Date(ad.end_date).toLocaleDateString()}
                </span>
              </div>
              
              <div className="flex items-center text-sm text-gray-500 mb-4">
                <Monitor className="w-4 h-4 mr-2" />
                <span>
                  {ad.device_type === 'all' ? 'Wszystkie urządzenia' :
                   ad.device_type === 'desktop' ? 'Tylko desktop' : 'Tylko mobile'}
                </span>
              </div>

              <div className="flex justify-end space-x-2">
                <button
                  onClick={() => setEditingAd(ad)}
                  className="p-2 text-blue-600 hover:bg-blue-50 rounded-lg"
                >
                  <Edit className="w-5 h-5" />
                </button>
                <button
                  onClick={() => handleDelete(ad.id)}
                  className="p-2 text-red-600 hover:bg-red-50 rounded-lg"
                >
                  <Trash2 className="w-5 h-5" />
                </button>
              </div>
            </div>
          </motion.div>
        ))}
      </div>

      {/* Modal edycji/dodawania */}
      {editingAd && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-lg w-full max-w-2xl">
            <div className="p-6">
              <h3 className="text-xl font-medium mb-4">
                {editingAd.id ? 'Edytuj reklamę' : 'Dodaj nową reklamę'}
              </h3>
              
              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Tytuł
                  </label>
                  <input
                    type="text"
                    value={editingAd.title}
                    onChange={e => setEditingAd({...editingAd, title: e.target.value})}
                    className="w-full px-3 py-2 border rounded-lg"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Treść
                  </label>
                  <textarea
                    value={editingAd.content}
                    onChange={e => setEditingAd({...editingAd, content: e.target.value})}
                    className="w-full px-3 py-2 border rounded-lg"
                    rows={3}
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    URL obrazu
                  </label>
                  <input
                    type="text"
                    value={editingAd.image_url}
                    onChange={e => setEditingAd({...editingAd, image_url: e.target.value})}
                    className="w-full px-3 py-2 border rounded-lg"
                  />
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Data rozpoczęcia
                    </label>
                    <input
                      type="datetime-local"
                      value={editingAd.start_date.slice(0, 16)}
                      onChange={e => setEditingAd({...editingAd, start_date: new Date(e.target.value).toISOString()})}
                      className="w-full px-3 py-2 border rounded-lg"
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Data zakończenia
                    </label>
                    <input
                      type="datetime-local"
                      value={editingAd.end_date.slice(0, 16)}
                      onChange={e => setEditingAd({...editingAd, end_date: new Date(e.target.value).toISOString()})}
                      className="w-full px-3 py-2 border rounded-lg"
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Powiązany produkt
                  </label>
                  <select
                    value={editingAd.product_id}
                    onChange={e => setEditingAd({...editingAd, product_id: e.target.value})}
                    className="w-full px-3 py-2 border rounded-lg"
                  >
                    <option value="">Brak</option>
                    {products.map(product => (
                      <option key={product.id} value={product.id}>
                        {product.name}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Typ urządzenia
                  </label>
                  <select
                    value={editingAd.device_type}
                    onChange={e => setEditingAd({...editingAd, device_type: e.target.value as 'desktop' | 'mobile' | 'all'})}
                    className="w-full px-3 py-2 border rounded-lg"
                  >
                    <option value="all">Wszystkie urządzenia</option>
                    <option value="desktop">Tylko desktop</option>
                    <option value="mobile">Tylko mobile</option>
                  </select>
                </div>

                <div className="flex items-center">
                  <input
                    type="checkbox"
                    checked={editingAd.is_active}
                    onChange={e => setEditingAd({...editingAd, is_active: e.target.checked})}
                    className="h-4 w-4 text-solrent-orange rounded border-gray-300"
                  />
                  <label className="ml-2 text-sm text-gray-700">
                    Aktywna
                  </label>
                </div>
              </div>

              <div className="mt-6 flex justify-end space-x-3">
                <button
                  onClick={() => setEditingAd(null)}
                  className="px-4 py-2 text-gray-700 bg-gray-100 rounded-lg hover:bg-gray-200"
                >
                  Anuluj
                </button>
                <button
                  onClick={() => handleSave(editingAd)}
                  disabled={isLoading}
                  className="px-4 py-2 bg-solrent-orange text-white rounded-lg hover:bg-orange-700 flex items-center"
                >
                  <Save className="w-5 h-5 mr-2" />
                  {isLoading ? 'Zapisywanie...' : 'Zapisz'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default AdminAdvertisements;