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
      c.id as customer_id,
      c.first_name,
      c.last_name,
      c.email,
      c.phone,
      c.company_name,
      c.company_nip
    FROM reservations r
    JOIN customers c ON c.id = r.customer_id
    WHERE r.status != 'cancelled'
    AND r.status IN ('pending', 'confirmed', 'completed')
  )
  SELECT jsonb_build_object(
    'columns', jsonb_build_array(
      jsonb_build_object(
        'id', 'pending',
        'title', 'Oczekujące',
        'reservations', (
          SELECT jsonb_agg(
            jsonb_build_object(
              'id', pd.id,
              'customer', jsonb_build_object(
                'id', pd.customer_id,
                'first_name', pd.first_name,
                'last_name', pd.last_name,
                'email', pd.email,
                'phone', pd.phone,
                'company_name', pd.company_name,
                'company_nip', pd.company_nip
              ),
              'dates', jsonb_build_object(
                'start', pd.start_date,
                'end', pd.end_date
              ),
              'total_price', pd.total_price,
              'items', (
                SELECT jsonb_agg(
                  jsonb_build_object(
                    'id', ri.id,
                    'equipment_name', e.name,
                    'quantity', ri.quantity
                  )
                )
                FROM reservation_items ri
                JOIN equipment e ON e.id = ri.equipment_id
                WHERE ri.reservation_id = pd.id
              ),
              'history', (
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
                WHERE rh.reservation_id = pd.id
              )
            )
          )
          FROM pipeline_data pd
          WHERE pd.status = 'pending'
          ORDER BY pd.start_date ASC
        )
      ),
      jsonb_build_object(
        'id', 'confirmed',
        'title', 'Potwierdzone',
        'reservations', (
          SELECT jsonb_agg(
            jsonb_build_object(
              'id', pd.id,
              'customer', jsonb_build_object(
                'id', pd.customer_id,
                'first_name', pd.first_name,
                'last_name', pd.last_name,
                'email', pd.email,
                'phone', pd.phone,
                'company_name', pd.company_name,
                'company_nip', pd.company_nip
              ),
              'dates', jsonb_build_object(
                'start', pd.start_date,
                'end', pd.end_date
              ),
              'total_price', pd.total_price,
              'items', (
                SELECT jsonb_agg(
                  jsonb_build_object(
                    'id', ri.id,
                    'equipment_name', e.name,
                    'quantity', ri.quantity
                  )
                )
                FROM reservation_items ri
                JOIN equipment e ON e.id = ri.equipment_id
                WHERE ri.reservation_id = pd.id
              ),
              'history', (
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
                WHERE rh.reservation_id = pd.id
              )
            )
          )
          FROM pipeline_data pd
          WHERE pd.status = 'confirmed'
          ORDER BY pd.start_date ASC
        )
      ),
      jsonb_build_object(
        'id', 'completed',
        'title', 'Zakończone',
        'reservations', (
          SELECT jsonb_agg(
            jsonb_build_object(
              'id', pd.id,
              'customer', jsonb_build_object(
                'id', pd.customer_id,
                'first_name', pd.first_name,
                'last_name', pd.last_name,
                'email', pd.email,
                'phone', pd.phone,
                'company_name', pd.company_name,
                'company_nip', pd.company_nip
              ),
              'dates', jsonb_build_object(
                'start', pd.start_date,
                'end', pd.end_date
              ),
              'total_price', pd.total_price,
              'items', (
                SELECT jsonb_agg(
                  jsonb_build_object(
                    'id', ri.id,
                    'equipment_name', e.name,
                    'quantity', ri.quantity
                  )
                )
                FROM reservation_items ri
                JOIN equipment e ON e.id = ri.equipment_id
                WHERE ri.reservation_id = pd.id
              ),
              'history', (
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
                WHERE rh.reservation_id = pd.id
              )
            )
          )
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

COMMENT ON FUNCTION get_pipeline_data IS 'Zwraca dane dla widoku pipeline z rezerwacjami';