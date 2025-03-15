/*
  # Add dashboard stats function
  
  1. New Function
    - get_dashboard_stats: Pobiera wszystkie statystyki dla dashboardu w jednym zapytaniu
    
  2. Optimizations
    - Używa Common Table Expressions (CTE) dla lepszej wydajności
    - Wykonuje wszystkie obliczenia w jednym zapytaniu
*/

CREATE OR REPLACE FUNCTION get_dashboard_stats()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result jsonb;
BEGIN
  WITH stats AS (
    -- Statystyki sprzętu
    SELECT 
      COUNT(DISTINCT e.id) as total_equipment,
      COUNT(DISTINCT CASE WHEN ml.status = 'planned' THEN ml.id END) as maintenance_needed
    FROM equipment e
    LEFT JOIN maintenance_logs ml ON ml.equipment_id = e.id
  ),
  reservation_stats AS (
    -- Statystyki rezerwacji
    SELECT
      COUNT(DISTINCT CASE WHEN r.status = 'confirmed' THEN r.id END) as active_reservations,
      COUNT(DISTINCT CASE WHEN r.status = 'pending' THEN r.id END) as pending_reservations,
      COUNT(DISTINCT r.customer_id) as total_customers,
      COALESCE(SUM(CASE WHEN ft.status = 'completed' THEN ft.amount ELSE 0 END), 0) as total_revenue,
      COALESCE(AVG(CASE WHEN r.status = 'completed' THEN r.rental_days ELSE NULL END), 0) as average_rental
    FROM reservations r
    LEFT JOIN financial_transactions ft ON ft.reservation_id = r.id
  ),
  returning_customers AS (
    -- Liczba powracających klientów
    SELECT COUNT(DISTINCT customer_id) as returning_customers
    FROM (
      SELECT customer_id
      FROM reservations
      WHERE status != 'cancelled'
      GROUP BY customer_id
      HAVING COUNT(*) > 1
    ) rc
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
  SELECT 
    jsonb_build_object(
      'total_equipment', (SELECT total_equipment FROM stats),
      'maintenance_needed', (SELECT maintenance_needed FROM stats),
      'active_reservations', (SELECT active_reservations FROM reservation_stats),
      'pending_reservations', (SELECT pending_reservations FROM reservation_stats),
      'total_customers', (SELECT total_customers FROM reservation_stats),
      'total_revenue', (SELECT total_revenue FROM reservation_stats),
      'average_rental', (SELECT average_rental FROM reservation_stats),
      'returning_customers', (SELECT returning_customers FROM returning_customers),
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
    ) INTO result;

  RETURN result;
END;
$$;