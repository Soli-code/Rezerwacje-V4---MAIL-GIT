/*
  # System reklamowy
  
  1. Nowe Tabele
    - `advertisements`
      - `id` (uuid, primary key)
      - `title` (text) - tytuł reklamy
      - `content` (text) - treść reklamy
      - `image_url` (text) - URL obrazu
      - `product_id` (uuid) - powiązany produkt
      - `start_date` (timestamptz) - data rozpoczęcia
      - `end_date` (timestamptz) - data zakończenia
      - `is_active` (boolean) - status aktywności
      - `display_order` (integer) - kolejność wyświetlania
      - `device_type` (text) - typ urządzenia (desktop/mobile)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)
      
  2. Bezpieczeństwo
    - Włączone RLS
    - Polityki dostępu dla administratorów
    - Publiczny dostęp tylko do odczytu aktywnych reklam
*/

-- Utworzenie tabeli reklam
CREATE TABLE IF NOT EXISTS advertisements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  content text NOT NULL,
  image_url text,
  product_id uuid REFERENCES equipment(id) ON DELETE SET NULL,
  start_date timestamptz NOT NULL,
  end_date timestamptz NOT NULL,
  is_active boolean DEFAULT true,
  display_order integer DEFAULT 0,
  device_type text NOT NULL CHECK (device_type IN ('desktop', 'mobile', 'all')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  
  -- Walidacja dat
  CONSTRAINT valid_date_range CHECK (end_date > start_date)
);

-- Włączenie Row Level Security
ALTER TABLE advertisements ENABLE ROW LEVEL SECURITY;

-- Polityka dla publicznego odczytu aktywnych reklam
CREATE POLICY "Public can view active ads" ON advertisements
  FOR SELECT
  TO public
  USING (
    is_active = true 
    AND now() BETWEEN start_date AND end_date
  );

-- Polityka dla administratorów (pełny dostęp)
CREATE POLICY "Admins can manage ads" ON advertisements
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.is_admin = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.is_admin = true
    )
  );

-- Indeksy dla optymalizacji zapytań
CREATE INDEX idx_advertisements_dates ON advertisements(start_date, end_date);
CREATE INDEX idx_advertisements_product ON advertisements(product_id);
CREATE INDEX idx_advertisements_active_order ON advertisements(is_active, display_order);

-- Trigger do automatycznej aktualizacji updated_at
CREATE TRIGGER update_advertisements_updated_at
  BEFORE UPDATE ON advertisements
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();