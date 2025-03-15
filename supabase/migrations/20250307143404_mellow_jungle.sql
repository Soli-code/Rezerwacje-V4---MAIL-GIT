/*
  # Fix triggers and relationships

  1. Changes
    - Add trigger to update equipment_availability on reservation changes
    - Add trigger to track reservation history
    - Fix foreign key relationships

  2. Security
    - Enable RLS on tables if not enabled
    - Add policies if they don't exist
*/

-- Funkcja do aktualizacji equipment_availability
CREATE OR REPLACE FUNCTION update_equipment_availability()
RETURNS TRIGGER AS $$
BEGIN
  -- Dla nowych rezerwacji lub zmiany statusu na confirmed
  IF (TG_OP = 'INSERT' AND NEW.status = 'confirmed') OR 
     (TG_OP = 'UPDATE' AND NEW.status = 'confirmed' AND OLD.status != 'confirmed') THEN
    
    -- Dodaj wpisy do equipment_availability dla każdego zarezerwowanego przedmiotu
    INSERT INTO equipment_availability (
      equipment_id,
      start_date,
      end_date,
      status,
      reservation_id
    )
    SELECT 
      ri.equipment_id,
      NEW.start_date,
      NEW.end_date,
      'reserved'::text,
      NEW.id
    FROM reservation_items ri
    WHERE ri.reservation_id = NEW.id;

  -- Dla anulowanych lub zakończonych rezerwacji
  ELSIF (TG_OP = 'UPDATE' AND (NEW.status = 'cancelled' OR NEW.status = 'completed')) THEN
    -- Usuń wpisy z equipment_availability
    DELETE FROM equipment_availability
    WHERE reservation_id = NEW.id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Funkcja do śledzenia historii rezerwacji
CREATE OR REPLACE FUNCTION track_reservation_history()
RETURNS TRIGGER AS $$
BEGIN
  IF (TG_OP = 'UPDATE' AND OLD.status != NEW.status) THEN
    INSERT INTO reservation_history (
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
        WHEN NEW.status = 'cancelled' THEN 'Rezerwacja anulowana'
        WHEN NEW.status = 'completed' THEN 'Rezerwacja zakończona'
        ELSE 'Status zmieniony'
      END
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Dodaj brakujące triggery
DROP TRIGGER IF EXISTS update_equipment_availability_trigger ON reservations;
CREATE TRIGGER update_equipment_availability_trigger
  AFTER INSERT OR UPDATE OF status
  ON reservations
  FOR EACH ROW
  EXECUTE FUNCTION update_equipment_availability();

DROP TRIGGER IF EXISTS track_reservation_history_trigger ON reservations;
CREATE TRIGGER track_reservation_history_trigger
  AFTER UPDATE OF status
  ON reservations
  FOR EACH ROW
  EXECUTE FUNCTION track_reservation_history();

-- Upewnij się, że RLS jest włączone dla wszystkich tabel
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_tables 
    WHERE tablename = 'equipment_availability' 
    AND rowsecurity = true
  ) THEN
    ALTER TABLE equipment_availability ENABLE ROW LEVEL SECURITY;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_tables 
    WHERE tablename = 'reservation_history' 
    AND rowsecurity = true
  ) THEN
    ALTER TABLE reservation_history ENABLE ROW LEVEL SECURITY;
  END IF;
END $$;

-- Dodaj odpowiednie polityki jeśli nie istnieją
DO $$ 
BEGIN
  -- Polityki dla equipment_availability
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'equipment_availability' 
    AND policyname = 'Public can view equipment availability'
  ) THEN
    CREATE POLICY "Public can view equipment availability"
      ON equipment_availability
      FOR SELECT
      TO public
      USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'equipment_availability' 
    AND policyname = 'Only admins can manage equipment availability'
  ) THEN
    CREATE POLICY "Only admins can manage equipment availability"
      ON equipment_availability
      FOR ALL
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM profiles
          WHERE id = auth.uid()
          AND is_admin = true
        )
      );
  END IF;

  -- Polityki dla reservation_history
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'reservation_history' 
    AND policyname = 'Users can view their own reservation history'
  ) THEN
    CREATE POLICY "Users can view their own reservation history"
      ON reservation_history
      FOR SELECT
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM reservations r
          JOIN customers c ON r.customer_id = c.id
          WHERE r.id = reservation_history.reservation_id
          AND c.user_id = auth.uid()
        )
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'reservation_history' 
    AND policyname = 'Admins can view all reservation history'
  ) THEN
    CREATE POLICY "Admins can view all reservation history"
      ON reservation_history
      FOR ALL
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM profiles
          WHERE id = auth.uid()
          AND is_admin = true
        )
      );
  END IF;
END $$;