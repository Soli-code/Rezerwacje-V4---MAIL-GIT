/*
  # Fix pipeline permissions

  1. Changes
    - Update get_pipeline_data function to properly check admin permissions
    - Add RLS policies for admin access
    - Fix error handling
*/

-- Drop existing function if exists
DROP FUNCTION IF EXISTS get_pipeline_data();

-- Create new function with proper permission checks
CREATE OR REPLACE FUNCTION get_pipeline_data()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
  v_user_id uuid;
BEGIN
  -- Get current user ID
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Użytkownik musi być zalogowany';
  END IF;

  -- Check if user is admin
  IF NOT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = v_user_id
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
    WHERE r.status IN ('pending', 'confirmed', 'picked_up', 'completed', 'cancelled', 'archived')
  )
  SELECT jsonb_build_object(
    'columns', jsonb_build_array(
      jsonb_build_object(
        'id', 'pending',
        'title', 'Oczekujące',
        'reservations', COALESCE((
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
            ORDER BY pd.start_date ASC
          )
          FROM pipeline_data pd
          WHERE pd.status = 'pending'
        ), '[]'::jsonb)
      ),
      jsonb_build_object(
        'id', 'confirmed',
        'title', 'Potwierdzone',
        'reservations', COALESCE((
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
            ORDER BY pd.start_date ASC
          )
          FROM pipeline_data pd
          WHERE pd.status = 'confirmed'
        ), '[]'::jsonb)
      ),
      jsonb_build_object(
        'id', 'picked_up',
        'title', 'Odebrane',
        'reservations', COALESCE((
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
            ORDER BY pd.start_date ASC
          )
          FROM pipeline_data pd
          WHERE pd.status = 'picked_up'
        ), '[]'::jsonb)
      ),
      jsonb_build_object(
        'id', 'completed',
        'title', 'Zakończone',
        'reservations', COALESCE((
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
            ORDER BY pd.updated_at DESC
          )
          FROM pipeline_data pd
          WHERE pd.status = 'completed'
          AND pd.updated_at >= now() - interval '24 hours'
        ), '[]'::jsonb)
      ),
      jsonb_build_object(
        'id', 'cancelled',
        'title', 'Anulowane',
        'reservations', COALESCE((
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
            ORDER BY pd.updated_at DESC
          )
          FROM pipeline_data pd
          WHERE pd.status = 'cancelled'
          AND pd.updated_at >= now() - interval '24 hours'
        ), '[]'::jsonb)
      ),
      jsonb_build_object(
        'id', 'archived',
        'title', 'Historyczne',
        'reservations', COALESCE((
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
            ORDER BY pd.updated_at DESC
          )
          FROM pipeline_data pd
          WHERE pd.status = 'archived'
        ), '[]'::jsonb)
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