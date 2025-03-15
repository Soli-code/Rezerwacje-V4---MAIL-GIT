/*
  # Add batch availability check function

  1. New Functions
    - `check_equipment_availability_batch`: Checks availability for multiple equipment items at once
    
  2. Changes
    - Optimizes availability checking by allowing batch processing
    - Returns availability status for multiple items in a single query
*/

CREATE OR REPLACE FUNCTION check_equipment_availability_batch(
  p_equipment_ids uuid[],
  p_start_date timestamptz,
  p_end_date timestamptz
) RETURNS TABLE (
  equipment_id uuid,
  is_available boolean
) LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  SELECT 
    e.id as equipment_id,
    NOT EXISTS (
      SELECT 1 
      FROM equipment_availability ea 
      WHERE ea.equipment_id = e.id
      AND ea.status IN ('reserved', 'maintenance')
      AND tstzrange(ea.start_date, ea.end_date, '[]') && tstzrange(p_start_date, p_end_date, '[]')
    ) as is_available
  FROM unnest(p_equipment_ids) AS eid
  JOIN equipment e ON e.id = eid;
END;
$$;

-- Grant access to authenticated and anon users
GRANT EXECUTE ON FUNCTION check_equipment_availability_batch TO authenticated, anon;