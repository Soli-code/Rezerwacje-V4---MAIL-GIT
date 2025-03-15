/*
  # Fix admin reservations view

  1. Changes
    - Create view for admin reservations with proper joins
    - Add indexes for better performance
    - Add comments for documentation
*/

-- Drop view if exists
DROP VIEW IF EXISTS admin_reservations_view;

-- Create view for admin reservations
CREATE VIEW admin_reservations_view AS
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
  (
    SELECT jsonb_agg(
      jsonb_build_object(
        'id', ri.id,
        'equipment_id', ri.equipment_id,
        'equipment_name', e.name,
        'quantity', ri.quantity,
        'price_per_day', ri.price_per_day,
        'deposit', ri.deposit
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
JOIN customers c ON c.id = r.customer_id;

-- Add comment to view
COMMENT ON VIEW admin_reservations_view IS 'Widok rezerwacji z pełnymi danymi dla administratorów';

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_reservations_customer_id ON reservations(customer_id);
CREATE INDEX IF NOT EXISTS idx_reservation_items_reservation_id ON reservation_items(reservation_id);
CREATE INDEX IF NOT EXISTS idx_reservation_history_reservation_id ON reservation_history(reservation_id);