/*
  # Dodanie pól związanych z wypożyczeniem do tabeli customers

  1. Nowe Kolumny
    - `product_name` - nazwa wypożyczonego produktu
    - `rental_start_date` - data rozpoczęcia wypożyczenia
    - `rental_end_date` - data zakończenia wypożyczenia
    - `rental_days` - liczba dni wypożyczenia
    - `total_amount` - całkowita kwota
    - `deposit_amount` - kwota kaucji

  2. Indeksy
    - Dodanie indeksu dla dat wypożyczenia w celu optymalizacji zapytań
*/

-- Dodaj nowe kolumny do tabeli customers
ALTER TABLE customers 
ADD COLUMN IF NOT EXISTS product_name text,
ADD COLUMN IF NOT EXISTS rental_start_date timestamptz,
ADD COLUMN IF NOT EXISTS rental_end_date timestamptz,
ADD COLUMN IF NOT EXISTS rental_days integer,
ADD COLUMN IF NOT EXISTS total_amount numeric,
ADD COLUMN IF NOT EXISTS deposit_amount numeric;

-- Dodaj indeks dla dat wypożyczenia
CREATE INDEX IF NOT EXISTS idx_customers_rental_dates 
ON customers (rental_start_date, rental_end_date);