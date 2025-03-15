-- Drop existing policies
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "Admins can manage reservation history" ON reservation_history;
  DROP POLICY IF EXISTS "Users can view their own reservation history" ON reservation_history;
  DROP POLICY IF EXISTS "Admins can view all reservation history" ON reservation_history;
  DROP POLICY IF EXISTS "Admins can manage all reservation history" ON reservation_history;
EXCEPTION
  WHEN undefined_object THEN NULL;
END $$;

-- Enable RLS
ALTER TABLE reservation_history ENABLE ROW LEVEL SECURITY;

-- Create single policy for all operations
CREATE POLICY "Admins can manage all reservation history"
  ON reservation_history
  FOR ALL
  TO public
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.is_admin = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.is_admin = true
    )
  );

-- Drop existing function if exists
DROP FUNCTION IF EXISTS update_reservation_status(uuid, text, text);

-- Create new function with SECURITY DEFINER and proper schema search path
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

  -- Add history entry with elevated privileges
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