/*
  # Tabela informacji kontaktowych

  1. Nowa tabela
    - contact_info: przechowuje dane kontaktowe
      - id (uuid, primary key)
      - phone_number (text)
      - email (text)
      - created_at (timestamptz)
      - updated_at (timestamptz)

  2. Bezpieczeństwo
    - RLS włączone
    - Polityki dostępu dla publicznych odczytów
    - Polityki dostępu dla administratorów

  3. Ograniczenia
    - Tylko jeden rekord może istnieć w tabeli
    - Trigger sprawdzający liczbę rekordów
*/

-- Usuń istniejący trigger jeśli istnieje
DROP TRIGGER IF EXISTS ensure_single_contact_info ON contact_info;

-- Usuń istniejącą funkcję jeśli istnieje
DROP FUNCTION IF EXISTS check_contact_info_count();

-- Utwórz funkcję sprawdzającą liczbę rekordów
CREATE OR REPLACE FUNCTION check_contact_info_count()
RETURNS trigger AS $$
BEGIN
  IF (SELECT COUNT(*) FROM contact_info) > 0 THEN
    RAISE EXCEPTION 'Tylko jeden rekord może istnieć w tabeli contact_info';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Usuń istniejącą tabelę jeśli istnieje
DROP TABLE IF EXISTS contact_info;

-- Utwórz tabelę contact_info
CREATE TABLE contact_info (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone_number text NOT NULL,
  email text NOT NULL,
  updated_at timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now()
);

-- Dodaj trigger ograniczający liczbę rekordów
CREATE TRIGGER ensure_single_contact_info
  BEFORE INSERT ON contact_info
  FOR EACH ROW
  EXECUTE FUNCTION check_contact_info_count();

-- Włącz Row Level Security
ALTER TABLE contact_info ENABLE ROW LEVEL SECURITY;

-- Dodaj polityki dostępu
CREATE POLICY "Anyone can view contact info"
  ON contact_info
  FOR SELECT
  TO public
  USING (true);

CREATE POLICY "Only admins can modify contact info"
  ON contact_info
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.is_admin = true
    )
  );

-- Dodaj domyślne dane kontaktowe
INSERT INTO contact_info (phone_number, email)
VALUES ('694 171 171', 'kontakt@solrent.pl')
ON CONFLICT DO NOTHING;