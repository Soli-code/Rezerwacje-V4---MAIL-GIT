/*
  # Utworzenie tabel dla sprzętu i danych kontaktowych

  1. Nowe Tabele
    - `equipment` - Główna tabela sprzętu
    - `specifications` - Specyfikacje techniczne sprzętu
    - `features` - Cechy sprzętu
    - `variants` - Warianty sprzętu
    - `contact_info` - Informacje kontaktowe
  
  2. Relacje
    - Powiązanie specifications, features i variants z equipment
    - Klucze obce z kaskadowym usuwaniem
  
  3. Bezpieczeństwo
    - Włączenie RLS dla wszystkich tabel
    - Polityki dostępu dla authenticated i anon użytkowników
*/

-- Tabela equipment
CREATE TABLE IF NOT EXISTS equipment (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text NOT NULL,
  price numeric NOT NULL CHECK (price >= 0),
  deposit numeric DEFAULT 0 CHECK (deposit >= 0),
  image text NOT NULL,
  categories text[] NOT NULL DEFAULT ARRAY['budowlany'],
  quantity integer NOT NULL DEFAULT 1 CHECK (quantity >= 0),
  dimensions text,
  weight numeric,
  power_supply text,
  technical_details jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  last_modified_by uuid REFERENCES auth.users(id)
);

-- Tabela specifications
CREATE TABLE IF NOT EXISTS specifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id uuid REFERENCES equipment(id) ON DELETE CASCADE,
  key text NOT NULL,
  value text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Tabela features
CREATE TABLE IF NOT EXISTS features (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id uuid REFERENCES equipment(id) ON DELETE CASCADE,
  text text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Tabela variants
CREATE TABLE IF NOT EXISTS variants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id uuid REFERENCES equipment(id) ON DELETE CASCADE,
  name text NOT NULL,
  price numeric NOT NULL CHECK (price >= 0),
  created_at timestamptz DEFAULT now()
);

-- Tabela contact_info
CREATE TABLE IF NOT EXISTS contact_info (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone_number text NOT NULL,
  email text NOT NULL,
  updated_at timestamptz DEFAULT now()
);

-- Włączenie RLS
ALTER TABLE equipment ENABLE ROW LEVEL SECURITY;
ALTER TABLE specifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE features ENABLE ROW LEVEL SECURITY;
ALTER TABLE variants ENABLE ROW LEVEL SECURITY;
ALTER TABLE contact_info ENABLE ROW LEVEL SECURITY;

-- Polityki RLS dla equipment
CREATE POLICY "Wszyscy mogą wyświetlać sprzęt"
  ON equipment FOR SELECT
  TO public
  USING (true);

CREATE POLICY "Tylko admin może modyfikować sprzęt"
  ON equipment FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.is_admin = true
    )
  );

-- Polityki RLS dla specifications
CREATE POLICY "Wszyscy mogą wyświetlać specyfikacje"
  ON specifications FOR SELECT
  TO public
  USING (true);

CREATE POLICY "Tylko admin może modyfikować specyfikacje"
  ON specifications FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.is_admin = true
    )
  );

-- Polityki RLS dla features
CREATE POLICY "Wszyscy mogą wyświetlać cechy"
  ON features FOR SELECT
  TO public
  USING (true);

CREATE POLICY "Tylko admin może modyfikować cechy"
  ON features FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.is_admin = true
    )
  );

-- Polityki RLS dla variants
CREATE POLICY "Wszyscy mogą wyświetlać warianty"
  ON variants FOR SELECT
  TO public
  USING (true);

CREATE POLICY "Tylko admin może modyfikować warianty"
  ON variants FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.is_admin = true
    )
  );

-- Polityki RLS dla contact_info
CREATE POLICY "Wszyscy mogą wyświetlać dane kontaktowe"
  ON contact_info FOR SELECT
  TO public
  USING (true);

CREATE POLICY "Tylko admin może modyfikować dane kontaktowe"
  ON contact_info FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.is_admin = true
    )
  );

-- Dodaj podstawowe dane kontaktowe
INSERT INTO contact_info (phone_number, email)
VALUES ('694 171 171', 'kontakt@solrent.pl')
ON CONFLICT DO NOTHING;