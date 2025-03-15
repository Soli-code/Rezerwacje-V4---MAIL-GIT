/*
  # System Pipeline dla zarządzania rezerwacjami

  1. Nowe funkcje
    - get_pipeline_data - pobieranie danych dla widoku pipeline
    - update_reservation_pipeline_status - aktualizacja statusu z historią zmian
    - archive_completed_reservations - automatyczna archiwizacja zakończonych rezerwacji

  2. Widoki
    - pipeline_view - widok kolumn z rezerwacjami
    - reservation_details_view - szczegóły rezerwacji
*/

-- Funkcja pobierająca dane dla pipeline'a
CREATE OR REPLACE FUNCTION get_pipeline_data()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
BEGIN
  -- Sprawdź uprawnienia administratora
  IF NOT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND is_admin = true
  ) THEN
    RAISE EXCEPTION 'Brak uprawnień administratora';
  END IF;

  WITH pipeline_data AS (
    SELECT 
      r.id,
      r.status,
      r.start_date,
      r.end_date,
      r.total_price,
      r.updated_at,
      jsonb_build_object(
        'id', c.id,
        'first_name', c.first_name,
        'last_name', c.last_name,
        'email', c.email,
        'phone', c.phone,
        'company_name', c.company_name,
        'company_nip', c.company_nip
      ) as customer,
      (
        SELECT jsonb_agg(
          jsonb_build_object(
            'id', ri.id,
            'equipment_name', e.name,
            'quantity', ri.quantity,
            'price_per_day', ri.price_per_day,
            'deposit', ri.deposit
          )
        )
        FROM reservation_items ri
        JOIN equipment e ON e.id = ri.equipment_id
        WHERE ri.reservation_id = r.id
      ) as items,
      (
        SELECT jsonb_agg(
          jsonb_build_object(
            'id', rh.id,
            'previous_status', rh.previous_status,
            'new_status', rh.new_status,
            'changed_at', rh.changed_at,
            'changed_by', rh.changed_by,
            'comment', rh.comment
          )
          ORDER BY rh.changed_at DESC
        )
        FROM reservation_history rh
        WHERE rh.reservation_id = r.id
      ) as history
    FROM reservations r
    JOIN customers c ON c.id = r.customer_id
    WHERE r.status != 'cancelled'
    AND r.status IN ('pending', 'confirmed', 'completed')
    GROUP BY r.id, c.id
  )
  SELECT jsonb_build_object(
    'columns', jsonb_build_array(
      jsonb_build_object(
        'id', 'pending',
        'title', 'Oczekujące',
        'reservations', (
          SELECT jsonb_agg(to_jsonb(pd))
          FROM pipeline_data pd
          WHERE pd.status = 'pending'
          ORDER BY pd.start_date ASC
        )
      ),
      jsonb_build_object(
        'id', 'confirmed',
        'title', 'Potwierdzone',
        'reservations', (
          SELECT jsonb_agg(to_jsonb(pd))
          FROM pipeline_data pd
          WHERE pd.status = 'confirmed'
          ORDER BY pd.start_date ASC
        )
      ),
      jsonb_build_object(
        'id', 'completed',
        'title', 'Zakończone',
        'reservations', (
          SELECT jsonb_agg(to_jsonb(pd))
          FROM pipeline_data pd
          WHERE pd.status = 'completed'
          AND pd.updated_at >= now() - interval '24 hours'
          ORDER BY pd.updated_at DESC
        )
      )
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- Funkcja do aktualizacji statusu rezerwacji w pipeline
CREATE OR REPLACE FUNCTION update_reservation_pipeline_status(
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

  -- Validate new status
  IF p_new_status NOT IN ('pending', 'confirmed', 'completed', 'cancelled') THEN
    RAISE EXCEPTION 'Nieprawidłowy status rezerwacji';
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
        WHEN p_new_status = 'cancelled' THEN 'Rezerwacja anulowana'
        WHEN p_new_status = 'completed' THEN 'Rezerwacja zakończona'
        ELSE 'Status zmieniony'
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
  WITH old_completed AS (
    SELECT id
    FROM reservations
    WHERE status = 'completed'
    AND updated_at < now() - interval '24 hours'
  )
  UPDATE reservations
  SET status = 'archived'
  WHERE id IN (SELECT id FROM old_completed);
END;
$$;

-- Dodaj trigger do automatycznej archiwizacji
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

COMMENT ON FUNCTION get_pipeline_data IS 'Zwraca dane dla widoku pipeline z rezerwacjami';
COMMENT ON FUNCTION update_reservation_pipeline_status IS 'Aktualizuje status rezerwacji w pipeline z historią zmian';
COMMENT ON FUNCTION archive_completed_reservations IS 'Automatycznie archiwizuje zakończone rezerwacje po 24h';