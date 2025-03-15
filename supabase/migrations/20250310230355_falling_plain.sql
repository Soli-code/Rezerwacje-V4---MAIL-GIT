/*
  # Dodanie pól wynajmu do tabeli customers

  1. Nowe kolumny
    - product_name: nazwa wypożyczonego produktu
    - rental_start_date: data rozpoczęcia wynajmu
    - rental_end_date: data zakończenia wynajmu
    - rental_days: liczba dni wynajmu
    - total_amount: całkowita kwota
    - deposit_amount: kwota kaucji

  2. Indeksy
    - Dodanie indeksu dla dat wynajmu w celu optymalizacji zapytań
*/

-- Dodaj nowe kolumny do tabeli customers
ALTER TABLE customers 
ADD COLUMN IF NOT EXISTS product_name text,
ADD COLUMN IF NOT EXISTS rental_start_date timestamptz,
ADD COLUMN IF NOT EXISTS rental_end_date timestamptz,
ADD COLUMN IF NOT EXISTS rental_days integer,
ADD COLUMN IF NOT EXISTS total_amount numeric,
ADD COLUMN IF NOT EXISTS deposit_amount numeric;

-- Dodaj indeks dla dat wynajmu
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE tablename = 'customers' AND indexname = 'idx_customers_rental_dates'
  ) THEN
    CREATE INDEX idx_customers_rental_dates ON customers (rental_start_date, rental_end_date);
  END IF;
END $$;