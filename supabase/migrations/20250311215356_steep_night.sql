/*
  # Admin Panel System Setup

  1. New Tables
    - `admin_actions` - log działań administratorów
    - `maintenance_logs` - rejestr konserwacji sprzętu
    - `rental_history` - historia wypożyczeń
    - `damage_reports` - raporty uszkodzeń
    - `customer_feedback` - opinie klientów
    - `financial_transactions` - transakcje finansowe

  2. Security
    - Enable RLS on all tables
    - Add policies for admin access
*/

-- Tabela logów działań administratorów
CREATE TABLE admin_actions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id uuid REFERENCES auth.users(id),
  action_type text NOT NULL,
  action_details jsonb NOT NULL,
  performed_at timestamptz DEFAULT now(),
  ip_address text,
  user_agent text
);

-- Tabela logów konserwacji
CREATE TABLE maintenance_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id uuid REFERENCES equipment(id) ON DELETE CASCADE,
  maintenance_type text NOT NULL,
  description text NOT NULL,
  cost numeric,
  performed_by uuid REFERENCES auth.users(id),
  performed_at timestamptz DEFAULT now(),
  next_maintenance_due timestamptz,
  status text NOT NULL CHECK (status IN ('planned', 'in_progress', 'completed')),
  attachments jsonb
);

-- Tabela historii wypożyczeń
CREATE TABLE rental_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reservation_id uuid REFERENCES reservations(id) ON DELETE CASCADE,
  previous_status text,
  new_status text NOT NULL,
  changed_at timestamptz DEFAULT now(),
  changed_by uuid REFERENCES auth.users(id),
  comment text
);

-- Tabela raportów uszkodzeń
CREATE TABLE damage_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id uuid REFERENCES equipment(id) ON DELETE CASCADE,
  reservation_id uuid REFERENCES reservations(id),
  reported_by uuid REFERENCES auth.users(id),
  description text NOT NULL,
  severity text NOT NULL CHECK (severity IN ('minor', 'moderate', 'severe')),
  repair_cost numeric,
  status text NOT NULL CHECK (status IN ('reported', 'under_review', 'repairing', 'resolved')),
  reported_at timestamptz DEFAULT now(),
  resolved_at timestamptz,
  photos jsonb,
  resolution_notes text
);

-- Tabela opinii klientów
CREATE TABLE customer_feedback (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reservation_id uuid REFERENCES reservations(id) ON DELETE CASCADE,
  customer_id uuid REFERENCES customers(id),
  rating integer CHECK (rating BETWEEN 1 AND 5),
  comment text,
  submitted_at timestamptz DEFAULT now(),
  equipment_condition_rating integer CHECK (rating BETWEEN 1 AND 5),
  service_rating integer CHECK (rating BETWEEN 1 AND 5),
  would_recommend boolean,
  admin_response text,
  admin_response_at timestamptz
);

-- Tabela transakcji finansowych
CREATE TABLE financial_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reservation_id uuid REFERENCES reservations(id),
  transaction_type text NOT NULL CHECK (transaction_type IN ('payment', 'deposit', 'deposit_return', 'damage_charge')),
  amount numeric NOT NULL,
  payment_method text,
  status text NOT NULL CHECK (status IN ('pending', 'completed', 'failed', 'refunded')),
  transaction_date timestamptz DEFAULT now(),
  notes text,
  receipt_number text,
  processed_by uuid REFERENCES auth.users(id)
);

-- Włącz RLS dla wszystkich tabel
ALTER TABLE admin_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE rental_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE damage_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE customer_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE financial_transactions ENABLE ROW LEVEL SECURITY;

-- Polityki dostępu dla administratorów
CREATE POLICY "Admins can manage admin actions"
  ON admin_actions FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.is_admin = true
  ));

CREATE POLICY "Admins can manage maintenance logs"
  ON maintenance_logs FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.is_admin = true
  ));

CREATE POLICY "Admins can manage rental history"
  ON rental_history FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.is_admin = true
  ));

CREATE POLICY "Admins can manage damage reports"
  ON damage_reports FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.is_admin = true
  ));

CREATE POLICY "Admins can manage customer feedback"
  ON customer_feedback FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.is_admin = true
  ));

CREATE POLICY "Admins can manage financial transactions"
  ON financial_transactions FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.is_admin = true
  ));

-- Indeksy dla optymalizacji
CREATE INDEX idx_admin_actions_admin ON admin_actions(admin_id);
CREATE INDEX idx_maintenance_logs_equipment ON maintenance_logs(equipment_id);
CREATE INDEX idx_rental_history_reservation ON rental_history(reservation_id);
CREATE INDEX idx_damage_reports_equipment ON damage_reports(equipment_id);
CREATE INDEX idx_damage_reports_reservation ON damage_reports(reservation_id);
CREATE INDEX idx_customer_feedback_reservation ON customer_feedback(reservation_id);
CREATE INDEX idx_financial_transactions_reservation ON financial_transactions(reservation_id);

-- Funkcja do logowania akcji administratora
CREATE OR REPLACE FUNCTION log_admin_action(
  action_type text,
  action_details jsonb
) RETURNS void AS $$
BEGIN
  INSERT INTO admin_actions (
    admin_id,
    action_type,
    action_details,
    ip_address,
    user_agent
  ) VALUES (
    auth.uid(),
    action_type,
    action_details,
    current_setting('request.headers')::json->>'x-forwarded-for',
    current_setting('request.headers')::json->>'user-agent'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Funkcja do śledzenia historii rezerwacji
CREATE OR REPLACE FUNCTION track_reservation_history()
RETURNS trigger AS $$
BEGIN
  INSERT INTO rental_history (
    reservation_id,
    previous_status,
    new_status,
    changed_by,
    comment
  ) VALUES (
    NEW.id,
    OLD.status,
    NEW.status,
    auth.uid(),
    CASE 
      WHEN NEW.status = 'confirmed' THEN 'Rezerwacja potwierdzona'
      WHEN NEW.status = 'completed' THEN 'Rezerwacja zakończona'
      WHEN NEW.status = 'cancelled' THEN 'Rezerwacja anulowana'
      ELSE 'Status zmieniony'
    END
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Bezpiecznie usuń trigger jeśli istnieje
DROP TRIGGER IF EXISTS track_reservation_history_trigger ON reservations;

-- Dodaj trigger do śledzenia zmian statusu rezerwacji
CREATE TRIGGER track_reservation_history_trigger
  AFTER UPDATE OF status ON reservations
  FOR EACH ROW
  EXECUTE FUNCTION track_reservation_history();