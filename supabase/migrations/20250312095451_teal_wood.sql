-- Najpierw usuń wszystkie istniejące polityki dla reservation_history
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "Admins can manage reservation history" ON reservation_history;
  DROP POLICY IF EXISTS "Users can view their own reservation history" ON reservation_history;
  DROP POLICY IF EXISTS "Admins can view all reservation history" ON reservation_history;
  DROP POLICY IF EXISTS "Admins can manage all reservation history" ON reservation_history;
EXCEPTION
  WHEN undefined_object THEN NULL;
END $$;

-- Włącz RLS jeśli nie jest włączone
ALTER TABLE reservation_history ENABLE ROW LEVEL SECURITY;

-- Dodaj nową politykę z uprawnieniami INSERT
CREATE POLICY "Admins can manage all reservation history"
  ON reservation_history
  FOR ALL
  TO authenticated
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

-- Zaktualizuj funkcję aktualizacji statusu rezerwacji
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
  -- Pobierz ID użytkownika
  v_user_id := auth.uid();
  
  -- Sprawdź czy użytkownik jest administratorem
  SELECT is_admin INTO v_is_admin
  FROM profiles
  WHERE id = v_user_id;

  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'Brak uprawnień do zmiany statusu rezerwacji';
  END IF;

  -- Pobierz aktualny status
  SELECT status INTO v_old_status
  FROM reservations
  WHERE id = p_reservation_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Rezerwacja nie istnieje';
  END IF;

  -- Zaktualizuj status rezerwacji
  UPDATE reservations
  SET 
    status = p_new_status,
    updated_at = now()
  WHERE id = p_reservation_id;

  -- Dodaj wpis do historii
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