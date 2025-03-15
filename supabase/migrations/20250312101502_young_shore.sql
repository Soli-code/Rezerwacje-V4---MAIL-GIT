/*
  # Usunięcie danych testowych z systemu rezerwacji

  1. Zmiany
    - Usunięcie wszystkich rezerwacji
    - Usunięcie wszystkich danych klientów
    - Usunięcie powiązanych danych (historia rezerwacji, notatki itp.)
    
  2. Bezpieczeństwo
    - Zachowanie struktury tabel
    - Zachowanie polityk dostępu i triggerów
*/

-- Najpierw usuń wszystkie powiązane dane
DELETE FROM reservation_history;
DELETE FROM reservation_notes;
DELETE FROM reservation_items;
DELETE FROM email_notifications WHERE reservation_id IN (SELECT id FROM reservations);
DELETE FROM financial_transactions WHERE reservation_id IN (SELECT id FROM reservations);
DELETE FROM damage_reports WHERE reservation_id IN (SELECT id FROM reservations);

-- Usuń wszystkie rezerwacje
DELETE FROM reservations;

-- Usuń wszystkie dane klientów
DELETE FROM crm_contacts WHERE customer_id IN (SELECT id FROM customers);
DELETE FROM crm_notes WHERE contact_id IN (SELECT id FROM crm_contacts);
DELETE FROM crm_tasks WHERE contact_id IN (SELECT id FROM crm_contacts);
DELETE FROM crm_documents WHERE contact_id IN (SELECT id FROM crm_contacts);
DELETE FROM crm_interactions WHERE contact_id IN (SELECT id FROM crm_contacts);
DELETE FROM customers;

-- Sprawdź czy dane zostały usunięte
DO $$
DECLARE
  v_reservations_count integer;
  v_customers_count integer;
BEGIN
  SELECT COUNT(*) INTO v_reservations_count FROM reservations;
  SELECT COUNT(*) INTO v_customers_count FROM customers;
  
  RAISE NOTICE 'Liczba pozostałych rezerwacji: %', v_reservations_count;
  RAISE NOTICE 'Liczba pozostałych klientów: %', v_customers_count;
  
  IF v_reservations_count > 0 OR v_customers_count > 0 THEN
    RAISE NOTICE 'UWAGA: Nie wszystkie dane zostały usunięte!';
  ELSE
    RAISE NOTICE 'Wszystkie dane testowe zostały pomyślnie usunięte.';
  END IF;
END $$;