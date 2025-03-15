import React, { useState, useEffect } from 'react';
import { Package, Plus, Minus, Save, Edit, Trash2, X } from 'lucide-react';
import { checkIsAdmin } from '../../lib/supabase';
import { getEquipment, addEquipment, updateEquipment, deleteEquipment, subscribeToEquipmentUpdates, Equipment } from '../../lib/equipment';
import EquipmentModal from './EquipmentModal';

const EquipmentSelector = ({ selectedEquipment, onChange, onNext }) => {
  const [activeCategory, setActiveCategory] = useState('wszystkie');
  const [searchTerm, setSearchTerm] = useState('');
  const [equipmentData, setEquipmentData] = useState([]);
  const [showAdminPanel, setShowAdminPanel] = useState(false);
  const [editingItem, setEditingItem] = useState(null);
  const [isAdmin, setIsAdmin] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);
  const [selectedModalItem, setSelectedModalItem] = useState(null);
  const [newItem, setNewItem] = useState({
    name: '',
    description: '',
    price: '',
    deposit: '',
    image: '',
    categories: ['budowlany']
  });

  useEffect(() => {
    const checkAdmin = async () => {
      const isUserAdmin = await checkIsAdmin();
      setIsAdmin(isUserAdmin);
    };
    checkAdmin();
  }, []);

  useEffect(() => {
    const loadEquipment = async () => {
      try {
        setIsLoading(true);
        console.log('Rozpoczynam ładowanie sprzętu...');
        const data = await getEquipment();
        console.log('Pobrane dane sprzętu:', data);
        if (data.length > 0) {
          setEquipmentData(data);
          setError(null);
        } else {
          setError('Brak dostępnego sprzętu.');
        }
      } catch (err) {
        console.error('Error loading equipment:', err);
        setError(
          err instanceof Error 
            ? err.message 
            : 'Nie udało się załadować sprzętu. Spróbuj odświeżyć stronę.'
        );
      } finally {
        setIsLoading(false);
      }
    };

    loadEquipment();

    const unsubscribe = subscribeToEquipmentUpdates((updatedEquipment) => {
      setEquipmentData(prevData => 
        prevData.map(item => 
          item.id === updatedEquipment.id ? updatedEquipment : item
        )
      );
    });

    return () => {
      unsubscribe();
    };
  }, []);

  const categories = [
    { id: 'wszystkie', name: 'Wszystkie' },
    { id: 'budowlany', name: 'Sprzęt budowlany' },
    { id: 'ogrodniczy', name: 'Sprzęt ogrodniczy' }
  ];

  const filteredEquipment = equipmentData.filter(item => {
    const matchesCategory = activeCategory === 'wszystkie' || item.categories.includes(activeCategory);
    const matchesSearch = item.name.toLowerCase().includes(searchTerm.toLowerCase()) || 
                         item.description.toLowerCase().includes(searchTerm.toLowerCase());
    return matchesCategory && matchesSearch;
  });

  const getItemQuantity = (itemId) => {
    const item = selectedEquipment.find(i => i.id === itemId);
    return item ? item.quantity : 0;
  };

  const handleQuantityChange = async (item, newQuantity) => {
    if (newQuantity < 0 || newQuantity > item.quantity) return;

    const existingItem = selectedEquipment.find(i => i.id === item.id);
    
    if (existingItem) {
      if (newQuantity === 0) {
        onChange(selectedEquipment.filter(i => i.id !== item.id));
      } else {
        onChange(selectedEquipment.map(i => 
          i.id === item.id ? { ...i, quantity: newQuantity } : i
        ));
      }
    } else if (newQuantity > 0) {
      onChange([...selectedEquipment, { ...item, quantity: newQuantity }]);
    }
  };

  const handleNewItemChange = (e) => {
    const { name, value } = e.target;
    
    if (name === 'categories') {
      setNewItem({
        ...newItem,
        categories: [value]
      });
    } else if (name === 'price' || name === 'deposit') {
      const numericValue = value.replace(/[^0-9]/g, '');
      setNewItem({
        ...newItem,
        [name]: numericValue
      });
    } else {
      setNewItem({
        ...newItem,
        [name]: value
      });
    }
  };

  const handleAddNewItem = async () => {
    if (!newItem.name || !newItem.description || !newItem.price || !newItem.image) {
      alert('Proszę wypełnić wszystkie pola');
      return;
    }

    try {
      const itemToAdd = {
        ...newItem,
        price: parseInt(newItem.price, 10),
        deposit: parseInt(newItem.deposit, 10) || 0
      };

      const addedItem = await addEquipment(itemToAdd);
      setEquipmentData([...equipmentData, addedItem]);
      
      setNewItem({
        name: '',
        description: '',
        price: '',
        deposit: '',
        image: '',
        categories: ['budowlany']
      });
    } catch (err) {
      console.error('Error adding equipment:', err);
      alert('Nie udało się dodać sprzętu. Spróbuj ponownie.');
    }
  };

  const handleEditItem = (item) => {
    setEditingItem({
      ...item,
      price: item.price.toString(),
      deposit: (item.deposit || '').toString()
    });
  };

  const handleEditItemChange = (e) => {
    const { name, value } = e.target;
    
    if (name === 'categories') {
      setEditingItem({
        ...editingItem,
        categories: [value]
      });
    } else if (name === 'price' || name === 'deposit') {
      const numericValue = value.replace(/[^0-9]/g, '');
      setEditingItem({
        ...editingItem,
        [name]: numericValue
      });
    } else {
      setEditingItem({
        ...editingItem,
        [name]: value
      });
    }
  };

  const handleSaveEdit = async () => {
    if (!editingItem.name || !editingItem.description || !editingItem.price || !editingItem.image) {
      alert('Proszę wypełnić wszystkie pola');
      return;
    }

    try {
      const updatedItem = {
        ...editingItem,
        price: parseInt(editingItem.price, 10),
        deposit: parseInt(editingItem.deposit, 10) || 0
      };

      const savedItem = await updateEquipment(editingItem.id, updatedItem);
      setEquipmentData(
        equipmentData.map(item => 
          item.id === savedItem.id ? savedItem : item
        )
      );
      
      setEditingItem(null);
    } catch (err) {
      console.error('Error updating equipment:', err);
      alert('Nie udało się zaktualizować sprzętu. Spróbuj ponownie.');
    }
  };

  const handleDeleteItem = async (itemId) => {
    if (window.confirm('Czy na pewno chcesz usunąć ten przedmiot?')) {
      try {
        await deleteEquipment(itemId);
        setEquipmentData(equipmentData.filter(item => item.id !== itemId));
        onChange(selectedEquipment.filter(item => item.id !== itemId));
      } catch (err) {
        console.error('Error deleting equipment:', err);
        alert('Nie udało się usunąć sprzętu. Spróbuj ponownie.');
      }
    }
  };

  if (isLoading) {
    return (
      <div className="flex justify-center items-center py-12">
        <div className="text-gray-600">Ładowanie sprzętu...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-red-50 p-4 rounded-lg text-red-700">
        {error}
      </div>
    );
  }

  const isItemInCart = (itemId: string) => {
    return selectedEquipment.some(item => item.id === itemId);
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-xl font-semibold text-gray-800">Wybierz sprzęt</h2>
        <div className="flex items-center space-x-4">
          <div className="flex items-center space-x-2">
            <Package className="w-5 h-5 text-solrent-orange" />
            <span className="text-sm text-gray-600">
              Wybrano: {selectedEquipment.reduce((sum, item) => sum + item.quantity, 0)} szt.
            </span>
          </div>
          {isAdmin && (
            <button 
              onClick={() => setShowAdminPanel(!showAdminPanel)}
              className="px-3 py-1 text-sm bg-gray-200 hover:bg-gray-300 rounded-lg"
            >
              {showAdminPanel ? 'Ukryj panel' : 'Zarządzaj sprzętem'}
            </button>
          )}
        </div>
      </div>

      {isAdmin && showAdminPanel && (
        <div className="bg-gray-50 p-4 rounded-lg border border-gray-200 mb-6">
          <h3 className="text-lg font-medium text-gray-800 mb-4">Panel zarządzania sprzętem</h3>
          
          <div className="mb-6 p-4 bg-white rounded-lg border border-gray-200">
            <h4 className="font-medium text-gray-700 mb-3">Dodaj nowy sprzęt</h4>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Nazwa</label>
                <input
                  type="text"
                  name="name"
                  value={newItem.name}
                  onChange={handleNewItemChange}
                  className="w-full px-3 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                  placeholder="Nazwa sprzętu"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Kategoria</label>
                <select
                  name="categories"
                  value={newItem.categories[0]}
                  onChange={handleNewItemChange}
                  className="w-full px-3 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                >
                  <option value="budowlany">Sprzęt budowlany</option>
                  <option value="ogrodniczy">Sprzęt ogrodniczy</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Cena (zł/dzień)</label>
                <input
                  type="text"
                  name="price"
                  value={newItem.price}
                  onChange={handleNewItemChange}
                  className="w-full px-3 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                  placeholder="Cena za dzień"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Kaucja (zł)</label>
                <input
                  type="text"
                  name="deposit"
                  value={newItem.deposit}
                  onChange={handleNewItemChange}
                  className="w-full px-3 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                  placeholder="Kwota kaucji"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">URL obrazu</label>
                <input
                  type="text"
                  name="image"
                  value={newItem.image}
                  onChange={handleNewItemChange}
                  className="w-full px-3 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                  placeholder="https://example.com/image.jpg"
                />
              </div>
              <div className="md:col-span-2">
                <label className="block text-sm font-medium text-gray-700 mb-1">Opis</label>
                <textarea
                  name="description"
                  value={newItem.description}
                  onChange={handleNewItemChange}
                  className="w-full px-3 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                  placeholder="Opis sprzętu"
                  rows={2}
                />
              </div>
            </div>
            <div className="flex justify-end">
              <button
                onClick={handleAddNewItem}
                className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
              >
                Dodaj sprzęt
              </button>
            </div>
          </div>

          <div className="mb-4">
            <h4 className="font-medium text-gray-700 mb-3">Edytuj istniejący sprzęt</h4>
            <div className="overflow-x-auto">
              <table className="min-w-full bg-white border border-gray-200 rounded-lg">
                <thead>
                  <tr className="bg-gray-100">
                    <th className="py-2 px-4 border-b text-left">Nazwa</th>
                    <th className="py-2 px-4 border-b text-left">Kategoria</th>
                    <th className="py-2 px-4 border-b text-left">Cena/dzień</th>
                    <th className="py-2 px-4 border-b text-left">Kaucja</th>
                    <th className="py-2 px-4 border-b text-right">Akcje</th>
                  </tr>
                </thead>
                <tbody>
                  {equipmentData.map(item => (
                    <tr key={item.id} className="border-b hover:bg-gray-50">
                      <td className="py-2 px-4">{item.name}</td>
                      <td className="py-2 px-4">
                        {item.categories[0] === 'budowlany' ? 'Sprzęt budowlany' : 'Sprzęt ogrodniczy'}
                      </td>
                      <td className="py-2 px-4">{item.price} zł/dzień</td>
                      <td className="py-2 px-4">{item.deposit || 0} zł</td>
                      <td className="py-2 px-4 text-right">
                        <button
                          onClick={() => handleEditItem(item)}
                          className="p-1 text-blue-600 hover:text-blue-800 mr-2"
                        >
                          <Edit className="w-4 h-4" />
                        </button>
                        <button
                          onClick={() => handleDeleteItem(item.id)}
                          className="p-1 text-red-600 hover:text-red-800"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}

      <div className="flex flex-col md:flex-row gap-4">
        <div className="flex-1">
          <input
            type="text"
            placeholder="Szukaj sprzętu..."
            className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
        </div>
        <div className="grid grid-cols-3 gap-2">
          {categories.map(category => (
            <button
              key={category.id}
              className={`px-2 py-2 rounded-lg text-center text-sm ${
                activeCategory === category.id
                  ? 'bg-solrent-orange text-white'
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              }`}
              onClick={() => setActiveCategory(category.id)}
            >
              {category.name}
            </button>
          ))}
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 md:gap-5 lg:gap-6">
        {filteredEquipment.map((item, index) => {
          const isSelected = getItemQuantity(item.id) > 0;
          const currentQuantity = getItemQuantity(item.id);
          
          console.log(`Renderowanie kafelka dla ${item.name}, URL obrazu: ${item.image}`);
          
          return (
            <div 
              key={item.id} 
              className={`border rounded-lg overflow-hidden flex flex-col md:flex-row transition-all duration-200 cursor-pointer w-full shadow-sm hover:shadow-md ${
                isSelected ? 'bg-[#e6f3ff] border-[#0066cc] border-2' : 'bg-white hover:bg-gray-50'
              }`}
              onClick={() => {
                if (currentQuantity < item.quantity) {
                  handleQuantityChange(item, currentQuantity + 1);
                }
              }}
            >
              <div className="w-full md:w-2/5 h-[180px] relative p-3 flex items-center justify-center border-b md:border-b-0 md:border-r border-gray-100">
                <img 
                  src={item.image} 
                  alt={item.name} 
                  className="w-full h-full object-contain max-h-[160px]"
                  onError={(e) => {
                    console.error(`Błąd ładowania obrazu: ${item.image}`);
                    e.currentTarget.src = '/assets/placeholder.png'; // Zastępczy obraz
                  }}
                />
              </div>
              <div className="w-full md:w-3/5 p-4 flex flex-col justify-between">
                <div className="space-y-2">
                  <h3 className="font-medium text-gray-900 text-base">{item.name}</h3>
                  <p className="text-sm text-gray-600 line-clamp-2">{item.description}</p>
                  <div>
                    {item.deposit > 0 && (
                    <p className="text-sm text-orange-600">Kaucja: {item.deposit} zł</p>
                    )}
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        setSelectedModalItem(item);
                      }}
                      className="mt-2 px-2 py-1 bg-solrent-orange text-white text-sm rounded-lg hover:bg-orange-700 transition-colors flex items-center gap-1"
                      aria-label={`Zobacz szczegóły ${item.name}`}
                    >
                      <Package className="w-4 h-4" />
                      Szczegóły sprzętu
                    </button>
                  </div>
                </div>
                <div className="flex items-center justify-between mt-3">
                  <span className="font-bold text-solrent-orange">
                    <span>{item.price} zł/dzień</span>
                    {item.promotional_price && (
                      <span className="block text-sm text-green-600">
                        od 7 dni: {item.promotional_price} zł/dzień
                      </span>
                    )}
                  </span>
                  <div className="flex items-center space-x-2">
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        handleQuantityChange(item, currentQuantity - 1);
                      }}
                      disabled={currentQuantity === 0}
                      className={`p-1.5 rounded-full transition-all ${
                        currentQuantity === 0
                          ? 'bg-gray-100 text-gray-400 cursor-not-allowed'
                          : 'bg-orange-100 text-solrent-orange hover:bg-orange-200'
                      }`}
                    >
                      <Minus className="w-4 h-4" />
                    </button>
                    <span className="w-6 text-center font-medium">{currentQuantity}</span>
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        handleQuantityChange(item, currentQuantity + 1);
                      }}
                      disabled={currentQuantity >= item.quantity}
                      className={`p-1.5 rounded-full transition-all ${
                        currentQuantity >= item.quantity
                          ? 'bg-gray-100 text-gray-400 cursor-not-allowed'
                          : 'bg-orange-100 text-solrent-orange hover:bg-orange-200'
                      }`}
                      title={item.quantity > 1 ? `Dostępne: ${item.quantity} szt.` : ''}
                    >
                      <Plus className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              </div>
            </div>
          );
        })}
      </div>

      {filteredEquipment.length === 0 && (
        <div className="text-center py-8">
          <p className="text-gray-500">Nie znaleziono sprzętu spełniającego kryteria wyszukiwania.</p>
        </div>
      )}

      <EquipmentModal
        equipment={selectedModalItem}
        onClose={() => setSelectedModalItem(null)}
        onAddToCart={(item) => handleQuantityChange(item, 1)}
        isInCart={selectedModalItem ? isItemInCart(selectedModalItem.id) : false}
        onRemoveFromCart={(id) => handleQuantityChange({ id, quantity: 1 }, 0)}
      />
    </div>
  );
};

export default EquipmentSelector