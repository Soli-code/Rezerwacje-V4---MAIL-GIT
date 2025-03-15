import React, { useState, useEffect } from 'react';
import { Calendar, ChevronLeft, ChevronRight, AlertCircle, Clock, Info, ArrowRight, Loader2, RotateCcw } from 'lucide-react';
import { getDay } from 'date-fns';
import { 
  checkAvailability, 
  getNextAvailableDate, 
  getReservationsInRange,
  formatShortDate,
  formatTime,
  formatDateTime,
  isSaturdayAfterCutoff,
  calculateRentalDays
} from '../../lib/availability';
import { motion, AnimatePresence } from 'framer-motion';

interface DatePickerProps {
  startDate: Date | null;
  endDate: Date | null;
  startTime: string | null;
  endTime: string | null;
  onChange: (startDate: Date | null, endDate: Date | null, startTime: string | null, endTime: string | null) => void;
  selectedEquipment: Array<{
    id: string;
    name: string;
    quantity: number;
  }>;
}

const DAYS = ['Pon', 'Wt', 'Śr', 'Czw', 'Pt', 'Sob', 'Nie'];
const MONTHS = [
  'Styczeń', 'Luty', 'Marzec', 'Kwiecień', 'Maj', 'Czerwiec',
  'Lipiec', 'Sierpień', 'Wrzesień', 'Październik', 'Listopad', 'Grudzień'
];

