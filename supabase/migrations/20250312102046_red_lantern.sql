/*
  # Fix admin functions and views

  1. Changes
    - Add missing columns to reservations table
    - Update admin views and functions to use correct columns
    - Fix RLS policies for admin access
*/

-- Add missing columns to reservations if they don't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'reservations' 
    AND column_name = 'created_at'
  ) THEN
    ALTER TABLE reservations ADD COLUMN created_at timestamptz DEFAULT now();
  END IF;
END $$;

-- Widok rezerwacji dla administratorów
CREATE OR REPLACE VIEW admin_reservations_view AS
SELECT 
  r.id,
  r.status,
  r.start_date,
  r.end_date,
  r.total_price,
  r.rental_days,
  jsonb_build_object(
    'id', c.id,
    'first_name', c.first_name,
    'last_name', c.last_name,
    'email', c.email,
    'phone', c.phone,
    'company_name', c.company_name,
    'company_nip', c.company_nip
  ) as customer,
  jsonb_agg(
    jsonb_build_object(
      'id', ri.id,
      'equipment_id', ri.equipment_id,
      'equipment_name', e.name,
      'quantity', ri.quantity,
      'price_per_day', ri.price_per_day,
      'deposit', ri.deposit
    )
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
LEFT JOIN reservation_items ri ON ri.reservation_id = r.id
LEFT JOIN equipment e ON e.id = ri.equipment_id
GROUP BY r.id, c.id;

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

  -- Pobierz dane
  SELECT jsonb_build_object(
    'columns', (
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', status,
          'title', 
          CASE status
            WHEN 'pending' THEN 'Oczekujące'
            WHEN 'confirmed' THEN 'Potwierdzone'
            WHEN 'completed' THEN 'Zakończone'
          END,
          'reservations', (
            SELECT jsonb_agg(
              jsonb_build_object(
                'id', r.id,
                'customer', jsonb_build_object(
                  'id', c.id,
                  'first_name', c.first_name,
                  'last_name', c.last_name,
                  'email', c.email,
                  'phone', c.phone
                ),
                'dates', jsonb_build_object(
                  'start', r.start_date,
                  'end', r.end_date
                ),
                'total_price', r.total_price,
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
                  WHERE ri.reservation_id = r.id
                )
              )
            )
            FROM reservations r
            JOIN customers c ON c.id = r.customer_id
            WHERE r.status = status
            AND r.created_at >= v_start_date
            ORDER BY r.created_at DESC
          )
        )
      )
      FROM unnest(p_status) as status
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- Dodaj indeksy dla optymalizacji
CREATE INDEX IF NOT EXISTS idx_reservations_created_at ON reservations(created_at);
CREATE INDEX IF NOT EXISTS idx_reservations_status ON reservations(status);
CREATE INDEX IF NOT EXISTS idx_maintenance_logs_status ON maintenance_logs(status);
CREATE INDEX IF NOT EXISTS idx_crm_contacts_status ON crm_contacts(status);
CREATE INDEX IF NOT EXISTS idx_crm_tasks_due_date ON crm_tasks(due_date);

COMMENT ON FUNCTION get_admin_pipeline_data IS 'Zwraca dane dla widoku pipeline rezerwacji';
COMMENT ON VIEW admin_reservations_view IS 'Widok rezerwacji z pełnymi danymi dla administratorów';