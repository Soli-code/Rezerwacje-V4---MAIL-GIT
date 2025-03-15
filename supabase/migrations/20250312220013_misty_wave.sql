/*
  # System profili klientów

  1. Nowe Tabele
    - `customer_profiles` - rozszerzone dane klienta i KPI
    - `customer_activities` - historia aktywności klienta
    - `customer_tags` - system tagów
    - `customer_activity_tags` - powiązania aktywności z tagami
    - `customer_financial_stats` - statystyki finansowe klienta
    
  2. Funkcje
    - `get_customer_kpis` - oblicza wskaźniki KPI dla klienta
    - `get_customer_activity_history` - pobiera historię aktywności
    - `update_customer_stats` - aktualizuje statystyki klienta
*/

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

-- Polityki dostępu dla administratorów
CREATE POLICY "Admins can manage customer profiles"
  ON customer_profiles FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.is_admin = true
  ));

CREATE POLICY "Admins can manage customer activities"
  ON customer_activities FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.is_admin = true
  ));

CREATE POLICY "Admins can manage customer tags"
  ON customer_tags FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.is_admin = true
  ));

CREATE POLICY "Admins can manage activity tags"
  ON customer_activity_tags FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.is_admin = true
  ));

CREATE POLICY "Admins can manage financial stats"
  ON customer_financial_stats FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.is_admin = true
  ));

-- Funkcja obliczająca KPI klienta
CREATE OR REPLACE FUNCTION get_customer_kpis(customer_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result jsonb;
BEGIN
  WITH stats AS (
    SELECT
      COUNT(*) as total_rentals,
      COUNT(*) FILTER (WHERE status = 'completed') as completed_rentals,
      AVG(EXTRACT(EPOCH FROM (end_date - start_date))/86400) as avg_duration,
      SUM(total_price) as total_value,
      COUNT(*) FILTER (WHERE status = 'cancelled') as cancelled_rentals
    FROM reservations
    WHERE customer_id = $1
  ),
  recent_activity AS (
    SELECT
      MAX(created_at) as last_activity,
      COUNT(*) FILTER (WHERE created_at > now() - interval '30 days') as activity_last_30_days
    FROM customer_activities
    WHERE customer_id = $1
  )
  SELECT jsonb_build_object(
    'total_rentals', COALESCE((SELECT total_rentals FROM stats), 0),
    'completed_rentals', COALESCE((SELECT completed_rentals FROM stats), 0),
    'avg_duration', ROUND(COALESCE((SELECT avg_duration FROM stats), 0)::numeric, 1),
    'total_value', COALESCE((SELECT total_value FROM stats), 0),
    'cancelled_rentals', COALESCE((SELECT cancelled_rentals FROM stats), 0),
    'last_activity', (SELECT last_activity FROM recent_activity),
    'activity_last_30_days', COALESCE((SELECT activity_last_30_days FROM recent_activity), 0),
    'completion_rate', CASE 
      WHEN (SELECT total_rentals FROM stats) > 0 
      THEN ROUND((SELECT completed_rentals::numeric / total_rentals * 100 FROM stats), 1)
      ELSE 0
    END
  ) INTO result;

  RETURN result;
END;
$$;

-- Funkcja pobierająca historię aktywności
CREATE OR REPLACE FUNCTION get_customer_activity_history(
  p_customer_id uuid,
  p_start_date timestamptz DEFAULT NULL,
  p_end_date timestamptz DEFAULT NULL,
  p_activity_types text[] DEFAULT NULL,
  p_status text[] DEFAULT NULL,
  p_tags uuid[] DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result jsonb;
BEGIN
  WITH filtered_activities AS (
    SELECT 
      ca.id,
      ca.activity_type,
      ca.description,
      ca.amount,
      ca.status,
      ca.created_at,
      ca.metadata,
      (
        SELECT jsonb_agg(jsonb_build_object(
          'id', ct.id,
          'name', ct.name,
          'color', ct.color
        ))
        FROM customer_activity_tags cat
        JOIN customer_tags ct ON ct.id = cat.tag_id
        WHERE cat.activity_id = ca.id
      ) as tags
    FROM customer_activities ca
    WHERE ca.customer_id = p_customer_id
    AND (p_start_date IS NULL OR ca.created_at >= p_start_date)
    AND (p_end_date IS NULL OR ca.created_at <= p_end_date)
    AND (p_activity_types IS NULL OR ca.activity_type = ANY(p_activity_types))
    AND (p_status IS NULL OR ca.status = ANY(p_status))
    AND (p_tags IS NULL OR EXISTS (
      SELECT 1 FROM customer_activity_tags cat
      WHERE cat.activity_id = ca.id AND cat.tag_id = ANY(p_tags)
    ))
    ORDER BY ca.created_at DESC
  )
  SELECT jsonb_build_object(
    'activities', COALESCE(jsonb_agg(to_jsonb(fa.*)), '[]'::jsonb),
    'summary', jsonb_build_object(
      'total_count', COUNT(*),
      'total_amount', SUM(fa.amount),
      'types_distribution', jsonb_object_agg(
        fa.activity_type,
        COUNT(*)
      )
    )
  )
  FROM filtered_activities fa
  INTO result;

  RETURN result;
END;
$$;

-- Funkcja aktualizująca statystyki klienta
CREATE OR REPLACE FUNCTION update_customer_stats()
RETURNS trigger AS $$
BEGIN
  -- Aktualizuj profil klienta
  INSERT INTO customer_profiles (
    id,
    lifetime_value,
    avg_rental_duration,
    total_rentals,
    updated_at
  )
  SELECT
    NEW.customer_id,
    COALESCE(SUM(total_price), 0),
    COALESCE(AVG(EXTRACT(EPOCH FROM (end_date - start_date))/86400), 0),
    COUNT(*),
    now()
  FROM reservations
  WHERE customer_id = NEW.customer_id
  AND status != 'cancelled'
  ON CONFLICT (id) DO UPDATE
  SET
    lifetime_value = EXCLUDED.lifetime_value,
    avg_rental_duration = EXCLUDED.avg_rental_duration,
    total_rentals = EXCLUDED.total_rentals,
    updated_at = EXCLUDED.updated_at;

  -- Dodaj wpis aktywności
  INSERT INTO customer_activities (
    customer_id,
    activity_type,
    description,
    related_reservation_id,
    amount,
    status,
    created_by,
    metadata
  ) VALUES (
    NEW.customer_id,
    CASE 
      WHEN TG_OP = 'INSERT' THEN 'rental'
      WHEN NEW.status = 'completed' THEN 'return'
      ELSE 'note'
    END,
    CASE 
      WHEN TG_OP = 'INSERT' THEN 'Nowa rezerwacja'
      WHEN NEW.status = 'completed' THEN 'Zwrot sprzętu'
      ELSE 'Aktualizacja rezerwacji'
    END,
    NEW.id,
    NEW.total_price,
    NEW.status,
    auth.uid(),
    jsonb_build_object(
      'reservation_id', NEW.id,
      'old_status', CASE WHEN TG_OP = 'UPDATE' THEN OLD.status ELSE NULL END,
      'new_status', NEW.status
    )
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Dodaj trigger do tabeli reservations
DROP TRIGGER IF EXISTS update_customer_stats_trigger ON reservations;
CREATE TRIGGER update_customer_stats_trigger
  AFTER INSERT OR UPDATE ON reservations
  FOR EACH ROW
  EXECUTE FUNCTION update_customer_stats();

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