const DatePicker: React.FC<DatePickerProps> = ({
  startDate,
  endDate,
  startTime,
  endTime,
  onChange,
  selectedEquipment
}) => {
  const [currentMonth, setCurrentMonth] = useState(new Date());
  const [selectionStep, setSelectionStep] = useState(1);
  const [showTimeModal, setShowTimeModal] = useState(false);
  const [unavailableDates, setUnavailableDates] = useState<Map<string, string>>(new Map());
  const [isCheckingAvailability, setIsCheckingAvailability] = useState(false);
  const [availableEndTimes, setAvailableEndTimes] = useState<string[]>([]);
  const [selectedDateTemp, setSelectedDateTemp] = useState<Date | null>(null);
  const [errorMessage, setErrorMessage] = useState<string>('');
  const [showMonthYearSelector, setShowMonthYearSelector] = useState(false);
  const [reservations, setReservations] = useState<Map<string, any[]>>(new Map());
  const [autoMonthChange, setAutoMonthChange] = useState(false);

  const today = new Date();
  today.setHours(0, 0, 0, 0);
  
  const handleReset = () => {
    onChange(null, null, null, null);
    setSelectionStep(1);
    setSelectedDateTemp(null);
    setErrorMessage('');
    setShowTimeModal(false);
  };

  const getTooltipContent = (date: Date): string => {
    const reservedEquipment: string[] = [];

    selectedEquipment.forEach(item => {
      const itemReservations = reservations.get(item.id) || [];
      const conflictingReservations = itemReservations.filter(reservation => {
        const reservationStart = new Date(reservation.start_date);
        const reservationEnd = new Date(reservation.end_date);
        reservationStart.setHours(0, 0, 0, 0);
        reservationEnd.setHours(23, 59, 59, 999);
        const testDate = new Date(date);
        testDate.setHours(0, 0, 0, 0);
        return testDate >= reservationStart && testDate <= reservationEnd;
      });

      conflictingReservations.forEach(reservation => {
        const endDate = new Date(reservation.end_date);
        reservedEquipment.push(
          `${reservation.equipment_name} - zarezerwowany do: ${formatDateTime(endDate)}`
        );
      });
    });

    return reservedEquipment.join('\n');
  };

  useEffect(() => {
    const checkMonthAvailability = async () => {
      if (selectedEquipment.length === 0) {
        setUnavailableDates(new Map());
        return;
      }

      setIsCheckingAvailability(true);
      const startOfMonth = new Date(currentMonth.getFullYear(), currentMonth.getMonth(), 1);
      const endOfMonth = new Date(currentMonth.getFullYear(), currentMonth.getMonth() + 1, 0);

      try {
        const equipmentIds = selectedEquipment.map(item => item.id);
        const reservationsMap = await getReservationsInRange(
          equipmentIds,
          startOfMonth,
          endOfMonth
        );

        const unavailableDatesMap = new Map<string, string>();
        
        for (let d = new Date(startOfMonth); d <= endOfMonth; d.setDate(d.getDate() + 1)) {
          const dateKey = d.toISOString().split('T')[0];
          const testDate = new Date(d);
          testDate.setHours(0, 0, 0, 0);

          for (const item of selectedEquipment) {
            const itemReservations = reservationsMap.get(item.id) || [];
            const isReserved = itemReservations.some(reservation => {
              const reservationStart = new Date(reservation.start_date);
              const reservationEnd = new Date(reservation.end_date);
              reservationStart.setHours(0, 0, 0, 0);
              reservationEnd.setHours(23, 59, 59, 999);
              return testDate >= reservationStart && testDate <= reservationEnd;
            });

            if (isReserved) {
              const nextDate = await getNextAvailableDate(item.id, testDate);
              unavailableDatesMap.set(dateKey,
                `${item.name} jest zarezerwowany do: ${formatDateTime(nextDate)}`
              );
              break;
            }
          }
        }

        setUnavailableDates(unavailableDatesMap);
        setReservations(reservationsMap);
      } catch (error) {
        console.error('Error checking month availability:', error);
        setErrorMessage('Wystąpił błąd podczas sprawdzania dostępności. Spróbuj ponownie później.');
      } finally {
        setIsCheckingAvailability(false);
      }
    };

    checkMonthAvailability();
  }, [currentMonth, selectedEquipment]);

  const getTimeOptions = () => {
    if (selectionStep === 1) {
      const baseOptions = Array.from({ length: 9 }, (_, i) => 
        `${(i + 8).toString().padStart(2, '0')}:00`
      );
      
      // Ogranicz godziny dla soboty w kroku wyboru daty rozpoczęcia
      if (selectedDateTemp && selectedDateTemp.getDay() === 6) {
        return baseOptions.filter(time => {
          const hour = parseInt(time.split(':')[0], 10);
          return hour <= 13;
        });
      }
      
      return baseOptions;
    }

    return availableEndTimes;
  };

  const calculateAvailableEndTimes = (date: Date) => {
    const baseEndTimes = Array.from({ length: 9 }, (_, i) => 
      `${(i + 8).toString().padStart(2, '0')}:00`
    );

    if (!startDate || !startTime) {
      return [];
    }

    const isSameDay = date.toDateString() === startDate.toDateString();
    const isSelectedDateSaturday = date.getDay() === 6;
    const startHour = parseInt(startTime.split(':')[0], 10);

    return baseEndTimes.filter(time => {
      const hour = parseInt(time.split(':')[0], 10);
      
      // Filtruj godziny dla soboty
      if (isSelectedDateSaturday && hour > 13) {
        return false;
      }

      // Filtruj godziny dla tego samego dnia
      if (isSameDay && hour <= startHour) {
        return false;
      }

      return true;
    });
  };

  const isTimeDisabled = (time: string): boolean => {
    if (selectionStep === 1) {
      return false;
    }
    
    return !availableEndTimes.includes(time);
  };

  const isDateInRange = (date: Date) => {
    if (!startDate || !endDate) return false;
    const testDate = new Date(date);
    testDate.setHours(0, 0, 0, 0);
    const rangeStart = new Date(startDate);
    rangeStart.setHours(0, 0, 0, 0);
    const rangeEnd = new Date(endDate);
    rangeEnd.setHours(23, 59, 59, 999);
    return testDate >= rangeStart && testDate <= rangeEnd;
  };

  const validateTimeRange = (start: Date, end: Date, startTimeStr: string, endTimeStr: string): boolean => {
    const [startHour] = startTimeStr.split(':').map(Number);
    const [endHour] = endTimeStr.split(':').map(Number);

    const startDateTime = new Date(start);
    const endDateTime = new Date(end);
    startDateTime.setHours(startHour, 0, 0, 0);
    endDateTime.setHours(endHour, 0, 0, 0);

    if (endDateTime <= startDateTime) {
      setErrorMessage('Data zakończenia musi być późniejsza niż data rozpoczęcia.');
      return false;
    }

    if (startHour < 8 || startHour > 16 || endHour < 8 || endHour > 16) {
      setErrorMessage('Rezerwacje są możliwe tylko w godzinach 8:00-16:00.');
      return false;
    }

    return true;
  };

  const handleDateClick = async (date: Date | null) => {
    if (!date || isDateDisabled(date)) return;

    // Oblicz dostępne godziny zakończenia dla kroku 2
    if (selectionStep === 2) {
      const endTimes = calculateAvailableEndTimes(date);
      if (endTimes.length === 0) {
        setErrorMessage('Brak dostępnych godzin zakończenia dla wybranej daty');
        return;
      }
      setAvailableEndTimes(endTimes);
    }

    const checkDateRange = selectionStep === 2;
    setSelectedDateTemp(date);
    setShowTimeModal(true);
    setErrorMessage('');

    if (selectionStep === 1) {
      onChange(null, null, null, null);
      
      setIsCheckingAvailability(true);
      try {
        for (const item of selectedEquipment) {
          const testDate = new Date(date);
          const isAvailable = await checkAvailability(item.id, testDate, testDate, false);
          if (!isAvailable) {
            const nextDate = await getNextAvailableDate(item.id, testDate);
            setErrorMessage(
              `${item.name} jest zarezerwowany do: ${formatDateTime(nextDate)}`
            );
            setSelectedDateTemp(null);
            setShowTimeModal(false);
            return;
          }
        }
      } catch (error) {
        console.error('Error checking availability:', error);
        setErrorMessage('Wystąpił błąd podczas sprawdzania dostępności.');
        setSelectedDateTemp(null);
        setShowTimeModal(false);
      } finally {
        setIsCheckingAvailability(false);
      }
    } else if (selectionStep === 2) {
      setIsCheckingAvailability(true);
      try {
        if (startDate) {
          const testStartDate = new Date(startDate);
          testStartDate.setHours(0, 0, 0, 0);
          const testEndDate = new Date(date);
          testEndDate.setHours(23, 59, 59, 999);
          
          // Sprawdź dostępność w całym zakresie dat
          for (const item of selectedEquipment) {
            const isAvailable = await checkAvailability(item.id, testStartDate, testEndDate, true);
            if (!isAvailable) {
              const nextDate = await getNextAvailableDate(item.id, testStartDate);
              setErrorMessage(
                `${item.name} jest niedostępny w wybranym okresie. Następna dostępność od: ${formatDateTime(nextDate)}`
              );
              setSelectedDateTemp(null);
              setShowTimeModal(false);
              return;
            }
          }
        }
      } catch (error) {
        console.error('Error checking range availability:', error);
        setErrorMessage('Wystąpił błąd podczas sprawdzania dostępności.');
        setSelectedDateTemp(null);
        setShowTimeModal(false);
      } finally {
        setIsCheckingAvailability(false);
      }
    }
  };

  const handleTimeSelection = (time: string) => {
    if (selectionStep === 1) {
      onChange(selectedDateTemp, null, time, null);
      setAvailableEndTimes([]);
      setSelectionStep(2);
    } else if (selectionStep === 2 && startDate && startTime) {
      if (!validateTimeRange(startDate, selectedDateTemp!, startTime, time)) {
        return;
      }
      onChange(startDate, selectedDateTemp, startTime, time);
      setSelectionStep(1);
    }
    setShowTimeModal(false);
  };

  interface ModalContent {
    title: string;
    message: string;
    type: 'info' | 'error' | 'success';
  }

  const [modalContent, setModalContent] = useState<ModalContent | null>(null);
  const [showModal, setShowModal] = useState(false);

  const Modal = ({ content }: { content: ModalContent }) => (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg p-6 max-w-md w-full mx-4">
        <h3 className={`text-lg font-medium mb-4 ${
          content.type === 'error' ? 'text-red-600' :
          content.type === 'success' ? 'text-green-600' :
          'text-blue-600'
        }`}>
          {content.title}
        </h3>
        <p className="text-gray-700 mb-6">{content.message}</p>
        <button
          onClick={() => setShowModal(false)}
          className="w-full px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200"
        >
          OK
        </button>
      </div>
    </div>
  );

  const isDateDisabled = (date: Date | null) => {
    if (!date) return true;
    
    const testDate = new Date(date);
    testDate.setHours(0, 0, 0, 0);
    
    // Sprawdź czy to sobota po godzinie 13:00
    if (testDate < today || date.getDay() === 0 || isSaturdayAfterCutoff(date)) return true;
    
    if (selectionStep === 2 && startDate) {
      const startDateCopy = new Date(startDate);
      startDateCopy.setHours(0, 0, 0, 0);
      
      // Blokuj daty wcześniejsze niż data rozpoczęcia
      if (testDate < startDateCopy) {
        return true;
      }
    }
    
    const dateKey = testDate.toISOString().split('T')[0];
    return unavailableDates.has(dateKey);
  };

  const formatDate = (date: Date | null) => {
    if (!date) return '';
    return date.toLocaleDateString('pl-PL', {
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    });
  };

  const getStepTitle = () => {
    switch (selectionStep) {
      case 1:
        return 'Wybierz datę rozpoczęcia wypożyczenia';
      case 2:
        return 'Wybierz datę zakończenia wypożyczenia';
      default:
        return '';
    }
  };

  const renderProgressIndicator = () => {
    return (
      <div className="flex items-center justify-center mb-4">
        {[1, 2].map((step) => (
          <div
            key={step}
            className={`w-3 h-3 rounded-full mx-1 ${
              step === selectionStep ? 'bg-solrent-orange' : 'bg-gray-300'
            }`}
          />
        ))}
      </div>
    );
  };

  const renderCalendar = () => {
    const year = currentMonth.getFullYear();
    const month = currentMonth.getMonth();
    const firstDay = new Date(year, month, 1).getDay();
    const daysInMonth = new Date(year, month + 1, 0).getDate();
    const startingDay = firstDay === 0 ? 6 : firstDay - 1;

    const days = [];
    for (let i = 0; i < startingDay; i++) {
      days.push(null);
    }
    for (let i = 1; i <= daysInMonth; i++) {
      days.push(new Date(year, month, i));
    }

    return (
      <div className="relative">
        <div className="grid grid-cols-7 gap-1">
          {DAYS.map(day => (
            <div key={day} className="text-center py-2 text-sm font-medium text-gray-700">
              {day}
            </div>
          ))}
          {days.map((date, index) => {
            if (!date) {
              return (
                <div key={index} className="p-2 text-center text-gray-400" />
              );
            }

            const isDisabled = isDateDisabled(date) || isCheckingAvailability;
            const isSelected = date && (
              (startDate && date.toDateString() === startDate.toDateString()) ||
              (endDate && date.toDateString() === endDate.toDateString())
            );
            const isInDateRange = date && isDateInRange(date);
            const isToday = date.toDateString() === today.toDateString();
            const tooltipContent = getTooltipContent(date);

            return (
              <div
                key={index}
                className={`
                  relative p-2 text-center cursor-pointer transition-all duration-200 group
                  ${isDisabled ? 'bg-gray-100 text-gray-400 cursor-not-allowed' : 'hover:bg-orange-50'}
                  ${isSelected ? 'bg-solrent-orange text-white' : ''}
                  ${isInDateRange ? 'bg-orange-100' : ''}
                  ${isToday ? 'border-2 border-solrent-orange' : ''}
                  ${date.getDay() === 0 ? 'bg-gray-200' : ''} // Sunday styling
                `}
                onClick={() => !isCheckingAvailability && handleDateClick(date)}
              >
                <span className={isSelected ? 'text-white' : ''}>{date.getDate()}</span>
                {isDisabled && !isCheckingAvailability && (
                  <div className="absolute bottom-0 left-1/2 transform -translate-x-1/2 w-1 h-1 bg-gray-400 rounded-full" />
                )}
                {tooltipContent && (
                  <div className="absolute z-50 invisible group-hover:visible bg-gray-800 text-white text-xs rounded py-2 px-3 left-1/2 transform -translate-x-1/2 bottom-full mb-2 min-w-[200px] max-w-[300px] whitespace-pre-line break-words shadow-lg">
                    <div className="relative">
                      {tooltipContent}
                      <div className="absolute bottom-0 left-1/2 transform -translate-x-1/2 translate-y-full w-2 h-2 bg-gray-800 rotate-45" />
                    </div>
                  </div>
                )}
              </div>
            );
          })}
        </div>

        <AnimatePresence>
          {isCheckingAvailability && (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="absolute inset-0 flex items-center justify-center bg-white bg-opacity-90 z-10"
            >
              <div className="flex flex-col items-center space-y-3">
                <Loader2 className="w-8 h-8 text-solrent-orange animate-spin" />
                <p className="text-sm font-medium text-gray-700">Sprawdzanie dostępności...</p>
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    );
  };

  const renderTimeModal = () => {
    if (!showTimeModal) return null;

    const timeOptions = getTimeOptions();

    return (
      <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
        <motion.div
          initial={{ scale: 0.9, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          exit={{ scale: 0.9, opacity: 0 }}
          className="bg-white rounded-lg p-6 max-w-sm w-full mx-4"
        >
          <h3 className="text-lg font-medium text-gray-900 mb-4">
            Wybierz godzinę {selectionStep === 1 ? 'rozpoczęcia' : 'zakończenia'}
          </h3>
          <div className="grid grid-cols-3 gap-2">
            {timeOptions.map(time => {
              const disabled = isTimeDisabled(time);
              return (
                <button
                  key={time}
                  onClick={() => !disabled && handleTimeSelection(time)}
                  className={`px-4 py-2 text-sm font-medium rounded-lg transition-colors ${
                    disabled
                      ? 'bg-gray-100 text-gray-400 cursor-not-allowed'
                      : 'hover:bg-orange-50 focus:outline-none focus:ring-2 focus:ring-orange-500'
                  }`}
                  disabled={disabled}
                >
                  {time}
                </button>
              );
            })}
          </div>
          <button
            onClick={() => setShowTimeModal(false)}
            className="mt-4 w-full px-4 py-2 text-sm font-medium text-gray-700 bg-gray-100 rounded-lg hover:bg-gray-200"
          >
            Anuluj
          </button>
        </motion.div>
      </div>
    );
  };

  return (
    <div className="space-y-6">
      {renderProgressIndicator()}

      <div className="bg-white rounded-lg shadow-sm border p-6">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-xl font-semibold text-gray-800">{getStepTitle()}</h2>
          {(startDate || endDate) && (
            <button
              onClick={handleReset}
              className="flex items-center px-3 py-1.5 text-sm font-medium text-gray-600 bg-gray-100 rounded-lg hover:bg-gray-200 transition-colors"
            >
              <RotateCcw className="w-4 h-4 mr-1.5" />
              Resetuj datę
            </button>
          )}
        </div>

        <div className="flex items-center justify-between mb-4">
          <button
            onClick={() => setCurrentMonth(new Date(currentMonth.setMonth(currentMonth.getMonth() - 1)))}
            className="p-2 rounded-full hover:bg-gray-100"
            disabled={currentMonth.getMonth() === today.getMonth() && currentMonth.getFullYear() === today.getFullYear()}
          >
            <ChevronLeft className="w-5 h-5" />
          </button>
          <button
            onClick={() => setShowMonthYearSelector(!showMonthYearSelector)}
            className="text-lg font-medium"
          >
            {MONTHS[currentMonth.getMonth()]} {currentMonth.getFullYear()}
          </button>
          <button
            onClick={() => setCurrentMonth(new Date(currentMonth.setMonth(currentMonth.getMonth() + 1)))}
            className="p-2 rounded-full hover:bg-gray-100"
          >
            <ChevronRight className="w-5 h-5" />
          </button>
        </div>

        {renderCalendar()}

        {errorMessage && (
          <div className="mt-4 p-4 bg-red-50 rounded-lg flex items-start">
            <AlertCircle className="w-5 h-5 text-red-500 mt-0.5 mr-2 flex-shrink-0" />
            <p className="text-red-700 text-sm">{errorMessage}</p>
          </div>
        )}

        {showModal && modalContent && (
          <Modal content={modalContent} />
        )}

        {(startDate || endDate) && (
          <div className="mt-4 p-4 bg-orange-50 rounded-lg">
            <h3 className="font-medium text-solrent-dark mb-2">Wybrane terminy:</h3>
            {startDate && (
              <p className="text-sm">
                Rozpoczęcie: {formatDate(startDate)} {startTime}
              </p>
            )}
            {endDate && (
              <p className="text-sm">
                Zakończenie: {formatDate(endDate)} {endTime} {
                  startDate && endDate && (
                    <span className={`font-medium ${
                      calculateRentalDays(startDate, endDate, startTime, endTime) >= 7 ? 'text-green-600' : 'text-gray-900'
                    }`}>
                      ({calculateRentalDays(startDate, endDate, startTime, endTime)} dni)
                    </span>
                  )
                }
              </p>
            )}
          </div>
        )}
      </div>

      <div className="bg-blue-50 p-4 rounded-lg">
        <div className="flex items-start">
          <Info className="w-5 h-5 text-blue-500 mt-0.5 mr-2" />
          <div>
            <p className="text-sm text-blue-700">
              <strong>Godziny otwarcia:</strong>
            </p>
            <ul className="text-sm text-blue-600 mt-1">
              <li>Poniedziałek - Piątek: 8:00 - 16:00</li>
              <li>Sobota: 8:00 - 13:00</li>
              <li>Niedziela: nieczynne</li>
            </ul>
          </div>
        </div>
      </div>

      <AnimatePresence>
        {renderTimeModal()}
      </AnimatePresence>
    </div>
  );
};

export default DatePicker;