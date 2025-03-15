/*
  # System zarządzania rezerwacjami

  1. Nowe Tabele
    - `reservations` - główna tabela rezerwacji
    - `reservation_items` - przedmioty w rezerwacji
    - `reservation_history` - historia zmian statusu
    - `reservation_notes` - notatki do rezerwacji
    
  2. Triggery
    - Automatyczna aktualizacja dostępności sprzętu
    - Śledzenie historii zmian statusu
    - Walidacja dat rezerwacji
*/

-- Najpierw utwórz wszystkie tabele
CREATE TABLE IF NOT EXISTS reservations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid REFERENCES customers(id) ON DELETE CASCADE,
  start_date timestamptz NOT NULL,
  end_date timestamptz NOT NULL,
  start_time text NOT NULL,
  end_time text NOT NULL,
  total_price numeric NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'cancelled', 'completed')),
  comment text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  rental_days integer,
  free_sunday boolean DEFAULT false,
  CONSTRAINT valid_dates CHECK (end_date >= start_date)
);

CREATE TABLE IF NOT EXISTS reservation_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reservation_id uuid REFERENCES reservations(id) ON DELETE CASCADE,
  equipment_id uuid REFERENCES equipment(id),
  quantity integer NOT NULL CHECK (quantity > 0),
  price_per_day numeric NOT NULL,
  deposit numeric DEFAULT 0
);

CREATE TABLE IF NOT EXISTS reservation_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reservation_id uuid REFERENCES reservations(id) ON DELETE CASCADE,
  previous_status text,
  new_status text NOT NULL,
  changed_at timestamptz DEFAULT now(),
  changed_by uuid REFERENCES auth.users(id),
  comment text
);

CREATE TABLE IF NOT EXISTS reservation_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reservation_id uuid REFERENCES reservations(id) ON DELETE CASCADE,
  content text NOT NULL,
  created_by uuid REFERENCES auth.users(id),
  created_at timestamptz DEFAULT now()
);

-- Włącz RLS dla wszystkich tabel
ALTER TABLE reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE reservation_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE reservation_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE reservation_notes ENABLE ROW LEVEL SECURITY;

-- Usuń istniejące polityki jeśli istnieją
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "Public can create and view reservations" ON reservations;
  DROP POLICY IF EXISTS "Public can create and view reservation items" ON reservation_items;
  DROP POLICY IF EXISTS "Admins can manage reservation history" ON reservation_history;
  DROP POLICY IF EXISTS "Admins can manage reservation notes" ON reservation_notes;
EXCEPTION
  WHEN undefined_object THEN NULL;
END $$;

-- Utwórz nowe polityki
CREATE POLICY "Public can create and view reservations"
  ON reservations FOR ALL TO public
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Public can create and view reservation items"
  ON reservation_items FOR ALL TO public
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Admins can manage reservation history"
  ON reservation_history FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  ));

CREATE POLICY "Admins can manage reservation notes"
  ON reservation_notes FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  ));

-- Indeksy dla optymalizacji
CREATE INDEX IF NOT EXISTS idx_reservations_dates ON reservations(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_reservations_status ON reservations(status);
CREATE INDEX IF NOT EXISTS idx_reservation_items_equipment ON reservation_items(equipment_id);
CREATE INDEX IF NOT EXISTS idx_reservation_history_reservation ON reservation_history(reservation_id);

-- Funkcja do walidacji rezerwacji
CREATE OR REPLACE FUNCTION validate_reservation()
RETURNS trigger AS $$
BEGIN
  -- Sprawdź czy data końcowa jest późniejsza niż początkowa
  IF NEW.end_date <= NEW.start_date THEN
    RAISE EXCEPTION 'Data zakończenia musi być późniejsza niż data rozpoczęcia';
  END IF;

  -- Sprawdź czy godziny są w dozwolonym zakresie (8:00-16:00)
  IF NEW.start_time::time < '08:00'::time OR NEW.start_time::time > '16:00'::time OR
     NEW.end_time::time < '08:00'::time OR NEW.end_time::time > '16:00'::time THEN
    RAISE EXCEPTION 'Godziny rezerwacji muszą być w zakresie 8:00-16:00';
  END IF;

  -- Sprawdź ograniczenia dla soboty (8:00-13:00)
  IF EXTRACT(DOW FROM NEW.start_date) = 6 AND NEW.start_time::time > '13:00'::time THEN
    RAISE EXCEPTION 'W sobotę rezerwacje tylko do 13:00';
  END IF;

  -- Sprawdź czy nie wypada w niedzielę
  IF EXTRACT(DOW FROM NEW.start_date) = 0 OR EXTRACT(DOW FROM NEW.end_date) = 0 THEN
    RAISE EXCEPTION 'Rezerwacje nie są możliwe w niedziele';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger do walidacji rezerwacji
DROP TRIGGER IF EXISTS validate_reservation_time_gap ON reservations;
CREATE TRIGGER validate_reservation_time_gap
  BEFORE INSERT OR UPDATE ON reservations
  FOR EACH ROW
  EXECUTE FUNCTION validate_reservation();

-- Funkcja do aktualizacji dostępności sprzętu
CREATE OR REPLACE FUNCTION update_equipment_availability()
RETURNS trigger AS $$
BEGIN
  -- Przy potwierdzeniu rezerwacji
  IF (TG_OP = 'INSERT' AND NEW.status = 'confirmed') OR
     (TG_OP = 'UPDATE' AND NEW.status = 'confirmed' AND OLD.status != 'confirmed') THEN
    
    -- Sprawdź dostępność sprzętu
    IF EXISTS (
      SELECT 1 FROM reservation_items ri
      WHERE ri.reservation_id = NEW.id
      AND NOT EXISTS (
        SELECT 1 FROM equipment e
        WHERE e.id = ri.equipment_id
        AND e.quantity >= ri.quantity
      )
    ) THEN
      RAISE EXCEPTION 'Brak wystarczającej ilości sprzętu';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger do aktualizacji dostępności sprzętu
DROP TRIGGER IF EXISTS update_equipment_availability_trigger ON reservations;
CREATE TRIGGER update_equipment_availability_trigger
  AFTER INSERT OR UPDATE OF status ON reservations
  FOR EACH ROW
  EXECUTE FUNCTION update_equipment_availability();

-- Funkcja do śledzenia historii rezerwacji
CREATE OR REPLACE FUNCTION track_reservation_history()
RETURNS trigger AS $$
BEGIN
  IF (TG_OP = 'UPDATE' AND OLD.status != NEW.status) THEN
    INSERT INTO reservation_history (
      reservation_id,
      previous_status,
      new_status,
      changed_by
    ) VALUES (
      NEW.id,
      OLD.status,
      NEW.status,
      auth.uid()
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger do śledzenia historii
DROP TRIGGER IF EXISTS track_reservation_history_trigger ON reservations;
CREATE TRIGGER track_reservation_history_trigger
  AFTER UPDATE OF status ON reservations
  FOR EACH ROW
  EXECUTE FUNCTION track_reservation_history();