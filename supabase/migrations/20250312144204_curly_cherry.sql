/*
  # Update reservation status transitions

  1. Changes
    - Update status transition validation function
    - Add new valid status transitions
    - Fix transition from confirmed status
*/

-- Aktualizacja funkcji walidującej przejścia między statusami
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
        IF NEW.status NOT IN ('picked_up', 'cancelled', 'completed') THEN
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