/*
  # Fix rental statistics function

  1. Changes
    - Fix alias naming conflict with 'or' keyword
    - Use proper alias names for subqueries
    - Keep all functionality intact
*/

-- Funkcja zwracająca statystyki wypożyczeń
CREATE OR REPLACE FUNCTION get_rental_statistics(p_date_range text)
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
    WHEN '12months' THEN now() - interval '12 months'
    ELSE now() - interval '30 days'
  END;

  WITH rental_stats AS (
    -- Podstawowe statystyki rezerwacji
    SELECT
      COUNT(*) FILTER (WHERE status = 'picked_up') as active_rentals,
      COUNT(*) FILTER (WHERE start_date >= date_trunc('month', now())) as monthly_rentals,
      COALESCE(AVG(rental_days), 0) as avg_duration,
      COALESCE(SUM(total_price), 0) as total_revenue
    FROM reservations
    WHERE created_at >= v_start_date
    AND status != 'cancelled'
  ),
  popular_equipment AS (
    -- Najpopularniejszy sprzęt
    SELECT 
      e.id,
      e.name,
      COUNT(*) as rental_count,
      ROUND(COUNT(*)::numeric / NULLIF((
        SELECT COUNT(*) 
        FROM reservation_items ri2
        JOIN reservations r2 ON r2.id = ri2.reservation_id
        WHERE r2.created_at >= v_start_date
        AND r2.status != 'cancelled'
      ), 0) * 100, 1) as percentage
    FROM reservation_items ri
    JOIN equipment e ON e.id = ri.equipment_id
    JOIN reservations r ON r.id = ri.reservation_id
    WHERE r.created_at >= v_start_date
    AND r.status != 'cancelled'
    GROUP BY e.id, e.name
    ORDER BY rental_count DESC
    LIMIT 5
  ),
  monthly_stats AS (
    -- Statystyki miesięczne
    SELECT
      date_trunc('month', start_date) as month,
      COUNT(*) as rental_count,
      SUM(total_price) as revenue
    FROM reservations
    WHERE created_at >= v_start_date - interval '12 months'
    AND status != 'cancelled'
    GROUP BY month
    ORDER BY month
  ),
  equipment_categories AS (
    -- Podział na kategorie sprzętu
    SELECT
      unnest(e.categories) as category,
      COUNT(*) as rental_count,
      ROUND(COUNT(*)::numeric / NULLIF((
        SELECT COUNT(*) 
        FROM reservation_items ri2
        JOIN reservations r2 ON r2.id = ri2.reservation_id
        WHERE r2.created_at >= v_start_date
        AND r2.status != 'cancelled'
      ), 0) * 100, 1) as percentage
    FROM reservation_items ri
    JOIN equipment e ON e.id = ri.equipment_id
    JOIN reservations r ON r.id = ri.reservation_id
    WHERE r.created_at >= v_start_date
    AND r.status != 'cancelled'
    GROUP BY category
  ),
  overdue_rentals AS (
    -- Przeterminowane wypożyczenia
    SELECT
      r.id,
      c.first_name || ' ' || c.last_name as customer_name,
      c.phone as customer_phone,
      e.name as equipment_name,
      r.end_date as return_date,
      EXTRACT(DAY FROM (now() - r.end_date)) as days_overdue
    FROM reservations r
    JOIN customers c ON c.id = r.customer_id
    JOIN reservation_items ri ON ri.reservation_id = r.id
    JOIN equipment e ON e.id = ri.equipment_id
    WHERE r.status = 'picked_up'
    AND r.end_date < now()
    ORDER BY r.end_date ASC
  ),
  top_customers AS (
    -- Najczęściej wypożyczający klienci
    SELECT
      c.id,
      c.first_name || ' ' || c.last_name as name,
      COUNT(*) as rental_count,
      SUM(r.total_price) as total_value
    FROM reservations r
    JOIN customers c ON c.id = r.customer_id
    WHERE r.created_at >= v_start_date
    AND r.status != 'cancelled'
    GROUP BY c.id, c.first_name, c.last_name
    ORDER BY rental_count DESC
    LIMIT 5
  )
  SELECT jsonb_build_object(
    'activeRentals', (SELECT active_rentals FROM rental_stats),
    'monthlyRentals', (SELECT monthly_rentals FROM rental_stats),
    'avgDuration', (SELECT avg_duration FROM rental_stats),
    'totalRevenue', (SELECT total_revenue FROM rental_stats),
    'popularEquipment', (
      SELECT jsonb_agg(to_jsonb(pe.*))
      FROM popular_equipment pe
    ),
    'monthlyStats', (
      SELECT jsonb_agg(to_jsonb(ms.*))
      FROM monthly_stats ms
    ),
    'equipmentCategories', (
      SELECT jsonb_agg(to_jsonb(ec.*))
      FROM equipment_categories ec
    ),
    'overdueRentals', (
      SELECT jsonb_agg(to_jsonb(overdue.*))
      FROM overdue_rentals overdue
    ),
    'topCustomers', (
      SELECT jsonb_agg(to_jsonb(tc.*))
      FROM top_customers tc
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;