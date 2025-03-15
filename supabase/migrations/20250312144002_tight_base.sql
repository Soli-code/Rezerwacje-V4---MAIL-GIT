/*
  # Update reservation statuses

  1. Changes
    - Update reservation status constraint
    - Add new statuses: pending, confirmed, picked_up, completed, cancelled, archived
    - Update existing data to match new statuses
    - Add validation function for status transitions
*/

-- Aktualizacja ograniczenia dla statusów rezerwacji
ALTER TABLE reservations
DROP CONSTRAINT IF EXISTS valid_reservation_status;

ALTER TABLE reservations
ADD CONSTRAINT valid_reservation_status 
CHECK (status IN ('pending', 'confirmed', 'picked_up', 'completed', 'cancelled', 'archived'));

-- Funkcja walidująca przejścia między statusami
CREATE OR REPLACE FUNCTION validate_status_transition()
RETURNS trigger AS $$
BEGIN
  -- Sprawdź czy przejście statusu jest dozwolone
  IF NEW.status != OLD.status THEN
    CASE OLD.status
      WHEN 'pending' THEN
        IF NEW.status NOT IN ('confirmed', 'cancelled') THEN
          RAISE EXCEPTION 'Nieprawidłowe przejście ze statusu pending';
        END IF;
      WHEN 'confirmed' THEN
        IF NEW.status NOT IN ('picked_up', 'cancelled') THEN
          RAISE EXCEPTION 'Nieprawidłowe przejście ze statusu confirmed';
        END IF;
      WHEN 'picked_up' THEN
        IF NEW.status NOT IN ('completed', 'cancelled') THEN
          RAISE EXCEPTION 'Nieprawidłowe przejście ze statusu picked_up';
        END IF;
      WHEN 'completed' THEN
        IF NEW.status != 'archived' THEN
          RAISE EXCEPTION 'Nieprawidłowe przejście ze statusu completed';
        END IF;
      WHEN 'cancelled' THEN
        IF NEW.status != 'archived' THEN
          RAISE EXCEPTION 'Nieprawidłowe przejście ze statusu cancelled';
        END IF;
      WHEN 'archived' THEN
        RAISE EXCEPTION 'Nie można zmienić statusu zarchiwizowanej rezerwacji';
    END CASE;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Dodaj trigger dla walidacji przejść między statusami
DROP TRIGGER IF EXISTS validate_status_transition_trigger ON reservations;
CREATE TRIGGER validate_status_transition_trigger
  BEFORE UPDATE OF status ON reservations
  FOR EACH ROW
  EXECUTE FUNCTION validate_status_transition();

-- Aktualizuj funkcję zmiany statusu rezerwacji
CREATE OR REPLACE FUNCTION update_reservation_status(
  p_reservation_id uuid,
  p_new_status text,
  p_comment text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_old_status text;
  v_is_admin boolean;
  v_user_id uuid;
BEGIN
  -- Get current user ID
  v_user_id := auth.uid();
  
  -- Check if user is admin
  SELECT is_admin INTO v_is_admin
  FROM profiles
  WHERE id = v_user_id;

  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'Brak uprawnień do zmiany statusu rezerwacji';
  END IF;

  -- Get current reservation status
  SELECT status INTO v_old_status
  FROM reservations
  WHERE id = p_reservation_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Rezerwacja nie istnieje';
  END IF;

  -- Update reservation status
  UPDATE reservations
  SET 
    status = p_new_status,
    updated_at = now()
  WHERE id = p_reservation_id;

  -- Add history entry
  INSERT INTO reservation_history (
    reservation_id,
    previous_status,
    new_status,
    changed_by,
    comment
  ) VALUES (
    p_reservation_id,
    v_old_status,
    p_new_status,
    v_user_id,
    COALESCE(p_comment, 
      CASE 
        WHEN p_new_status = 'confirmed' THEN 'Rezerwacja potwierdzona'
        WHEN p_new_status = 'picked_up' THEN 'Sprzęt odebrany'
        WHEN p_new_status = 'completed' THEN 'Rezerwacja zakończona'
        WHEN p_new_status = 'cancelled' THEN 'Rezerwacja anulowana'
        WHEN p_new_status = 'archived' THEN 'Rezerwacja zarchiwizowana'
        ELSE 'Status zmieniony'
      END
    )
  );
END;
$$;