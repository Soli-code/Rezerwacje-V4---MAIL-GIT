-- Funkcja do pobierania danych pipeline'a
CREATE OR REPLACE FUNCTION get_admin_pipeline_data(
  p_date_range text DEFAULT '30days',
  p_status text[] DEFAULT ARRAY['pending', 'confirmed', 'completed']
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_start_date timestamptz;
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

  -- Ustaw zakres dat
  v_start_date := CASE p_date_range
    WHEN '7days' THEN now() - interval '7 days'
    WHEN '30days' THEN now() - interval '30 days'
    WHEN '90days' THEN now() - interval '90 days'
    ELSE now() - interval '30 days'
  END;

  WITH reservation_data AS (
    SELECT 
      r.id,
      r.status,
      r.start_date,
      r.end_date,
      r.total_price,
      jsonb_build_object(
        'id', c.id,
        'first_name', c.first_name,
        'last_name', c.last_name,
        'email', c.email,
        'phone', c.phone
      ) as customer,
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
      ) as items
    FROM reservations r
    JOIN customers c ON c.id = r.customer_id
    WHERE r.status = ANY(p_status)
    AND r.created_at >= v_start_date
    GROUP BY r.id, c.id
  )
  SELECT jsonb_build_object(
    'columns', (
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', col_status,
          'title', 
          CASE col_status
            WHEN 'pending' THEN 'Oczekujące'
            WHEN 'confirmed' THEN 'Potwierdzone'
            WHEN 'completed' THEN 'Zakończone'
          END,
          'reservations', (
            SELECT jsonb_agg(
              jsonb_build_object(
                'id', rd.id,
                'customer', rd.customer,
                'dates', jsonb_build_object(
                  'start', rd.start_date,
                  'end', rd.end_date
                ),
                'total_price', rd.total_price,
                'items', rd.items
              )
              ORDER BY rd.start_date DESC
            )
            FROM reservation_data rd
            WHERE rd.status = col_status
          )
        )
      )
      FROM unnest(p_status) as col_status
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- Dodaj indeks dla optymalizacji
CREATE INDEX IF NOT EXISTS idx_reservations_created_at_status 
ON reservations(created_at, status);

COMMENT ON FUNCTION get_admin_pipeline_data IS 'Zwraca dane dla widoku pipeline rezerwacji z poprawnym grupowaniem';