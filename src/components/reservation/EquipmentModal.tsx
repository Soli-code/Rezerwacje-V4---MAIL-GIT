import React from 'react';
import { X, Package } from 'lucide-react';
import { Equipment } from '../../lib/equipment';

interface EquipmentModalProps {
  equipment: Equipment | null;
  onClose: () => void;
  onAddToCart: (item: Equipment) => void;
  onRemoveFromCart: (id: string) => void;
  isInCart: boolean;
}

const EquipmentModal: React.FC<EquipmentModalProps> = ({
  equipment,
  onClose,
  onAddToCart,
  onRemoveFromCart,
  isInCart
}) => {
  if (!equipment) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-lg shadow-xl max-w-3xl w-full max-h-[90vh] overflow-y-auto">
        <div className="flex justify-between items-center p-4 border-b">
          <h2 className="text-xl font-semibold text-gray-800">{equipment.name}</h2>
          <button 
            onClick={onClose}
            className="p-1 rounded-full hover:bg-gray-100"
          >
            <X className="w-6 h-6 text-gray-500" />
          </button>
        </div>
        
        <div className="p-6">
          <div className="flex flex-col md:flex-row gap-6">
            <div className="w-full md:w-1/3 flex justify-center">
              <img 
                src={equipment.image} 
                alt={equipment.name} 
                className="w-full max-w-[250px] object-contain"
                onError={(e) => {
                  console.error(`Błąd ładowania obrazu w modalu: ${equipment.image}`);
                  e.currentTarget.src = '/assets/placeholder.png'; // Zastępczy obraz
                }}
              />
            </div>
            
            <div className="w-full md:w-2/3">
              <p className="text-gray-700 mb-4">{equipment.description}</p>
              
              <div className="grid grid-cols-2 gap-4 mb-6">
                <div>
                  <h3 className="font-medium text-gray-900">Cena</h3>
                  <p className="text-solrent-orange font-bold">{equipment.price} zł/dzień</p>
                  {equipment.promotional_price && (
                    <p className="text-green-600 text-sm">od 7 dni: {equipment.promotional_price} zł/dzień</p>
                  )}
                </div>
                
                <div>
                  <h3 className="font-medium text-gray-900">Kaucja</h3>
                  <p className="text-gray-700">{equipment.deposit || 0} zł</p>
                </div>
              </div>
              
              {equipment.specifications && equipment.specifications.length > 0 && (
                <div className="mb-6">
                  <h3 className="font-medium text-gray-900 mb-2">Specyfikacja</h3>
                  <ul className="grid grid-cols-1 md:grid-cols-2 gap-2">
                    {equipment.specifications.map(spec => (
                      <li key={spec.id} className="flex items-start">
                        <span className="font-medium mr-2">{spec.key}:</span>
                        <span>{spec.value}</span>
                      </li>
                    ))}
                  </ul>
                </div>
              )}
              
              {equipment.features && equipment.features.length > 0 && (
                <div className="mb-6">
                  <h3 className="font-medium text-gray-900 mb-2">Cechy</h3>
                  <ul className="list-disc pl-5 space-y-1">
                    {equipment.features.map(feature => (
                      <li key={feature.id}>{feature.text}</li>
                    ))}
                  </ul>
                </div>
              )}
            </div>
          </div>
        </div>
        
        <div className="p-4 border-t flex justify-end">
          {isInCart ? (
            <button
              onClick={() => onRemoveFromCart(equipment.id)}
              className="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors"
            >
              Usuń z koszyka
            </button>
          ) : (
            <button
              onClick={() => onAddToCart(equipment)}
              className="px-4 py-2 bg-solrent-orange text-white rounded-lg hover:bg-orange-700 transition-colors flex items-center gap-2"
            >
              <Package className="w-4 h-4" />
              Dodaj do koszyka
            </button>
          )}
        </div>
      </div>
    </div>
  );
};

export default EquipmentModal;