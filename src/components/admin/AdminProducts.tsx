import React, { useState, useEffect } from 'react';
import { Plus, Edit, Trash2, Save, Loader2 } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { motion } from 'framer-motion';
import AdminProductModal from './AdminProductModal';
import ExportProducts from './ExportProducts';

interface Equipment {
  id: string;
  name: string;
  description: string;
  price: number;
  deposit: number;
  image: string;
  categories: string[];
  quantity: number;
  specifications?: Array<{
    id: string;
    key: string;
    value: string;
  }>;
  features?: Array<{
    id: string;
    text: string;
  }>;
  variants?: Array<{
    id: string;
    name: string;
    price: number;
  }>;
}

const AdminProducts: React.FC = () => {
  const [equipment, setEquipment] = useState<Equipment[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedProduct, setSelectedProduct] = useState<Equipment | null>(null);
  const [showModal, setShowModal] = useState(false);

  useEffect(() => {
    loadEquipment();
  }, []);

  const loadEquipment = async () => {
    try {
      setIsLoading(true);
      const { data, error } = await supabase
        .from('equipment')
        .select(`
          *,
          specifications (*),
          features (*),
          variants (*)
        `)
        .order('name');

      if (error) throw error;
      setEquipment(data || []);
      setError(null);
    } catch (err) {
      console.error('Error loading equipment:', err);
      setError('Nie udało się załadować sprzętu');
    } finally {
      setIsLoading(false);
    }
  };

  const handleSave = async (product: Equipment) => {
    try {
      setIsLoading(true);

      if (product.id) {
        // Update existing product
        const { error } = await supabase
          .from('equipment')
          .update({
            name: product.name,
            description: product.description,
            price: product.price,
            deposit: product.deposit,
            image: product.image,
            categories: product.categories,
            quantity: product.quantity
          })
          .eq('id', product.id);

        if (error) throw error;

        // Update specifications
        if (product.specifications) {
          await supabase
            .from('specifications')
            .delete()
            .eq('equipment_id', product.id);

          await supabase
            .from('specifications')
            .insert(
              product.specifications.map(spec => ({
                ...spec,
                equipment_id: product.id
              }))
            );
        }

        // Update features
        if (product.features) {
          await supabase
            .from('features')
            .delete()
            .eq('equipment_id', product.id);

          await supabase
            .from('features')
            .insert(
              product.features.map(feature => ({
                ...feature,
                equipment_id: product.id
              }))
            );
        }

        // Update variants
        if (product.variants) {
          await supabase
            .from('variants')
            .delete()
            .eq('equipment_id', product.id);

          await supabase
            .from('variants')
            .insert(
              product.variants.map(variant => ({
                ...variant,
                equipment_id: product.id
              }))
            );
        }
      } else {
        // Create new product
        const { data: newProduct, error } = await supabase
          .from('equipment')
          .insert({
            name: product.name,
            description: product.description,
            price: product.price,
            deposit: product.deposit,
            image: product.image,
            categories: product.categories,
            quantity: product.quantity
          })
          .select()
          .single();

        if (error) throw error;

        // Add specifications
        if (product.specifications?.length) {
          await supabase
            .from('specifications')
            .insert(
              product.specifications.map(spec => ({
                ...spec,
                equipment_id: newProduct.id
              }))
            );
        }

        // Add features
        if (product.features?.length) {
          await supabase
            .from('features')
            .insert(
              product.features.map(feature => ({
                ...feature,
                equipment_id: newProduct.id
              }))
            );
        }

        // Add variants
        if (product.variants?.length) {
          await supabase
            .from('variants')
            .insert(
              product.variants.map(variant => ({
                ...variant,
                equipment_id: newProduct.id
              }))
            );
        }
      }

      await loadEquipment();
      setShowModal(false);
    } catch (err) {
      console.error('Error saving product:', err);
      setError('Nie udało się zapisać produktu');
    } finally {
      setIsLoading(false);
    }
  };

  const handleDelete = async (id: string) => {
    if (!window.confirm('Czy na pewno chcesz usunąć ten produkt?')) return;

    try {
      setIsLoading(true);
      const { error } = await supabase
        .from('equipment')
        .delete()
        .eq('id', id);

      if (error) throw error;
      await loadEquipment();
    } catch (err) {
      console.error('Error deleting product:', err);
      setError('Nie udało się usunąć produktu');
    } finally {
      setIsLoading(false);
    }
  };

  if (isLoading) {
    return (
      <div className="flex justify-center items-center h-64">
        <Loader2 className="w-8 h-8 text-solrent-orange animate-spin" />
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-red-50 p-4 rounded-lg text-red-700">
        <p>{error}</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h2 className="text-2xl font-semibold text-gray-900">Zarządzanie sprzętem</h2>
        <div className="flex gap-4">
          <ExportProducts equipmentData={equipment} />
          <button
            onClick={() => {
              setSelectedProduct(null);
              setShowModal(true);
            }}
            className="px-4 py-2 bg-solrent-orange text-white rounded-lg hover:bg-orange-700 flex items-center gap-2"
          >
            <Plus className="w-5 h-5" />
            Dodaj sprzęt
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {equipment.map(item => (
          <motion.div
            key={item.id}
            layout
            className="bg-white rounded-lg shadow-lg overflow-hidden"
          >
            <div className="h-48 bg-gray-200 relative">
              <img
                src={item.image}
                alt={item.name}
                className="w-full h-full object-contain"
              />
            </div>
            <div className="p-4">
              <h3 className="text-lg font-medium text-gray-900">{item.name}</h3>
              <p className="text-sm text-gray-500 mt-1 line-clamp-2">{item.description}</p>
              <div className="mt-4 flex justify-between items-center">
                <div>
                  <p className="text-lg font-bold text-solrent-orange">{item.price} zł/dzień</p>
                  {item.deposit > 0 && (
                    <p className="text-sm text-gray-600">Kaucja: {item.deposit} zł</p>
                  )}
                </div>
                <div className="flex space-x-2">
                  <button
                    onClick={() => {
                      setSelectedProduct(item);
                      setShowModal(true);
                    }}
                    className="p-2 text-blue-600 hover:bg-blue-50 rounded-lg"
                  >
                    <Edit className="w-5 h-5" />
                  </button>
                  <button
                    onClick={() => handleDelete(item.id)}
                    className="p-2 text-red-600 hover:bg-red-50 rounded-lg"
                  >
                    <Trash2 className="w-5 h-5" />
                  </button>
                </div>
              </div>
            </div>
          </motion.div>
        ))}
      </div>

      <AdminProductModal
        product={selectedProduct}
        isOpen={showModal}
        onClose={() => setShowModal(false)}
        onSave={handleSave}
      />
    </div>
  );
};

export default AdminProducts;