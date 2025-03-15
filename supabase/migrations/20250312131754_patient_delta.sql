/*
  # Add updated_at column to reservations table

  1. Changes
    - Add updated_at column if not exists
    - Add trigger to automatically update updated_at
    - Update function to handle status changes
*/

-- Add updated_at column if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'reservations' 
    AND column_name = 'updated_at'
  ) THEN
    ALTER TABLE reservations 
    ADD COLUMN updated_at timestamptz DEFAULT now();
  END IF;
END $$;

-- Create or replace trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS update_reservations_updated_at ON reservations;
CREATE TRIGGER update_reservations_updated_at
  BEFORE UPDATE ON reservations
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Update function to handle status changes
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
    status = p_new_status
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
        WHEN p_new_status = 'cancelled' THEN 'Rezerwacja anulowana'
        WHEN p_new_status = 'completed' THEN 'Rezerwacja zakończona'
        ELSE 'Status zmieniony'
      END
    )
  );
END;
$$;