/*
  # System profili klientów

  1. Nowe Tabele
    - `customer_profiles` - rozszerzone profile klientów
    - `customer_activities` - historia aktywności
    - `customer_tags` - system tagów
    - `customer_activity_tags` - powiązania aktywności z tagami
    - `customer_financial_stats` - statystyki finansowe
    
  2. Bezpieczeństwo
    - Włączone RLS dla wszystkich tabel
    - Polityki dostępu dla administratorów
*/

-- Najpierw usuń istniejące polityki
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "Admins can manage customer profiles" ON customer_profiles;
  DROP POLICY IF EXISTS "Admins can manage customer activities" ON customer_activities;
  DROP POLICY IF EXISTS "Admins can manage customer tags" ON customer_tags;
  DROP POLICY IF EXISTS "Admins can manage activity tags" ON customer_activity_tags;
  DROP POLICY IF EXISTS "Admins can manage financial stats" ON customer_financial_stats;
EXCEPTION
  WHEN undefined_object THEN NULL;
END $$;

-- Tabela profili klientów
CREATE TABLE IF NOT EXISTS customer_profiles (
  id uuid PRIMARY KEY REFERENCES customers(id) ON DELETE CASCADE,
  lead_status text CHECK (lead_status IN ('cold', 'warm', 'hot', 'converted')),
  lead_source text,
  assigned_to uuid REFERENCES auth.users(id),
  last_contact_date timestamptz,
  next_contact_date timestamptz,
  lifetime_value numeric DEFAULT 0,
  avg_rental_duration numeric DEFAULT 0,
  total_rentals integer DEFAULT 0,
  notes text,
  preferences jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Tabela historii aktywności
CREATE TABLE IF NOT EXISTS customer_activities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid REFERENCES customers(id) ON DELETE CASCADE,
  activity_type text NOT NULL CHECK (activity_type IN ('rental', 'return', 'contact', 'note', 'payment')),
  description text NOT NULL,
  related_reservation_id uuid REFERENCES reservations(id) ON DELETE SET NULL,
  amount numeric,
  status text,
  created_by uuid REFERENCES auth.users(id),
  created_at timestamptz DEFAULT now(),
  metadata jsonb
);

-- Tabela tagów
CREATE TABLE IF NOT EXISTS customer_tags (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  color text NOT NULL,
  created_by uuid REFERENCES auth.users(id),
  created_at timestamptz DEFAULT now()
);

-- Tabela powiązań aktywności z tagami
CREATE TABLE IF NOT EXISTS customer_activity_tags (
  activity_id uuid REFERENCES customer_activities(id) ON DELETE CASCADE,
  tag_id uuid REFERENCES customer_tags(id) ON DELETE CASCADE,
  PRIMARY KEY (activity_id, tag_id)
);

-- Tabela statystyk finansowych
CREATE TABLE IF NOT EXISTS customer_financial_stats (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid REFERENCES customers(id) ON DELETE CASCADE,
  period_start date NOT NULL,
  period_end date NOT NULL,
  total_rentals integer DEFAULT 0,
  total_value numeric DEFAULT 0,
  avg_rental_value numeric DEFAULT 0,
  on_time_returns_percent numeric DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  UNIQUE (customer_id, period_start, period_end)
);

-- Włącz RLS dla wszystkich tabel
ALTER TABLE customer_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE customer_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE customer_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE customer_activity_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE customer_financial_stats ENABLE ROW LEVEL SECURITY;

-- Utwórz nowe polityki
CREATE POLICY "Admins can manage customer profiles"
  ON customer_profiles FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  ));

CREATE POLICY "Admins can manage customer activities"
  ON customer_activities FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  ));

CREATE POLICY "Admins can manage customer tags"
  ON customer_tags FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  ));

CREATE POLICY "Admins can manage activity tags"
  ON customer_activity_tags FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  ));

CREATE POLICY "Admins can manage financial stats"
  ON customer_financial_stats FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  ));

-- Dodaj indeksy dla optymalizacji
CREATE INDEX IF NOT EXISTS idx_customer_activities_customer_id_created_at 
  ON customer_activities(customer_id, created_at);

CREATE INDEX IF NOT EXISTS idx_customer_activities_type_status 
  ON customer_activities(activity_type, status);

CREATE INDEX IF NOT EXISTS idx_customer_financial_stats_customer_period 
  ON customer_financial_stats(customer_id, period_start, period_end);

COMMENT ON TABLE customer_profiles IS 'Rozszerzone profile klientów z KPI i preferencjami';
COMMENT ON TABLE customer_activities IS 'Historia wszystkich aktywności klienta';
COMMENT ON TABLE customer_tags IS 'System tagów do kategoryzacji aktywności';
COMMENT ON TABLE customer_financial_stats IS 'Statystyki finansowe klientów w okresach';