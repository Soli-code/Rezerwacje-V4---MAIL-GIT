import React, { useState, useEffect, useRef } from 'react';
import { ChevronUp, ChevronDown, X, ArrowRight, ArrowLeft, Trash2 } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { calculateRentalDays } from '../../lib/availability';
import Modal from './Modal';

interface CollapsibleSummaryProps {
  reservation: {
    equipment: Array<{
      id: string;
      name: string;
      quantity: number;
      price: number;
    }>;
    startDate: Date | null;
    endDate: Date | null;
    startTime: string | null;
    endTime: string | null;
  };
  onRemoveItem: (id: string) => void;
  onRemoveAll: () => void;
  currentStep: number;
  onNext: () => void;
  onPrev: () => void;
}

const CollapsibleSummary: React.FC<CollapsibleSummaryProps> = ({
  reservation,
  onRemoveItem,
  onRemoveAll,
  currentStep,
  onNext,
  onPrev
}) => {
  const [isCollapsed, setIsCollapsed] = useState(false);
  const [showDeleteConfirmation, setShowDeleteConfirmation] = useState(false);
  const summaryRef = useRef<HTMLDivElement>(null);
  const { startDate, endDate } = reservation;
  const [userInteracted, setUserInteracted] = useState(false);
  const prevEquipmentLength = useRef(reservation.equipment.length);

  const getStoredCollapseState = (step: number): boolean => {
    const stored = localStorage.getItem(`summaryCollapsed_${step}`);
    return stored ? JSON.parse(stored) : step > 0;
  };

  // Śledź zmiany w liczbie produktów
  useEffect(() => {
    // Nie zmieniaj stanu jeśli użytkownik już wchodził w interakcję z panelem
    if (!userInteracted) {
      const newState = currentStep === 0 ? false : true;
      setIsCollapsed(newState);
    }
    prevEquipmentLength.current = reservation.equipment.length;
  }, [currentStep]);

  // Inicjalizacja początkowego stanu
  useEffect(() => {
    if (!userInteracted) {
      const initialState = getStoredCollapseState(currentStep);
      setIsCollapsed(initialState);
    }
  }, []);

  // Zachowaj stan po usunięciu produktu
  useEffect(() => {
    if (userInteracted && prevEquipmentLength.current !== reservation.equipment.length) {
      // Nie zmieniaj stanu zwinięcia przy usuwaniu produktów
      prevEquipmentLength.current = reservation.equipment.length;
    }
  }, [reservation.equipment.length]);

  const toggleCollapse = () => {
    const newState = !isCollapsed;
    setIsCollapsed(newState);
    setUserInteracted(true);
    if (currentStep !== 0) { // Zapisuj stan tylko dla kroków innych niż pierwszy
      localStorage.setItem(`summaryCollapsed_${currentStep}`, JSON.stringify(newState));
    }
  };

  const handleDeleteAll = () => {
    setShowDeleteConfirmation(true);
  };

  const confirmDeleteAll = () => {
    onRemoveAll();
    setShowDeleteConfirmation(false);
  };

  const calculateTotal = () => {
    const days = calculateDays();
    return reservation.equipment.reduce((sum, item) => {
      const price = days >= 7 && item.promotional_price ? item.promotional_price : item.price;
      return sum + (price * item.quantity);
    }, 0);
  };

  const calculateDays = () => {
    if (!startDate || !endDate || !reservation.startTime || !reservation.endTime) {
      return 0;
    }
    return calculateRentalDays(startDate, endDate, reservation.startTime, reservation.endTime);
  };

  if (currentStep === 3) return null;
  if (reservation.equipment.length === 0) return null;

  return (
    <>
      <div 
        onClick={(e) => {
          // Zapobiegaj zwijaniu przy kliknięciu w przyciski
          if (!(e.target as HTMLElement).closest('button')) {
            toggleCollapse();
          }
        }}
        ref={summaryRef}
        className="fixed bottom-0 left-0 right-0 bg-white border-t shadow-lg fixed-summary transition-all duration-300"
      >
        <div className="max-w-4xl mx-auto relative">
          {/* Toggle button */}
          <div
            onClick={toggleCollapse}
            className="absolute -top-8 right-4 bg-white rounded-t-lg border border-b-0 px-3 py-1 shadow-sm hover:bg-gray-50 transition-colors"
          >
            <motion.div
              animate={{ rotate: isCollapsed ? 0 : 180 }}
              transition={{ duration: 0.3 }}
            >
              <ChevronUp className="w-5 h-5 text-gray-600" />
            </motion.div>
          </div>

          {/* Header - always visible */}
          <div className="px-4 py-2 flex items-center justify-between border-b">
            <div className="flex items-center justify-between flex-1">
              <div className="flex items-center gap-2 md:gap-4">
                <div className="flex items-center gap-2">
                  <span className="text-sm text-gray-600">
                    Wybrane: {reservation.equipment.length}
                  </span>
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      handleDeleteAll();
                    }}
                    className="flex items-center gap-1 text-red-600 hover:text-red-700 text-xs md:text-sm py-1 px-1.5 md:px-2 rounded transition-colors"
                  >
                    <Trash2 className="w-4 h-4" />
                    <span className="hidden md:inline">Usuń wszystkie</span>
                    <span className="md:hidden">Usuń</span>
                  </button>
                </div>
              </div>
              <div className="flex items-center gap-4">
                <div className="text-right">
                  <span className="text-sm text-gray-600">Suma:</span>
                  <div className="font-bold text-solrent-orange">                    
                    {calculateDays() >= 7 && reservation.equipment.some(item => item.promotional_price) ? (
                      <>
                        <span className="text-sm line-through text-gray-500">
                          {reservation.equipment.reduce((sum, item) => sum + (item.price * item.quantity), 0)} zł/dzień
                        </span>
                        <span className="block font-bold text-green-600">
                          {calculateTotal()} zł/dzień
                        </span>
                      </>
                    ) : (
                      <span>{calculateTotal()} zł/dzień</span>
                    )}
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  {currentStep > 0 && (
                    <button
                      onClick={onPrev}
                      className="md:px-4 md:py-2 px-3 py-1.5 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 flex items-center gap-1 md:gap-2 text-sm md:text-base"
                    >
                      <ArrowLeft className="w-4 h-4 md:w-5 md:h-5" />
                      <span className="hidden md:inline">Wstecz</span>
                    </button>
                  )}
                  <button
                    onClick={onNext}
                    className="md:px-4 md:py-2 px-3 py-1.5 bg-solrent-orange text-white rounded-lg hover:bg-orange-700 flex items-center gap-1 md:gap-2 text-sm md:text-base"
                  >
                    <span className="hidden md:inline">Dalej</span>
                    <ArrowRight className="w-4 h-4 md:w-5 md:h-5" />
                  </button>
                </div>
              </div>
            </div>
          </div>

          {/* Collapsible content */}
          <AnimatePresence>
            {!isCollapsed && (
              <motion.div
                initial={{ height: 0, opacity: 0 }}
                animate={{ height: 'auto', opacity: 1 }}
                exit={{ height: 0, opacity: 0 }}
                transition={{ duration: 0.3 }}
                className="overflow-hidden"
              >
                <div className="p-4 space-y-4">
                  {/* Equipment list */}
                  <div className="grid grid-cols-2 md:flex md:flex-wrap gap-2">
                    {reservation.equipment.map(item => (
                      <div
                        key={item.id}
                        className="flex items-center bg-orange-50 text-solrent-orange px-2 md:px-3 py-1.5 rounded-lg md:rounded-full text-xs md:text-sm"
                      >
                        <span className="flex-1 truncate">
                          {item.name.includes('/') ? (
                            <span className="inline-flex flex-col">
                              <span className="truncate">{item.name.split('/')[0].trim()}</span>
                              <span className="truncate">{item.name.split('/')[1].trim()}</span>
                            </span>
                          ) : (
                            item.name
                          )}
                          <span className="ml-1 font-medium">x{item.quantity}</span>
                        </span>
                        <button
                          onClick={() => onRemoveItem(item.id)}
                          className="ml-1 md:ml-2 p-1 rounded-full hover:bg-orange-100 transition-colors flex-shrink-0"
                        >
                          <X className="w-4 h-4" />
                        </button>
                      </div>
                    ))}
                  </div>
                </div>
              </motion.div>
            )}
          </AnimatePresence>
        </div>
      </div>

      {/* Delete Confirmation Modal */}
      <Modal
        isOpen={showDeleteConfirmation}
        onClose={() => setShowDeleteConfirmation(false)}
        title="Potwierdzenie usunięcia" 
        className="modal-overlay"
      >
        <div className="text-center">
          <p className="mb-6 text-gray-700">
            Czy na pewno chcesz usunąć wszystkie produkty?
          </p>
          <div className="flex justify-center gap-4">
            <button
              onClick={() => setShowDeleteConfirmation(false)}
              className="px-4 py-2 bg-gray-200 text-gray-700 rounded hover:bg-gray-300 transition-colors"
            >
              Anuluj
            </button>
            <button
              onClick={confirmDeleteAll}
              className="px-4 py-2 bg-[#FF0000] text-white rounded hover:bg-[#CC0000] transition-colors"
            >
              Usuń wszystko
            </button>
          </div>
        </div>
      </Modal>
    </>
  );
};

export default CollapsibleSummary;