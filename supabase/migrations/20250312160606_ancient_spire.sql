/*
  # Fix reservation status function

  1. Changes
    - Drop all existing versions of update_reservation_status function
    - Create single version with proper signature and implementation
    - Update status validation
*/

-- Drop all existing versions of the function
DO $$ 
BEGIN
  DROP FUNCTION IF EXISTS update_reservation_status(uuid, text);
  DROP FUNCTION IF EXISTS update_reservation_status(uuid, text, text);
  DROP FUNCTION IF EXISTS update_reservation_status(uuid, text, text, boolean);
EXCEPTION
  WHEN others THEN NULL;
END $$;

-- Create single version of the function
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