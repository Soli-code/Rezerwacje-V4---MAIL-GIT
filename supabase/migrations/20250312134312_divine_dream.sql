/*
  # Fix pipeline data function

  1. Changes
    - Remove unnecessary grouping
    - Fix data aggregation
    - Improve query performance
*/

-- Drop existing function
DROP FUNCTION IF EXISTS get_pipeline_data();

-- Create new function with fixed grouping
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
  SELECT jsonb_build_object(
    'columns', jsonb_build_array(
      jsonb_build_object(
        'id', 'pending',
        'title', 'Oczekujące',
        'reservations', (
          SELECT COALESCE(jsonb_agg(
            jsonb_build_object(
              'id', r.id,
              'customer', jsonb_build_object(
                'id', c.id,
                'first_name', c.first_name,
                'last_name', c.last_name,
                'email', c.email,
                'phone', c.phone,
                'company_name', c.company_name,
                'company_nip', c.company_nip
              ),
              'dates', jsonb_build_object(
                'start', r.start_date,
                'end', r.end_date
              ),
              'total_price', r.total_price,
              'items', (
                SELECT COALESCE(jsonb_agg(
                  jsonb_build_object(
                    'id', ri.id,
                    'equipment_name', e.name,
                    'quantity', ri.quantity
                  )
                ), '[]'::jsonb)
                FROM reservation_items ri
                JOIN equipment e ON e.id = ri.equipment_id
                WHERE ri.reservation_id = r.id
              ),
              'history', (
                SELECT COALESCE(jsonb_agg(
                  jsonb_build_object(
                    'id', rh.id,
                    'previous_status', rh.previous_status,
                    'new_status', rh.new_status,
                    'changed_at', rh.changed_at,
                    'changed_by', rh.changed_by,
                    'comment', rh.comment
                  )
                  ORDER BY rh.changed_at DESC
                ), '[]'::jsonb)
                FROM reservation_history rh
                WHERE rh.reservation_id = r.id
              )
            )
            ORDER BY r.start_date ASC
          ), '[]'::jsonb)
          FROM reservations r
          JOIN customers c ON c.id = r.customer_id
          WHERE r.status = 'pending'
        )
      ),
      jsonb_build_object(
        'id', 'confirmed',
        'title', 'Potwierdzone',
        'reservations', (
          SELECT COALESCE(jsonb_agg(
            jsonb_build_object(
              'id', r.id,
              'customer', jsonb_build_object(
                'id', c.id,
                'first_name', c.first_name,
                'last_name', c.last_name,
                'email', c.email,
                'phone', c.phone,
                'company_name', c.company_name,
                'company_nip', c.company_nip
              ),
              'dates', jsonb_build_object(
                'start', r.start_date,
                'end', r.end_date
              ),
              'total_price', r.total_price,
              'items', (
                SELECT COALESCE(jsonb_agg(
                  jsonb_build_object(
                    'id', ri.id,
                    'equipment_name', e.name,
                    'quantity', ri.quantity
                  )
                ), '[]'::jsonb)
                FROM reservation_items ri
                JOIN equipment e ON e.id = ri.equipment_id
                WHERE ri.reservation_id = r.id
              ),
              'history', (
                SELECT COALESCE(jsonb_agg(
                  jsonb_build_object(
                    'id', rh.id,
                    'previous_status', rh.previous_status,
                    'new_status', rh.new_status,
                    'changed_at', rh.changed_at,
                    'changed_by', rh.changed_by,
                    'comment', rh.comment
                  )
                  ORDER BY rh.changed_at DESC
                ), '[]'::jsonb)
                FROM reservation_history rh
                WHERE rh.reservation_id = r.id
              )
            )
            ORDER BY r.start_date ASC
          ), '[]'::jsonb)
          FROM reservations r
          JOIN customers c ON c.id = r.customer_id
          WHERE r.status = 'confirmed'
        )
      ),
      jsonb_build_object(
        'id', 'completed',
        'title', 'Zakończone',
        'reservations', (
          SELECT COALESCE(jsonb_agg(
            jsonb_build_object(
              'id', r.id,
              'customer', jsonb_build_object(
                'id', c.id,
                'first_name', c.first_name,
                'last_name', c.last_name,
                'email', c.email,
                'phone', c.phone,
                'company_name', c.company_name,
                'company_nip', c.company_nip
              ),
              'dates', jsonb_build_object(
                'start', r.start_date,
                'end', r.end_date
              ),
              'total_price', r.total_price,
              'items', (
                SELECT COALESCE(jsonb_agg(
                  jsonb_build_object(
                    'id', ri.id,
                    'equipment_name', e.name,
                    'quantity', ri.quantity
                  )
                ), '[]'::jsonb)
                FROM reservation_items ri
                JOIN equipment e ON e.id = ri.equipment_id
                WHERE ri.reservation_id = r.id
              ),
              'history', (
                SELECT COALESCE(jsonb_agg(
                  jsonb_build_object(
                    'id', rh.id,
                    'previous_status', rh.previous_status,
                    'new_status', rh.new_status,
                    'changed_at', rh.changed_at,
                    'changed_by', rh.changed_by,
                    'comment', rh.comment
                  )
                  ORDER BY rh.changed_at DESC
                ), '[]'::jsonb)
                FROM reservation_history rh
                WHERE rh.reservation_id = r.id
              )
            )
            ORDER BY r.updated_at DESC
          ), '[]'::jsonb)
          FROM reservations r
          JOIN customers c ON c.id = r.customer_id
          WHERE r.status = 'completed'
          AND r.updated_at >= now() - interval '24 hours'
        )
      )
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_reservations_status_start_date 
ON reservations(status, start_date);

CREATE INDEX IF NOT EXISTS idx_reservations_status_updated_at 
ON reservations(status, updated_at);

COMMENT ON FUNCTION get_pipeline_data IS 'Zwraca dane dla widoku pipeline z rezerwacjami';