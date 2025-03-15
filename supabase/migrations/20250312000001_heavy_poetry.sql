/*
  # System CRM

  1. Nowe Tabele
    - `crm_contacts` - kontakty klientów
    - `crm_notes` - notatki do kontaktów
    - `crm_tasks` - zadania do wykonania
    - `crm_documents` - dokumenty związane z klientami
    - `crm_interactions` - historia interakcji z klientami
    
  2. Bezpieczeństwo
    - Włączone RLS dla wszystkich tabel
    - Dostęp tylko dla administratorów
*/

-- Tabela kontaktów CRM
CREATE TABLE IF NOT EXISTS crm_contacts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid REFERENCES customers(id) ON DELETE CASCADE,
  status text NOT NULL CHECK (status IN ('lead', 'customer', 'inactive')),
  source text NOT NULL,
  assigned_to uuid REFERENCES auth.users(id),
  last_contact_date timestamptz,
  next_contact_date timestamptz,
  lead_score integer CHECK (lead_score BETWEEN 0 AND 100),
  custom_fields jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Tabela notatek CRM
CREATE TABLE IF NOT EXISTS crm_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id uuid REFERENCES crm_contacts(id) ON DELETE CASCADE,
  created_by uuid REFERENCES auth.users(id),
  content text NOT NULL,
  type text NOT NULL CHECK (type IN ('general', 'meeting', 'call', 'email')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Tabela zadań CRM
CREATE TABLE IF NOT EXISTS crm_tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id uuid REFERENCES crm_contacts(id) ON DELETE CASCADE,
  assigned_to uuid REFERENCES auth.users(id),
  title text NOT NULL,
  description text,
  due_date timestamptz,
  priority text NOT NULL CHECK (priority IN ('low', 'medium', 'high')),
  status text NOT NULL CHECK (status IN ('pending', 'in_progress', 'completed', 'cancelled')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Tabela dokumentów CRM
CREATE TABLE IF NOT EXISTS crm_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id uuid REFERENCES crm_contacts(id) ON DELETE CASCADE,
  uploaded_by uuid REFERENCES auth.users(id),
  name text NOT NULL,
  type text NOT NULL,
  url text NOT NULL,
  size integer,
  metadata jsonb,
  created_at timestamptz DEFAULT now()
);

-- Tabela interakcji CRM
CREATE TABLE IF NOT EXISTS crm_interactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id uuid REFERENCES crm_contacts(id) ON DELETE CASCADE,
  type text NOT NULL CHECK (type IN ('email', 'call', 'meeting', 'website', 'other')),
  description text,
  outcome text,
  created_by uuid REFERENCES auth.users(id),
  created_at timestamptz DEFAULT now()
);

-- Włącz RLS dla wszystkich tabel
ALTER TABLE crm_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm_interactions ENABLE ROW LEVEL SECURITY;

-- Polityki dostępu dla administratorów
CREATE POLICY "Admins can manage CRM contacts"
  ON crm_contacts FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  ));

CREATE POLICY "Admins can manage CRM notes"
  ON crm_notes FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  ));

CREATE POLICY "Admins can manage CRM tasks"
  ON crm_tasks FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  ));

CREATE POLICY "Admins can manage CRM documents"
  ON crm_documents FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  ));

CREATE POLICY "Admins can manage CRM interactions"
  ON crm_interactions FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  ));

-- Indeksy dla optymalizacji
CREATE INDEX idx_crm_contacts_customer ON crm_contacts(customer_id);
CREATE INDEX idx_crm_contacts_assigned_to ON crm_contacts(assigned_to);
CREATE INDEX idx_crm_notes_contact ON crm_notes(contact_id);
CREATE INDEX idx_crm_tasks_contact ON crm_tasks(contact_id);
CREATE INDEX idx_crm_tasks_assigned_to ON crm_tasks(assigned_to);
CREATE INDEX idx_crm_documents_contact ON crm_documents(contact_id);
CREATE INDEX idx_crm_interactions_contact ON crm_interactions(contact_id);

-- Funkcja do automatycznej aktualizacji updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggery dla aktualizacji updated_at
CREATE TRIGGER update_crm_contacts_updated_at
  BEFORE UPDATE ON crm_contacts
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_crm_notes_updated_at
  BEFORE UPDATE ON crm_notes
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_crm_tasks_updated_at
  BEFORE UPDATE ON crm_tasks
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Funkcja do logowania interakcji CRM
CREATE OR REPLACE FUNCTION log_crm_interaction(
  p_contact_id uuid,
  p_type text,
  p_description text,
  p_outcome text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_interaction_id uuid;
BEGIN
  INSERT INTO crm_interactions (
    contact_id,
    type,
    description,
    outcome,
    created_by
  ) VALUES (
    p_contact_id,
    p_type,
    p_description,
    p_outcome,
    auth.uid()
  )
  RETURNING id INTO v_interaction_id;

  -- Aktualizuj datę ostatniego kontaktu
  UPDATE crm_contacts
  SET last_contact_date = now()
  WHERE id = p_contact_id;

  RETURN v_interaction_id;
END;
$$;