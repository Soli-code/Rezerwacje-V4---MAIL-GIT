/*
  # Funkcje panelu administracyjnego

  1. Nowe funkcje
    - get_admin_dashboard_stats - statystyki dla dashboardu
    - get_admin_pipeline_data - dane dla widoku pipeline
    - get_admin_crm_stats - statystyki CRM
    
  2. Bezpieczeństwo
    - Wszystkie funkcje jako SECURITY DEFINER
    - Sprawdzanie uprawnień administratora
*/

-- Funkcja zwracająca statystyki dla dashboardu
CREATE OR REPLACE FUNCTION get_admin_dashboard_stats(
  p_date_range text DEFAULT '30days'
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

  WITH stats AS (
    -- Statystyki rezerwacji
    SELECT
      COUNT(*) FILTER (WHERE r.status = 'confirmed') as active_reservations,
      COUNT(*) FILTER (WHERE r.status = 'pending') as pending_reservations,
      COUNT(DISTINCT r.customer_id) as total_customers,
      COUNT(DISTINCT CASE 
        WHEN c.reservation_count > 1 THEN r.customer_id 
      END) as returning_customers,
      COALESCE(AVG(r.rental_days), 0) as avg_rental_days,
      COALESCE(SUM(r.total_price), 0) as total_revenue
    FROM reservations r
    LEFT JOIN (
      SELECT customer_id, COUNT(*) as reservation_count
      FROM reservations
      WHERE status != 'cancelled'
      GROUP BY customer_id
    ) c ON c.customer_id = r.customer_id
    WHERE r.status != 'cancelled'
  ),
  equipment_stats AS (
    -- Statystyki sprzętu
    SELECT
      COUNT(*) as total_equipment,
      COUNT(*) FILTER (WHERE quantity = 0) as out_of_stock,
      COUNT(*) FILTER (WHERE quantity < 2) as low_stock
    FROM equipment
  ),
  maintenance_stats AS (
    -- Statystyki konserwacji
    SELECT
      COUNT(*) FILTER (WHERE status = 'planned') as planned_maintenance,
      COUNT(*) FILTER (WHERE status = 'in_progress') as ongoing_maintenance
    FROM maintenance_logs
  ),
  popular_equipment AS (
    -- Najpopularniejszy sprzęt
    SELECT 
      e.id,
      e.name,
      COUNT(*) as rental_count
    FROM reservation_items ri
    JOIN equipment e ON e.id = ri.equipment_id
    JOIN reservations r ON r.id = ri.reservation_id
    WHERE r.status != 'cancelled'
    GROUP BY e.id, e.name
    ORDER BY rental_count DESC
    LIMIT 5
  )
  SELECT jsonb_build_object(
    'reservations', jsonb_build_object(
      'active', (SELECT active_reservations FROM stats),
      'pending', (SELECT pending_reservations FROM stats),
      'total_customers', (SELECT total_customers FROM stats),
      'returning_customers', (SELECT returning_customers FROM stats),
      'avg_rental_days', (SELECT avg_rental_days FROM stats),
      'total_revenue', (SELECT total_revenue FROM stats)
    ),
    'equipment', jsonb_build_object(
      'total', (SELECT total_equipment FROM equipment_stats),
      'out_of_stock', (SELECT out_of_stock FROM equipment_stats),
      'low_stock', (SELECT low_stock FROM equipment_stats)
    ),
    'maintenance', jsonb_build_object(
      'planned', (SELECT planned_maintenance FROM maintenance_stats),
      'ongoing', (SELECT ongoing_maintenance FROM maintenance_stats)
    ),
    'popular_equipment', (
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', id,
          'name', name,
          'count', rental_count
        )
      )
      FROM popular_equipment
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

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
            AND r.status != 'cancelled'
            ORDER BY r.start_date ASC
          )
        )
      )
      FROM unnest(p_status) as status
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- Funkcja do pobierania statystyk CRM
CREATE OR REPLACE FUNCTION get_admin_crm_stats()
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

  WITH stats AS (
    SELECT
      COUNT(*) FILTER (WHERE status = 'lead') as total_leads,
      COUNT(*) FILTER (WHERE status = 'customer') as total_customers,
      COUNT(*) FILTER (WHERE status = 'inactive') as total_inactive,
      COALESCE(AVG(lead_score), 0) as avg_lead_score,
      COUNT(DISTINCT CASE 
        WHEN last_contact_date >= now() - interval '30 days' 
        THEN id 
      END) as active_last_30_days
    FROM crm_contacts
  ),
  task_stats AS (
    SELECT
      COUNT(*) FILTER (WHERE due_date::date = CURRENT_DATE) as tasks_today,
      COUNT(*) FILTER (WHERE status = 'pending') as pending_tasks,
      COUNT(*) FILTER (WHERE status = 'completed') as completed_tasks
    FROM crm_tasks
  )
  SELECT jsonb_build_object(
    'contacts', jsonb_build_object(
      'leads', (SELECT total_leads FROM stats),
      'customers', (SELECT total_customers FROM stats),
      'inactive', (SELECT total_inactive FROM stats),
      'avg_lead_score', (SELECT avg_lead_score FROM stats),
      'active_last_30_days', (SELECT active_last_30_days FROM stats)
    ),
    'tasks', jsonb_build_object(
      'today', (SELECT tasks_today FROM task_stats),
      'pending', (SELECT pending_tasks FROM task_stats),
      'completed', (SELECT completed_tasks FROM task_stats)
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- Dodaj indeksy dla optymalizacji
CREATE INDEX IF NOT EXISTS idx_reservations_status ON reservations(status);
CREATE INDEX IF NOT EXISTS idx_maintenance_logs_status ON maintenance_logs(status);
CREATE INDEX IF NOT EXISTS idx_crm_contacts_status ON crm_contacts(status);
CREATE INDEX IF NOT EXISTS idx_crm_tasks_due_date ON crm_tasks(due_date);

COMMENT ON FUNCTION get_admin_dashboard_stats IS 'Zwraca statystyki dla dashboardu administratora';
COMMENT ON FUNCTION get_admin_pipeline_data IS 'Zwraca dane dla widoku pipeline rezerwacji';
COMMENT ON FUNCTION get_admin_crm_stats IS 'Zwraca statystyki CRM';
COMMENT ON VIEW admin_reservations_view IS 'Widok rezerwacji z pełnymi danymi dla administratorów';