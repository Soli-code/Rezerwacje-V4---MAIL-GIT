import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '../../lib/supabase';
import { ChevronLeft, ChevronRight, Download } from 'lucide-react';
import { motion } from 'framer-motion';

interface Equipment {
  id: string;
  name: string;
}

interface Reservation {
  id: string;
  customer: {
    first_name: string;
    last_name: string;
  };
  start_date: string;
  end_date: string;
  start_time: string;
  end_time: string;
  status: string;
}

const DAYS = ['PON', 'WT', 'ŚR', 'CZW', 'PT', 'SOB', 'NIEDZ'];

const ReservationCalendar: React.FC = () => {
  const navigate = useNavigate();
  const [equipment, setEquipment] = useState<Equipment[]>([]);
  const [reservations, setReservations] = useState<Reservation[]>([]);
  const [currentDate, setCurrentDate] = useState(new Date());
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadEquipment();
    loadReservations();
  }, [currentDate]);

  const loadEquipment = async () => {
    const { data, error } = await supabase
      .from('equipment')
      .select('id, name')
      .order('name');

    if (error) {
      console.error('Error loading equipment:', error);
      return;
    }

    setEquipment(data || []);
  };

  const loadReservations = async () => {
    const startOfMonth = new Date(currentDate.getFullYear(), currentDate.getMonth(), 1);
    const endOfMonth = new Date(currentDate.getFullYear(), currentDate.getMonth() + 1, 0);

    const { data, error } = await supabase
      .from('reservations')
      .select(`
        id,
        customer:customers (
          first_name,
          last_name
        ),
        start_date,
        end_date,
        start_time,
        end_time,
        status,
        reservation_items!inner (
          equipment_id
        )
      `)
      .gte('start_date', startOfMonth.toISOString())
      .lte('end_date', endOfMonth.toISOString())
      .neq('status', 'cancelled');

    if (error) {
      console.error('Error loading reservations:', error);
      return;
    }

    setReservations(data || []);
    setLoading(false);
  };

  const getDaysInMonth = () => {
    const year = currentDate.getFullYear();
    const month = currentDate.getMonth();
    return new Date(year, month + 1, 0).getDate();
  };

  const getReservationSpan = (reservation: Reservation, monthStart: Date, monthEnd: Date) => {
    const start = new Date(reservation.start_date);
    const end = new Date(reservation.end_date);
    
    // Ustaw początek na 1. dzień miesiąca jeśli rezerwacja zaczyna się wcześniej
    const startDay = start < monthStart ? 1 : start.getDate();
    
    // Ustaw koniec na ostatni dzień miesiąca jeśli rezerwacja kończy się później
    const endDay = end > monthEnd ? monthEnd.getDate() : end.getDate();
    
    return {
      startDay,
      endDay,
      span: endDay - startDay + 1
    };
  };

  const formatDateTime = (date: string, time: string) => {
    const d = new Date(date);
    return `${d.getDate()}.${(d.getMonth() + 1)} ${time}`;
  };

  const formatCustomerName = (firstName: string, lastName: string) => {
    // Zwróć tylko pierwsze 4 litery nazwiska
    return `${lastName} ${firstName}`;
  };

  const formatShortCell = (lastName: string, date: string) => {
    // Zwróć pierwsze 4 litery nazwiska i dzień miesiąca
    return `${lastName.substring(0, 4)}\n${new Date(date).getDate()}`;
  };

  const formatDateRange = (startDate: string, endDate: string, startTime: string, endTime: string) => {
    const start = new Date(startDate);
    const end = new Date(endDate);
    const days = Math.ceil((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24));

    // Dla rezerwacji 4+ dni
    if (days >= 4) {
      return `${start.getDate()}.${start.getMonth() + 1} ${startTime} - ${end.getDate()}.${end.getMonth() + 1} ${endTime}`;
    }
    
    // Dla rezerwacji 2-3 dni
    return `${start.getDate()}-${end.getDate()}`;
  };

  const getReservationContent = (reservation: Reservation, cellWidth: number, isMultiDay: boolean) => {
    const lastName = reservation.customer.last_name;
    const firstName = reservation.customer.first_name;
    const startDate = new Date(reservation.start_date);
    const endDate = new Date(reservation.end_date);
    const days = Math.ceil((endDate.getTime() - startDate.getTime()) / (1000 * 60 * 60 * 24));

    // Dla rezerwacji 4+ dni
    if (days >= 4) {
      const customerName = formatCustomerName(firstName, lastName);
      const dateRange = formatDateRange(reservation.start_date, reservation.end_date, reservation.start_time, reservation.end_time);
      return `${customerName}\n${dateRange}`;
    } 
    
    // Dla rezerwacji 2-3 dni
    if (days >= 2 && days <= 3) {
      const dateRange = formatDateRange(reservation.start_date, reservation.end_date, reservation.start_time, reservation.end_time);
      const customerName = cellWidth < 100 
        ? `${lastName} ${firstName[0]}.`
        : `${lastName} ${firstName}`;
      return `${customerName}\n${dateRange}`;
    }

    // Dla rezerwacji jednodniowych
    return `${lastName}\n${startDate.getDate()}`;
  };

  const getReservationStyle = (reservation: Reservation, isMultiDay: boolean) => {
    const baseStyle = "absolute inset-1 rounded p-1.5 cursor-pointer transition-all duration-300 text-sm flex flex-col items-center justify-center";
    
    const days = Math.ceil((new Date(reservation.end_date).getTime() - new Date(reservation.start_date).getTime()) / (1000 * 60 * 60 * 24));
    
    if (days >= 4) {
      return `${baseStyle} bg-gradient-to-r from-indigo-100 to-blue-50 hover:from-indigo-200 hover:to-blue-100 text-center font-medium`;
    }
    
    if (days >= 2) {
      return `${baseStyle} bg-gradient-to-r from-blue-100 to-blue-50 hover:from-blue-200 hover:to-blue-100 text-center font-medium`;
    }
    
    return `${baseStyle} bg-blue-50 hover:bg-blue-100 font-medium text-center`;
  };

  const renderHeader = () => {
    const days = Array.from({ length: getDaysInMonth() }, (_, i) => i + 1);
    
    return (
      <div className="grid grid-cols-[200px_1fr] border-b">
        <div className="p-4 font-medium text-gray-700 border-r">Nazwa sprzętu</div>
        <div className="overflow-x-auto">
          <div className="grid grid-cols-31 min-w-[1240px]">
            {days.map(day => {
              const date = new Date(currentDate.getFullYear(), currentDate.getMonth(), day);
              const dayName = DAYS[date.getDay() === 0 ? 6 : date.getDay() - 1];
              return (
                <div key={day} className="p-2 text-center border-r last:border-r-0">
                  <div className="font-bold text-lg">{day}</div>
                  <div className="text-sm text-gray-500">{dayName}</div>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    );
  };

  return (
    <div className="bg-white rounded-lg shadow overflow-hidden">
      <div className="p-4 border-b flex items-center justify-between">
        <div className="flex items-center space-x-4">
          <button
            onClick={() => setCurrentDate(new Date(currentDate.setMonth(currentDate.getMonth() - 1)))}
            className="p-3 md:p-2 hover:bg-gray-100 rounded-full touch-manipulation"
          >
            <ChevronLeft className="w-5 h-5" />
          </button>
          <h2 className="text-lg md:text-xl font-semibold">
            {currentDate.toLocaleString('pl-PL', { month: 'long', year: 'numeric' })}
          </h2>
          <button
            onClick={() => setCurrentDate(new Date(currentDate.setMonth(currentDate.getMonth() + 1)))}
            className="p-3 md:p-2 hover:bg-gray-100 rounded-full touch-manipulation"
          >
            <ChevronRight className="w-5 h-5" />
          </button>
        </div>
        <button
          onClick={() => {/* TODO: Implement export */}}
          className="hidden md:flex items-center px-4 py-2 bg-gray-100 rounded-lg hover:bg-gray-200"
        >
          <Download className="w-5 h-5 mr-2" />
          Eksportuj
        </button>
      </div>

      {loading ? (
        <div className="p-8 text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-solrent-orange mx-auto"></div>
          <p className="mt-4 text-gray-500">Ładowanie kalendarza...</p>
        </div>
      ) : (
        <div className="overflow-x-auto relative touch-pan-x">
          {renderHeader()}
          <div className="grid grid-cols-[120px_1fr] md:grid-cols-[200px_1fr] relative">
            <div className="border-r">
              {equipment.map(item => (
                <div key={item.id} className="p-2 md:p-4 border-b last:border-b-0 h-[60px] flex items-center">
                  <div className="text-xs md:text-base line-clamp-2 break-words min-w-[100px] md:min-w-[180px] max-w-full">
                    {item.name}
                  </div>
                </div>
              ))}
            </div>
            <div className="overflow-x-auto relative">
              <div className="min-w-[calc(100vw-120px)] md:min-w-[1240px]">
                {equipment.map(item => (
                  <div key={item.id} className="grid grid-cols-31 border-b last:border-b-0 h-[60px]">
                    {Array.from({ length: getDaysInMonth() }).map((_, dayIndex) => {
                      const itemReservations = reservations.filter(r => 
                        r.reservation_items.some(ri => ri.equipment_id === item.id)
                      );

                      const monthStart = new Date(currentDate.getFullYear(), currentDate.getMonth(), 1);
                      const monthEnd = new Date(currentDate.getFullYear(), currentDate.getMonth() + 1, 0);

                      // Znajdź rezerwację, która powinna być wyświetlona w tej komórce
                      const reservation = itemReservations.find(r => {
                        const { startDay, endDay } = getReservationSpan(r, monthStart, monthEnd);
                        return dayIndex + 1 >= startDay && dayIndex + 1 <= endDay;
                      });

                      // Jeśli znaleziono rezerwację, sprawdź czy to jej pierwszy dzień
                      if (reservation) {
                        const { startDay, span } = getReservationSpan(reservation, monthStart, monthEnd);
                        const isMultiDay = span > 1;
                        const cellWidth = Math.floor(1240 / getDaysInMonth()); // Przybliżona szerokość komórki

                        if (dayIndex + 1 === startDay) {
                          return (
                            <div
                              key={dayIndex}
                              className="relative"
                              style={{ gridColumn: `span ${span}` }}
                            >
                              <div
                                onClick={() => navigate(`/admin/panel/customer/${reservation.id}`)}
                                className={`${getReservationStyle(reservation, isMultiDay)} min-h-[44px] touch-manipulation`}
                              >
                                <div className="text-[10px] md:text-xs whitespace-pre-line font-medium">
                                  {getReservationContent(reservation, cellWidth, isMultiDay)}
                                </div>
                                {isMultiDay && (
                                  <>
                                    <div className="absolute left-0 top-1/2 -translate-y-1/2 -ml-1">
                                      <div className="w-2 h-2 bg-blue-300 rounded-full" />
                                    </div>
                                    <div className="absolute right-0 top-1/2 -translate-y-1/2 -mr-1">
                                      <div className="w-2 h-2 bg-blue-300 rounded-full" />
                                    </div>
                                  </>
                                )}
                              </div>
                            </div>
                          );
                        }
                        return null; // Nie renderuj komórki jeśli jest częścią połączonej rezerwacji
                      }

                      return <div key={dayIndex} className="border-r last:border-r-0 h-[60px]" />;
                    })}
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default ReservationCalendar;