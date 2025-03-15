import React, { useState, useEffect, useRef } from 'react';
import { supabase } from '../../lib/supabase';
import FullCalendar from '@fullcalendar/react';
import dayGridPlugin from '@fullcalendar/daygrid';
import timeGridPlugin from '@fullcalendar/timegrid';
import listPlugin from '@fullcalendar/list';
import interactionPlugin from '@fullcalendar/interaction';
import { Filter, Download, Edit2, X, Check, AlertTriangle } from 'lucide-react';
import { jsPDF } from 'jspdf';
import 'jspdf-autotable';
import plLocale from '@fullcalendar/core/locales/pl';

interface Reservation {
  id: string;
  customer_id: string;
  start_date: string;
  end_date: string;
  start_time: string;
  end_time: string;
  total_price: number;
  status: 'pending' | 'confirmed' | 'cancelled' | 'completed';
  customer: {
    first_name: string;
    last_name: string;
    email: string;
    phone: string;
  };
  items: Array<{
    equipment: {
      name: string;
    };
    quantity: number;
  }>;
}

const AdminCalendar: React.FC = () => {
  const [reservations, setReservations] = useState<Reservation[]>([]);
  const [selectedStatus, setSelectedStatus] = useState<string[]>(['confirmed', 'pending']);
  const [selectedEvent, setSelectedEvent] = useState<Reservation | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const calendarRef = useRef<FullCalendar>(null);

  useEffect(() => {
    loadReservations();
  }, [selectedStatus]);

  const loadReservations = async () => {
    try {
      setIsLoading(true);
      const { data, error } = await supabase
        .from('reservations')
        .select(`
          *,
          customer:customers (
            first_name,
            last_name,
            email,
            phone
          ),
          items:reservation_items (
            quantity,
            equipment:equipment (
              name
            )
          )
        `)
        .in('status', selectedStatus);

      if (error) throw error;
      setReservations(data || []);
    } catch (err) {
      console.error('Error loading reservations:', err);
      setError('Nie udało się załadować rezerwacji');
    } finally {
      setIsLoading(false);
    }
  };

  const handleStatusChange = async (reservationId: string, newStatus: string) => {
    try {
      const { error } = await supabase
        .from('reservations')
        .update({ status: newStatus })
        .eq('id', reservationId);

      if (error) throw error;

      // Wyślij powiadomienie email
      await supabase.functions.invoke('send-status-notification', {
        body: { reservationId, newStatus }
      });

      await loadReservations();
      setSelectedEvent(null);
    } catch (err) {
      console.error('Error updating reservation:', err);
      setError('Nie udało się zaktualizować statusu rezerwacji');
    }
  };

  const getEventColor = (status: string) => {
    switch (status) {
      case 'confirmed': return '#22c55e'; // green
      case 'pending': return '#f59e0b'; // yellow
      case 'cancelled': return '#ef4444'; // red
      case 'completed': return '#3b82f6'; // blue
      default: return '#6b7280'; // gray
    }
  };

  const exportToPDF = () => {
    const doc = new jsPDF();
    const tableColumn = ['Data', 'Klient', 'Sprzęt', 'Status', 'Wartość'];
    const tableRows: any[] = [];

    reservations.forEach(reservation => {
      const equipmentList = reservation.items
        .map(item => `${item.equipment.name} (${item.quantity}x)`)
        .join(', ');

      tableRows.push([
        `${new Date(reservation.start_date).toLocaleDateString()} ${reservation.start_time}`,
        `${reservation.customer.first_name} ${reservation.customer.last_name}`,
        equipmentList,
        reservation.status,
        `${reservation.total_price} zł`
      ]);
    });

    (doc as any).autoTable({
      head: [tableColumn],
      body: tableRows,
      startY: 20,
      theme: 'grid',
      styles: { fontSize: 8, cellPadding: 2 },
      headStyles: { fillColor: [255, 107, 0] }
    });

    doc.save('rezerwacje.pdf');
  };

  const exportToCSV = () => {
    const csvContent = reservations.map(reservation => {
      const equipmentList = reservation.items
        .map(item => `${item.equipment.name} (${item.quantity}x)`)
        .join('; ');

      return [
        new Date(reservation.start_date).toLocaleDateString(),
        reservation.start_time,
        new Date(reservation.end_date).toLocaleDateString(),
        reservation.end_time,
        `${reservation.customer.first_name} ${reservation.customer.last_name}`,
        reservation.customer.email,
        reservation.customer.phone,
        equipmentList,
        reservation.status,
        `${reservation.total_price} zł`
      ].join(',');
    }).join('\n');

    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = 'rezerwacje.csv';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const renderEventContent = (eventInfo: any) => {
    const reservation = reservations.find(r => r.id === eventInfo.event.id);
    if (!reservation) return null;

    return (
      <div className="p-1 overflow-hidden">
        <div className="font-medium text-sm truncate">
          {reservation.customer.first_name} {reservation.customer.last_name}
        </div>
        <div className="text-xs truncate">
          {reservation.items.map(item => item.equipment.name).join(', ')}
        </div>
      </div>
    );
  };

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <div className="flex items-center space-x-4">
          <div className="relative">
            <button
              className="px-4 py-2 bg-white border rounded-lg shadow-sm hover:bg-gray-50 flex items-center space-x-2"
              onClick={() => document.getElementById('status-filter')?.click()}
            >
              <Filter className="w-4 h-4" />
              <span>Filtruj status</span>
            </button>
            <select
              id="status-filter"
              multiple
              className="absolute opacity-0 invisible"
              value={selectedStatus}
              onChange={(e) => {
                const values = Array.from(e.target.selectedOptions, option => option.value);
                setSelectedStatus(values);
              }}
            >
              <option value="confirmed">Potwierdzone</option>
              <option value="pending">Oczekujące</option>
              <option value="cancelled">Anulowane</option>
              <option value="completed">Zakończone</option>
            </select>
          </div>
          <div className="flex space-x-2">
            <button
              onClick={exportToPDF}
              className="px-4 py-2 bg-white border rounded-lg shadow-sm hover:bg-gray-50 flex items-center space-x-2"
            >
              <Download className="w-4 h-4" />
              <span>PDF</span>
            </button>
            <button
              onClick={exportToCSV}
              className="px-4 py-2 bg-white border rounded-lg shadow-sm hover:bg-gray-50 flex items-center space-x-2"
            >
              <Download className="w-4 h-4" />
              <span>CSV</span>
            </button>
          </div>
        </div>
      </div>

      <div className="bg-white rounded-lg shadow">
        <FullCalendar
          ref={calendarRef}
          plugins={[dayGridPlugin, timeGridPlugin, listPlugin, interactionPlugin]}
          initialView="dayGridMonth"
          locale={plLocale}
          headerToolbar={{
            left: 'prev,next today',
            center: 'title',
            right: 'dayGridMonth,timeGridWeek,timeGridDay,listWeek'
          }}
          events={reservations.map(reservation => ({
            id: reservation.id,
            title: `${reservation.customer.first_name} ${reservation.customer.last_name}`,
            start: `${reservation.start_date}T${reservation.start_time}`,
            end: `${reservation.end_date}T${reservation.end_time}`,
            backgroundColor: getEventColor(reservation.status),
            borderColor: getEventColor(reservation.status),
            extendedProps: { reservation }
          }))}
          eventContent={renderEventContent}
          eventClick={(info) => {
            setSelectedEvent(info.event.extendedProps.reservation);
          }}
          height="auto"
          slotMinTime="08:00:00"
          slotMaxTime="16:00:00"
          businessHours={{
            daysOfWeek: [1, 2, 3, 4, 5],
            startTime: '08:00',
            endTime: '16:00'
          }}
          selectConstraint="businessHours"
          nowIndicator
          dayMaxEvents={3}
        />
      </div>

      {/* Modal ze szczegółami rezerwacji */}
      {selectedEvent && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg shadow-xl max-w-2xl w-full mx-4">
            <div className="p-6">
              <div className="flex justify-between items-start">
                <h3 className="text-xl font-semibold text-gray-900">
                  Szczegóły rezerwacji
                </h3>
                <button
                  onClick={() => setSelectedEvent(null)}
                  className="text-gray-400 hover:text-gray-500"
                >
                  <X className="w-6 h-6" />
                </button>
              </div>

              <div className="mt-6 space-y-4">
                <div>
                  <h4 className="font-medium text-gray-700">Klient</h4>
                  <p>{selectedEvent.customer.first_name} {selectedEvent.customer.last_name}</p>
                  <p className="text-sm text-gray-500">{selectedEvent.customer.email}</p>
                  <p className="text-sm text-gray-500">{selectedEvent.customer.phone}</p>
                </div>

                <div>
                  <h4 className="font-medium text-gray-700">Termin</h4>
                  <p>
                    {new Date(selectedEvent.start_date).toLocaleDateString()} {selectedEvent.start_time}
                    {' - '}
                    {new Date(selectedEvent.end_date).toLocaleDateString()} {selectedEvent.end_time}
                  </p>
                </div>

                <div>
                  <h4 className="font-medium text-gray-700">Sprzęt</h4>
                  <ul className="list-disc list-inside">
                    {selectedEvent.items.map((item, index) => (
                      <li key={index}>
                        {item.equipment.name} (x{item.quantity})
                      </li>
                    ))}
                  </ul>
                </div>

                <div>
                  <h4 className="font-medium text-gray-700">Status</h4>
                  <div className="flex items-center space-x-2 mt-2">
                    {selectedEvent.status === 'pending' && (
                      <>
                        <button
                          onClick={() => handleStatusChange(selectedEvent.id, 'confirmed')}
                          className="px-3 py-1 bg-green-500 text-white rounded-lg hover:bg-green-600 flex items-center space-x-1"
                        >
                          <Check className="w-4 h-4" />
                          <span>Potwierdź</span>
                        </button>
                        <button
                          onClick={() => handleStatusChange(selectedEvent.id, 'cancelled')}
                          className="px-3 py-1 bg-red-500 text-white rounded-lg hover:bg-red-600 flex items-center space-x-1"
                        >
                          <X className="w-4 h-4" />
                          <span>Anuluj</span>
                        </button>
                      </>
                    )}
                    {selectedEvent.status === 'confirmed' && (
                      <button
                        onClick={() => handleStatusChange(selectedEvent.id, 'completed')}
                        className="px-3 py-1 bg-blue-500 text-white rounded-lg hover:bg-blue-600 flex items-center space-x-1"
                      >
                        <Check className="w-4 h-4" />
                        <span>Zakończ</span>
                      </button>
                    )}
                  </div>
                </div>

                <div className="mt-4 pt-4 border-t">
                  <p className="font-medium text-gray-900">
                    Całkowita wartość: {selectedEvent.total_price} zł
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

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

export default AdminCalendar;