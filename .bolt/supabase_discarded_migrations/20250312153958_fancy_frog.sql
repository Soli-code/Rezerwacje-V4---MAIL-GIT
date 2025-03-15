/*
  # System zarządzania statusami rezerwacji

  1. Aktualizacja tabeli reservations
    - Dodanie nowych statusów
    - Dodanie kolumny is_reversed dla śledzenia cofniętych statusów
    
  2. Funkcje
    - validate_status_transition - walidacja przejść między statusami
    - update_reservation_status - aktualizacja statusu z historią zmian
*/

-- Aktualizacja ograniczenia dla statusów rezerwacji
ALTER TABLE reservations
DROP CONSTRAINT IF EXISTS valid_reservation_status;

ALTER TABLE reservations
ADD CONSTRAINT valid_reservation_status 
CHECK (status IN ('pending', 'confirmed', 'picked_up', 'completed', 'cancelled', 'archived'));

-- Dodaj kolumnę do oznaczania cofniętych statusów
ALTER TABLE reservations
ADD COLUMN IF NOT EXISTS is_reversed boolean DEFAULT false;

-- Funkcja walidująca przejścia między statusami
CREATE OR REPLACE FUNCTION validate_status_transition()
RETURNS trigger AS $$
BEGIN
  -- Sprawdź czy przejście statusu jest dozwolone
  IF NEW.status != OLD.status THEN
    -- Ustaw flagę cofnięcia statusu
    NEW.is_reversed := CASE
      -- Przejścia wsteczne
      WHEN OLD.status = 'completed' AND NEW.status IN ('picked_up', 'confirmed', 'pending') THEN true
      WHEN OLD.status = 'picked_up' AND NEW.status IN ('confirmed', 'pending') THEN true
      WHEN OLD.status = 'confirmed' AND NEW.status = 'pending' THEN true
      WHEN OLD.status = 'archived' AND NEW.status IN ('completed', 'picked_up', 'confirmed', 'pending') THEN true
      ELSE false
    END;

    -- Walidacja przejść
    CASE OLD.status
      WHEN 'pending' THEN
        IF NEW.status NOT IN ('confirmed', 'cancelled') THEN
          RAISE EXCEPTION 'Nieprawidłowe przejście ze statusu pending';
        END IF;
      WHEN 'confirmed' THEN
        IF NEW.status NOT IN ('picked_up', 'cancelled', 'pending') THEN
          RAISE EXCEPTION 'Nieprawidłowe przejście ze statusu confirmed';
        END IF;
      WHEN 'picked_up' THEN
        IF NEW.status NOT IN ('completed', 'cancelled', 'confirmed') THEN
          RAISE EXCEPTION 'Nieprawidłowe przejście ze statusu picked_up';
        END IF;
      WHEN 'completed' THEN
        IF NEW.status NOT IN ('archived', 'picked_up') THEN
          RAISE EXCEPTION 'Nieprawidłowe przejście ze statusu completed';
        END IF;
      WHEN 'cancelled' THEN
        IF NEW.status NOT IN ('archived', 'pending') THEN
          RAISE EXCEPTION 'Nieprawidłowe przejście ze statusu cancelled';
        END IF;
      WHEN 'archived' THEN
        IF NEW.status NOT IN ('completed', 'picked_up', 'confirmed', 'pending') THEN
          RAISE EXCEPTION 'Nieprawidłowe przejście ze statusu archived';
        END IF;
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

-- Funkcja do aktualizacji statusu rezerwacji
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
  v_is_reversed boolean;
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

  -- Sprawdź czy to przejście wsteczne
  v_is_reversed := CASE
    WHEN v_old_status = 'completed' AND p_new_status IN ('picked_up', 'confirmed', 'pending') THEN true
    WHEN v_old_status = 'picked_up' AND p_new_status IN ('confirmed', 'pending') THEN true
    WHEN v_old_status = 'confirmed' AND p_new_status = 'pending' THEN true
    WHEN v_old_status = 'archived' AND p_new_status IN ('completed', 'picked_up', 'confirmed', 'pending') THEN true
    ELSE false
  END;

  -- Wymagaj komentarza przy cofaniu statusu
  IF v_is_reversed AND p_comment IS NULL THEN
    RAISE EXCEPTION 'Wymagany komentarz przy cofaniu statusu rezerwacji';
  END IF;

  -- Update reservation status
  UPDATE reservations
  SET 
    status = p_new_status,
    is_reversed = v_is_reversed,
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
        WHEN v_is_reversed THEN 'Status cofnięty do: ' || p_new_status
        ELSE CASE
          WHEN p_new_status = 'confirmed' THEN 'Rezerwacja potwierdzona'
          WHEN p_new_status = 'picked_up' THEN 'Sprzęt odebrany'
          WHEN p_new_status = 'completed' THEN 'Rezerwacja zakończona'
          WHEN p_new_status = 'cancelled' THEN 'Rezerwacja anulowana'
          WHEN p_new_status = 'archived' THEN 'Rezerwacja zarchiwizowana'
          ELSE 'Status zmieniony'
        END
      END
    )
  );
END;
$$;

-- Funkcja do automatycznej archiwizacji zakończonych rezerwacji
CREATE OR REPLACE FUNCTION archive_completed_reservations()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Przenieś zakończone rezerwacje starsze niż 24h do archiwum
  UPDATE reservations
  SET status = 'archived'
  WHERE status = 'completed'
  AND updated_at < now() - interval '24 hours';
END;
$$;

-- Trigger do automatycznej archiwizacji
CREATE OR REPLACE FUNCTION check_reservation_archive()
RETURNS trigger AS $$
BEGIN
  -- Jeśli rezerwacja jest zakończona i minęło 24h, oznacz jako zarchiwizowaną
  IF NEW.status = 'completed' AND 
     NEW.updated_at < now() - interval '24 hours' THEN
    NEW.status := 'archived';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Dodaj trigger do tabeli reservations
DROP TRIGGER IF EXISTS check_reservation_archive_trigger ON reservations;
CREATE TRIGGER check_reservation_archive_trigger
  BEFORE UPDATE ON reservations
  FOR EACH ROW
  EXECUTE FUNCTION check_reservation_archive();

-- Dodaj indeksy dla optymalizacji
CREATE INDEX IF NOT EXISTS idx_reservations_status_updated_at 
ON reservations(status, updated_at);

COMMENT ON FUNCTION update_reservation_status IS 'Aktualizuje status rezerwacji z walidacją i historią zmian';
COMMENT ON FUNCTION archive_completed_reservations IS 'Automatycznie archiwizuje zakończone rezerwacje po 24h';