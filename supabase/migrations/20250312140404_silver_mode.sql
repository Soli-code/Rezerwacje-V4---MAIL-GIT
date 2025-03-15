/*
  # Update pipeline system

  1. Changes
    - Add new reservation statuses
    - Update pipeline data function
    - Add automatic archiving
    
  2. Status Flow
    - pending -> confirmed -> picked_up -> completed -> cancelled -> archived
*/

-- Aktualizacja statusów rezerwacji
ALTER TABLE reservations
DROP CONSTRAINT IF EXISTS valid_reservation_status;

ALTER TABLE reservations
ADD CONSTRAINT valid_reservation_status 
CHECK (status IN ('pending', 'confirmed', 'picked_up', 'completed', 'cancelled', 'archived'));

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

  -- Pobierz dane
  WITH reservation_data AS (
    SELECT 
      r.id,
      r.status,
      r.start_date,
      r.end_date,
      r.total_price,
      r.updated_at,
      c.id as customer_id,
      c.first_name,
      c.last_name,
      c.email,
      c.phone,
      c.company_name,
      c.company_nip,
      (
        SELECT jsonb_agg(
          jsonb_build_object(
            'id', ri.id,
            'equipment_name', e.name,
            'quantity', ri.quantity
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
    WHERE r.status IN ('pending', 'confirmed', 'picked_up', 'completed', 'cancelled', 'archived')
    GROUP BY r.id, c.id
  )
  SELECT jsonb_build_object(
    'columns', jsonb_build_array(
      jsonb_build_object(
        'id', 'pending',
        'title', 'Oczekujące',
        'reservations', COALESCE((
          SELECT jsonb_agg(
            jsonb_build_object(
              'id', rd.id,
              'customer', jsonb_build_object(
                'id', rd.customer_id,
                'first_name', rd.first_name,
                'last_name', rd.last_name,
                'email', rd.email,
                'phone', rd.phone,
                'company_name', rd.company_name,
                'company_nip', rd.company_nip
              ),
              'dates', jsonb_build_object(
                'start', rd.start_date,
                'end', rd.end_date
              ),
              'total_price', rd.total_price,
              'items', rd.items,
              'history', rd.history
            )
            ORDER BY rd.start_date ASC
          )
          FROM reservation_data rd
          WHERE rd.status = 'pending'
        ), '[]'::jsonb)
      ),
      jsonb_build_object(
        'id', 'confirmed',
        'title', 'Potwierdzone',
        'reservations', COALESCE((
          SELECT jsonb_agg(
            jsonb_build_object(
              'id', rd.id,
              'customer', jsonb_build_object(
                'id', rd.customer_id,
                'first_name', rd.first_name,
                'last_name', rd.last_name,
                'email', rd.email,
                'phone', rd.phone,
                'company_name', rd.company_name,
                'company_nip', rd.company_nip
              ),
              'dates', jsonb_build_object(
                'start', rd.start_date,
                'end', rd.end_date
              ),
              'total_price', rd.total_price,
              'items', rd.items,
              'history', rd.history
            )
            ORDER BY rd.start_date ASC
          )
          FROM reservation_data rd
          WHERE rd.status = 'confirmed'
        ), '[]'::jsonb)
      ),
      jsonb_build_object(
        'id', 'picked_up',
        'title', 'Odebrane',
        'reservations', COALESCE((
          SELECT jsonb_agg(
            jsonb_build_object(
              'id', rd.id,
              'customer', jsonb_build_object(
                'id', rd.customer_id,
                'first_name', rd.first_name,
                'last_name', rd.last_name,
                'email', rd.email,
                'phone', rd.phone,
                'company_name', rd.company_name,
                'company_nip', rd.company_nip
              ),
              'dates', jsonb_build_object(
                'start', rd.start_date,
                'end', rd.end_date
              ),
              'total_price', rd.total_price,
              'items', rd.items,
              'history', rd.history
            )
            ORDER BY rd.start_date ASC
          )
          FROM reservation_data rd
          WHERE rd.status = 'picked_up'
        ), '[]'::jsonb)
      ),
      jsonb_build_object(
        'id', 'completed',
        'title', 'Zakończone',
        'reservations', COALESCE((
          SELECT jsonb_agg(
            jsonb_build_object(
              'id', rd.id,
              'customer', jsonb_build_object(
                'id', rd.customer_id,
                'first_name', rd.first_name,
                'last_name', rd.last_name,
                'email', rd.email,
                'phone', rd.phone,
                'company_name', rd.company_name,
                'company_nip', rd.company_nip
              ),
              'dates', jsonb_build_object(
                'start', rd.start_date,
                'end', rd.end_date
              ),
              'total_price', rd.total_price,
              'items', rd.items,
              'history', rd.history
            )
            ORDER BY rd.updated_at DESC
          )
          FROM reservation_data rd
          WHERE rd.status = 'completed'
          AND rd.updated_at >= now() - interval '24 hours'
        ), '[]'::jsonb)
      ),
      jsonb_build_object(
        'id', 'cancelled',
        'title', 'Anulowane',
        'reservations', COALESCE((
          SELECT jsonb_agg(
            jsonb_build_object(
              'id', rd.id,
              'customer', jsonb_build_object(
                'id', rd.customer_id,
                'first_name', rd.first_name,
                'last_name', rd.last_name,
                'email', rd.email,
                'phone', rd.phone,
                'company_name', rd.company_name,
                'company_nip', rd.company_nip
              ),
              'dates', jsonb_build_object(
                'start', rd.start_date,
                'end', rd.end_date
              ),
              'total_price', rd.total_price,
              'items', rd.items,
              'history', rd.history
            )
            ORDER BY rd.updated_at DESC
          )
          FROM reservation_data rd
          WHERE rd.status = 'cancelled'
          AND rd.updated_at >= now() - interval '24 hours'
        ), '[]'::jsonb)
      ),
      jsonb_build_object(
        'id', 'archived',
        'title', 'Historyczne',
        'reservations', COALESCE((
          SELECT jsonb_agg(
            jsonb_build_object(
              'id', rd.id,
              'customer', jsonb_build_object(
                'id', rd.customer_id,
                'first_name', rd.first_name,
                'last_name', rd.last_name,
                'email', rd.email,
                'phone', rd.phone,
                'company_name', rd.company_name,
                'company_nip', rd.company_nip
              ),
              'dates', jsonb_build_object(
                'start', rd.start_date,
                'end', rd.end_date
              ),
              'total_price', rd.total_price,
              'items', rd.items,
              'history', rd.history
            )
            ORDER BY rd.updated_at DESC
          )
          FROM reservation_data rd
          WHERE rd.status = 'archived'
        ), '[]'::jsonb)
      )
    )
  ) INTO v_result;

  RETURN v_result;
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

COMMENT ON FUNCTION get_pipeline_data IS 'Zwraca dane dla widoku pipeline z rezerwacjami';
COMMENT ON FUNCTION archive_completed_reservations IS 'Automatycznie archiwizuje zakończone rezerwacje po 24h';