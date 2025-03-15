/*
  # Add availability check functions
  
  1. New Functions
    - check_equipment_availability: Sprawdza dostępność pojedynczego sprzętu
    - check_equipment_availability_batch: Sprawdza dostępność wielu sprzętów jednocześnie
    - get_next_available_date: Znajduje następną dostępną datę dla sprzętu
*/

-- Funkcja sprawdzająca dostępność pojedynczego sprzętu
CREATE OR REPLACE FUNCTION check_equipment_availability(
  p_equipment_id uuid,
  p_start_date timestamptz,
  p_end_date timestamptz
) RETURNS boolean AS $$
BEGIN
  RETURN NOT EXISTS (
    SELECT 1 FROM equipment_availability
    WHERE equipment_id = p_equipment_id
    AND tstzrange(start_date, end_date, '[]') && tstzrange(p_start_date, p_end_date, '[]')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Funkcja sprawdzająca dostępność wielu sprzętów
CREATE OR REPLACE FUNCTION check_equipment_availability_batch(
  p_equipment_ids uuid[],
  p_start_date timestamptz,
  p_end_date timestamptz
) RETURNS TABLE (equipment_id uuid, is_available boolean) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    e.id as equipment_id,
    NOT EXISTS (
      SELECT 1 FROM equipment_availability ea
      WHERE ea.equipment_id = e.id
      AND tstzrange(ea.start_date, ea.end_date, '[]') && tstzrange(p_start_date, p_end_date, '[]')
    ) as is_available
  FROM unnest(p_equipment_ids) AS e(id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Funkcja znajdująca następną dostępną datę
CREATE OR REPLACE FUNCTION get_next_available_date(
  p_equipment_id uuid,
  p_start_date timestamptz
) RETURNS timestamptz AS $$
DECLARE
  next_date timestamptz;
BEGIN
  SELECT MIN(end_date) INTO next_date
  FROM equipment_availability
  WHERE equipment_id = p_equipment_id
  AND start_date >= p_start_date;

  RETURN COALESCE(next_date, p_start_date);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;