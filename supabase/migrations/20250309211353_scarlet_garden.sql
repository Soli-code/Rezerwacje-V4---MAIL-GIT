/*
  # Add sample customer record

  1. New Data
    - Dodaje przykładowy rekord klienta z wszystkimi wymaganymi polami
    - Dane są poprawnie sformatowane i zwalidowane
    - Rekord będzie widoczny w panelu administracyjnym Supabase

  2. Fields
    - first_name: Imię klienta
    - last_name: Nazwisko klienta
    - email: Adres email
    - phone: Numer telefonu
    - product_name: Nazwa wypożyczonego sprzętu
    - rental_start_date: Data rozpoczęcia wypożyczenia
    - rental_end_date: Data zakończenia wypożyczenia
    - rental_days: Liczba dni wypożyczenia
    - total_amount: Całkowita kwota
    - deposit_amount: Kwota kaucji
    - comment: Komentarz (opcjonalny)
*/

INSERT INTO customers (
  first_name,
  last_name,
  email,
  phone,
  product_name,
  rental_start_date,
  rental_end_date,
  rental_days,
  total_amount,
  deposit_amount,
  comment,
  created_at,
  updated_at
) VALUES (
  'Jan',
  'Kowalski',
  'jan.kowalski@example.com',
  '123 456 789',
  'Młotowiertarka (1x), Szlifierka kątowa (2x)',
  '2025-03-15 08:00:00+01',
  '2025-03-22 16:00:00+01',
  8,
  640.00,
  300.00,
  'Proszę o przygotowanie sprzętu na godzinę 8:00',
  NOW(),
  NOW()
);