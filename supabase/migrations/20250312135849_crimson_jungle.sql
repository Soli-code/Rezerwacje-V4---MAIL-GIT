/*
  # Fix pipeline data function

  1. Changes
    - Poprawione grupowanie danych w funkcji get_pipeline_data
    - Dodane indeksy dla optymalizacji
    - Uproszczona struktura zapytania
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
    WHERE r.status IN ('pending', 'confirmed', 'completed')
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
      )
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- Dodaj indeksy dla optymalizacji
CREATE INDEX IF NOT EXISTS idx_reservations_status_start_date 
ON reservations(status, start_date);

CREATE INDEX IF NOT EXISTS idx_reservations_status_updated_at 
ON reservations(status, updated_at);

COMMENT ON FUNCTION get_pipeline_data IS 'Zwraca dane dla widoku pipeline z rezerwacjami';