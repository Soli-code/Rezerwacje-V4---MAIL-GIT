import React, { useState, forwardRef, useImperativeHandle } from 'react';
import { Calendar, Package, User, CheckCircle } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { calculateRentalDays } from '../../lib/availability';
import { sendTemplateEmail, emailTemplates } from '../../lib/email-utils';
import Modal from './Modal';

const Summary = forwardRef(({ reservation, onSubmit }, ref) => {
  const { startDate, endDate, equipment, personalInfo } = reservation;
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState('');
  const [submitSuccess, setSubmitSuccess] = useState(false);
  const [showModal, setShowModal] = useState(false);
  const [modalContent, setModalContent] = useState({
    title: '',
    message: '',
    isError: false
  });

  const calculateDays = () => {
    if (!startDate || !endDate || !reservation.startTime || !reservation.endTime) {
      return 0;
    }
    return calculateRentalDays(startDate, endDate, reservation.startTime, reservation.endTime);
  };

  const calculateTotalPrice = () => {
    const days = calculateDays();
    return equipment.reduce((total, item) => {
      const price = days >= 7 && item.promotional_price ? item.promotional_price : item.price;
      return total + (price * item.quantity * days);
    }, 0);
  };

  const calculateTotalDeposit = () => {
    return equipment.reduce((total, item) => total + ((item.deposit || 0) * item.quantity), 0);
  };

  const formatDate = (date) => {
    if (!date) return '';
    return date.toLocaleDateString('pl-PL', {
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    });
  };

  const handleSubmitReservation = async () => {
    if (isSubmitting || submitSuccess) return;
    
    // Walidacja danych przed wysłaniem
    if (!personalInfo.email || !personalInfo.firstName || !personalInfo.lastName) {
      setSubmitError('Proszę wypełnić wszystkie wymagane pola');
      return;
    }

    setIsSubmitting(true);
    setSubmitError('');
    
    try {
      const startDateTime = new Date(startDate);
      const endDateTime = new Date(endDate);
      const [startHour] = reservation.startTime.split(':').map(Number);
      const [endHour] = reservation.endTime.split(':').map(Number);
      
      startDateTime.setHours(startHour, 0, 0, 0);
      endDateTime.setHours(endHour, 0, 0, 0);

      // Przygotuj szczegółowy opis rezerwowanego sprzętu
      const equipmentDetails = equipment.map(item => 
        `${item.name} (${item.quantity}x)`
      ).join(', ');

      // Sprawdź czy klient już istnieje
      const { data: existingCustomers, error: customerQueryError } = await supabase
        .from('customers')
        .select('id')
        .eq('email', personalInfo.email)
        .maybeSingle();

      if (customerQueryError) throw customerQueryError;

      let customerId;
      const existingCustomer = existingCustomers;

      if (existingCustomer) {
        // Aktualizuj istniejącego klienta
        const { data: updatedCustomer, error: updateError } = await supabase
          .from('customers')
          .update({
            first_name: personalInfo.firstName,
            last_name: personalInfo.lastName,
            phone: personalInfo.phone,
            company_name: personalInfo.companyName || null,
            company_nip: personalInfo.companyNip || null,
            company_street: personalInfo.companyStreet || null,
            company_postal_code: personalInfo.companyPostalCode || null,
            company_city: personalInfo.companyCity || null,
            product_name: equipmentDetails,
            rental_start_date: startDateTime.toISOString(),
            rental_end_date: endDateTime.toISOString(),
            rental_days: calculateDays(),
            total_amount: calculateTotalPrice(),
            deposit_amount: calculateTotalDeposit(),
            comment: personalInfo.comment || null,
            updated_at: new Date().toISOString()
          })
          .eq('id', existingCustomer.id)
          .select()
          .single();

        if (updateError) throw updateError;
        customerId = existingCustomer.id;
      } else {
        // Utwórz nowego klienta
        const { data: newCustomer, error: createError } = await supabase
          .from('customers')
          .insert({
            first_name: personalInfo.firstName,
            last_name: personalInfo.lastName,
            email: personalInfo.email,
            phone: personalInfo.phone,
            company_name: personalInfo.companyName || null,
            company_nip: personalInfo.companyNip || null,
            company_street: personalInfo.companyStreet || null,
            company_postal_code: personalInfo.companyPostalCode || null,
            company_city: personalInfo.companyCity || null,
            product_name: equipmentDetails,
            rental_start_date: startDateTime.toISOString(),
            rental_end_date: endDateTime.toISOString(),
            rental_days: calculateDays(),
            total_amount: calculateTotalPrice(),
            deposit_amount: calculateTotalDeposit(),
            comment: personalInfo.comment || null
          })
          .select()
          .single();

        if (createError) throw createError;
        customerId = newCustomer.id;
      }

      // Utwórz rezerwację
      const { data: reservationData, error: reservationError } = await supabase
        .from('reservations')
        .insert({
          customer_id: customerId,
          start_date: startDateTime.toISOString(),
          end_date: endDateTime.toISOString(),
          start_time: reservation.startTime,
          end_time: reservation.endTime,
          total_price: calculateTotalPrice(),
          status: 'pending',
          comment: personalInfo.comment || null
        })
        .select()
        .single();

      if (reservationError) throw reservationError;

      // Utwórz elementy rezerwacji
      const reservationItems = equipment.map(item => ({
        reservation_id: reservationData.id,
        equipment_id: item.id,
        quantity: item.quantity,
        price_per_day: item.price,
        deposit: item.deposit || 0
      }));

      const { error: itemsError } = await supabase
        .from('reservation_items')
        .insert(reservationItems);

      if (itemsError) throw itemsError;

      // Wyślij email potwierdzający rezerwację
      try {
        // Przygotuj dane dla szablonu
        const equipmentText = equipment
          .map(item => `${item.name} (${item.quantity} szt.) - ${item.price} zł/dzień`)
          .join('\n');

        const templateData = {
          first_name: personalInfo.firstName,
          last_name: personalInfo.lastName,
          start_date: formatDate(startDate),
          start_time: reservation.startTime,
          end_date: formatDate(endDate),
          end_time: reservation.endTime,
          days: calculateDays().toString(),
          equipment: equipmentText,
          total_price: calculateTotalPrice().toString(),
          deposit: calculateTotalDeposit().toString()
        };

        // Wyślij email do klienta
        await sendTemplateEmail({
          recipientEmail: personalInfo.email,
          subject: emailTemplates.newReservation.subject,
          htmlContent: emailTemplates.newReservation.htmlContent,
          templateData
        });

        // Wyślij email do administratora
        await sendTemplateEmail({
          recipientEmail: 'biuro@solrent.pl',
          subject: `Nowa rezerwacja: ${personalInfo.firstName} ${personalInfo.lastName}`,
          htmlContent: emailTemplates.newReservation.htmlContent,
          templateData
        });

        console.log('Emaile z potwierdzeniem rezerwacji wysłane pomyślnie');
        
        // Zapisz status wysłania emaili
        await supabase.from('email_notifications').insert([
          {
            reservation_id: reservationData.id,
            recipient: personalInfo.email,
            type: 'customer',
            status: 'sent'
          },
          {
            reservation_id: reservationData.id,
            recipient: 'biuro@solrent.pl',
            type: 'admin',
            status: 'sent'
          }
        ]);
      } catch (emailError) {
        console.error('Błąd podczas wysyłania emaila z potwierdzeniem rezerwacji:', emailError);
        // Nie rzucamy błędu, aby nie przerywać procesu tworzenia rezerwacji
      }

      setSubmitSuccess(true);
      setModalContent({
        title: 'Rezerwacja potwierdzona',
        message: 'Rezerwacja została pomyślnie utworzona. Na podany adres email zostało wysłane potwierdzenie. Dziękujemy!',
        isError: false
      });
      setShowModal(true);
      onSubmit && onSubmit();
    } catch (error) {
      console.error('Error submitting reservation:', error);
      setSubmitError('Wystąpił błąd podczas zapisywania rezerwacji.');
      setModalContent({
        title: 'Błąd rezerwacji',
        message: 'Przepraszamy, wystąpił błąd podczas tworzenia rezerwacji. Spróbuj ponownie.',
        isError: true
      });
      setShowModal(true);
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleModalClose = () => {
    setShowModal(false);
    if (!modalContent.isError) {
      // Redirect to homepage only on successful reservation
      window.location.href = '/';
    }
  };

  // Expose the handleSubmitReservation method through the ref
  useImperativeHandle(ref, () => ({
    handleSubmitReservation
  }));

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-semibold text-gray-800">Podsumowanie rezerwacji</h2>
        <p className="text-sm text-gray-600 mt-1">
          Sprawdź szczegóły swojej rezerwacji przed potwierdzeniem
        </p>
      </div>

      <div className="space-y-4">
        {/* Dates */}
        <div className="bg-gray-50 p-4 rounded-lg">
          <div className="flex items-start">
            <Calendar className="w-5 h-5 text-solrent-orange mt-0.5 mr-3" />
            <div>
              <h3 className="font-medium text-gray-900">Termin rezerwacji</h3>
              <p className="text-gray-700 mt-1">
                Od: <span className="font-medium">{formatDate(startDate)}</span>
                {reservation.startTime && <span className="font-medium"> {reservation.startTime}</span>}
              </p>
              <p className="text-gray-700">
                Do: <span className="font-medium">{formatDate(endDate)}</span>
                {reservation.endTime && <span className="font-medium"> {reservation.endTime}</span>}
              </p>
              <p className="text-gray-700 mt-1">
                Liczba dni: <span className="font-medium">{calculateDays()}</span>
              </p>
            </div>
          </div>
        </div>

        {/* Equipment */}
        <div className="bg-gray-50 p-4 rounded-lg">
          <div className="flex items-start">
            <Package className="w-5 h-5 text-solrent-orange mt-0.5 mr-3" />
            <div className="w-full">
              <h3 className="font-medium text-gray-900">Wybrany sprzęt</h3>
              <div className="mt-2 space-y-2">
                {equipment.map(item => (
                  <div key={item.id} className="flex justify-between text-gray-700">
                    <div>
                      <span>{item.name} x{item.quantity}</span>
                      {item.promotional_price && calculateDays() >= 7 && (
                        <span className="ml-2 text-sm text-green-600 font-medium">
                          (Cena promocyjna dla wynajmu 7+ dni)
                        </span>
                      )}
                    </div>
                    <div className="text-right">
                      <div>
                        {item.promotional_price && calculateDays() >= 7 ? (
                          <>
                            <span className="font-medium text-green-600">
                              {(item.promotional_price * item.quantity).toFixed(2)} zł/dzień
                            </span>
                            <span className="ml-2 text-sm line-through text-gray-500">
                              {(item.price * item.quantity).toFixed(2)} zł
                            </span>
                          </>
                        ) : (
                          <span className="font-medium">
                            {(item.price * item.quantity).toFixed(2)} zł/dzień
                          </span>
                        )}
                      </div>
                      {item.deposit > 0 && (
                        <div className="text-sm text-orange-600">
                          Kaucja: {item.deposit * item.quantity} zł
                        </div>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>

        {/* Personal Info */}
        <div className="bg-gray-50 p-4 rounded-lg">
          <div className="flex items-start">
            <User className="w-5 h-5 text-solrent-orange mt-0.5 mr-3" />
            <div>
              <h3 className="font-medium text-gray-900">Dane osobowe</h3>
              <p className="text-gray-700 mt-1">
                Imię i nazwisko: <span className="font-medium">{personalInfo.firstName} {personalInfo.lastName}</span>
              </p>
              <p className="text-gray-700">
                Email: <span className="font-medium">{personalInfo.email}</span>
              </p>
              <p className="text-gray-700">
                Telefon: <span className="font-medium">{personalInfo.phone}</span>
              </p>
              {personalInfo.companyName && (
                <div className="mt-4 pt-4 border-t border-gray-200">
                  <h4 className="font-medium text-gray-900">Dane firmy</h4>
                  <p className="text-gray-700 mt-1">
                    Nazwa: <span className="font-medium">{personalInfo.companyName}</span>
                  </p>
                  <p className="text-gray-700">
                    NIP: <span className="font-medium">{personalInfo.companyNip}</span>
                  </p>
                  <p className="text-gray-700">
                    Adres: <span className="font-medium">
                      {personalInfo.companyStreet}, {personalInfo.companyPostalCode} {personalInfo.companyCity}
                    </span>
                  </p>
                </div>
              )}
              {personalInfo.comment && (
                <p className="text-gray-700 mt-2">
                  Komentarz: <span className="italic">{personalInfo.comment}</span>
                </p>
              )}
            </div>
          </div>
        </div>

        {/* Payment */}
        <div className="bg-orange-50 p-4 rounded-lg mb-4">
          <div className="flex items-start">
            <CheckCircle className="w-5 h-5 text-solrent-orange mt-0.5 mr-3" />
            <div>
              <h3 className="font-medium text-solrent-dark">Podsumowanie kosztów</h3>
              <div className="mt-2 space-y-1">
                <div className="flex justify-between text-solrent-gray">
                  <span>Koszt dzienny:</span>
                  <div className="text-right">
                    {calculateDays() >= 7 && equipment.some(item => item.promotional_price) ? (
                      <>
                        <span className="font-medium text-green-600">
                          {equipment.reduce((total, item) => 
                            total + ((item.promotional_price || item.price) * item.quantity), 0).toFixed(2)
                          } zł
                        </span>
                        <span className="ml-2 text-sm line-through">
                          {equipment.reduce((total, item) => 
                            total + (item.price * item.quantity), 0).toFixed(2)
                          } zł
                        </span>
                      </>
                    ) : (
                      <span className="font-medium">
                        {equipment.reduce((total, item) => 
                          total + (item.price * item.quantity), 0).toFixed(2)
                        } zł
                      </span>
                    )}
                  </div>
                </div>
                <div className="flex justify-between text-solrent-gray">
                  <span>Liczba dni:</span>
                  <span className={`font-medium ${calculateDays() >= 7 ? 'text-green-600' : 'text-gray-900'}`}>
                    {calculateDays()}
                  </span>
                </div>
                {calculateDays() >= 7 && equipment.some(item => item.promotional_price) && (
                  <div className="flex justify-between text-green-600 font-medium pt-2 border-t border-green-200">
                    <span>Oszczędzasz:</span>
                    <span>
                      {((
                        equipment.reduce((total, item) => total + (item.price * item.quantity), 0) -
                        equipment.reduce((total, item) => total + ((item.promotional_price || item.price) * item.quantity), 0)
                      ) * calculateDays()).toFixed(2)} zł
                    </span>
                  </div>
                )}
                <div className="flex justify-between text-solrent-gray pt-2 border-t border-orange-200">
                  <span>Całkowity koszt wypożyczenia:</span>
                  <span className="font-medium">{calculateTotalPrice().toFixed(2)} zł</span>
                </div>
                <div className="flex justify-between text-solrent-gray pt-2 border-t border-orange-200">
                  <span>Kaucja (zwrotna):</span>
                  <span className="font-medium">{calculateTotalDeposit().toFixed(2)} zł</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div className="bg-green-50 p-4 rounded-lg text-green-700">
        <p className="text-sm">
          <strong>Informacja:</strong> Po kliknięciu przycisku "Zarezerwuj" Twoja rezerwacja zostanie zapisana w systemie.
          {calculateDays() >= 7 && equipment.some(item => item.promotional_price) ? (
            <span className="block mt-2">
              <strong>Promocja aktywna!</strong> Wybrałeś rezerwację na 7 lub więcej dni - otrzymujesz specjalną zniżkę na wybrane produkty!
            </span>
          ) : calculateDays() < 7 && equipment.some(item => item.promotional_price) ? (
            <span className="block mt-2">
              <strong>Wskazówka:</strong> Zarezerwuj na 7 lub więcej dni, aby otrzymać specjalną zniżkę na wybrane produkty!
            </span>
          ) : null}
        </p>
      </div>
      <div className="bg-orange-50 p-4 rounded-lg text-orange-700">
        <p className="text-sm">
          <strong>Kaucja:</strong> Kaucja jest pobierana przed rozpoczęciem usługi jako zabezpieczenie przed ewentualnymi uszkodzeniami. 
          Kaucja zostanie zwrócona w pełnej wysokości po zakończeniu usługi i stwierdzeniu braku uszkodzeń. 
          W przypadku stwierdzenia uszkodzeń, koszty naprawy zostaną potrącone z kaucji.
        </p>
      </div>
      
      {/* Status messages */}
      <div className="flex flex-col items-center space-y-4">
        {submitError && (
          <div className="w-full bg-red-50 p-4 rounded-lg text-red-700">
            {submitError}
          </div>
        )}
        
        {submitSuccess && (
          <div className="w-full bg-green-50 p-4 rounded-lg text-green-700">
            <p className="font-medium">Rezerwacja została pomyślnie złożona!</p>
            <p className="mt-2">Za chwilę nastąpi przekierowanie na stronę główną...</p>
          </div>
        )}
      </div>

      <Modal
        isOpen={showModal}
        onClose={handleModalClose}
        title={modalContent.title}
      >
        <div className={`text-center ${modalContent.isError ? 'text-red-600' : 'text-green-600'}`}>
          <p className="mb-4">{modalContent.message}</p>
          <button
            onClick={handleModalClose}
            className={`px-4 py-2 rounded-lg text-white ${
              modalContent.isError ? 'bg-red-600 hover:bg-red-700' : 'bg-green-600 hover:bg-green-700'
            }`}
          >
            OK
          </button>
        </div>
      </Modal>
    </div>
  );
});

Summary.displayName = 'Summary';

export default Summary;