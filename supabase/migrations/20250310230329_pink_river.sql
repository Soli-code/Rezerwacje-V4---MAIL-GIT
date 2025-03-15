/*
  # Połączenie szczegółów technicznych z opisem sprzętu

  1. Zmiany
    - Dodanie kolumn dla szczegółów technicznych
    - Utworzenie kopii zapasowej danych
    - Połączenie szczegółów technicznych z opisem
    - Dodanie funkcji do przywrócenia zmian

  2. Bezpieczeństwo
    - Tworzenie kopii zapasowej przed modyfikacją
    - Funkcja do przywrócenia zmian w razie potrzeby
*/

-- Najpierw dodaj kolumny, jeśli nie istnieją
ALTER TABLE equipment
ADD COLUMN IF NOT EXISTS dimensions text,
ADD COLUMN IF NOT EXISTS weight numeric,
ADD COLUMN IF NOT EXISTS power_supply text;

-- Utwórz kopię zapasową obecnych danych
INSERT INTO equipment_history (equipment_id, changed_at, changed_by, changes)
SELECT 
  id,
  NOW(),
  NULL,
  jsonb_build_object(
    'description', description,
    'dimensions', dimensions,
    'weight', weight,
    'power_supply', power_supply
  )
FROM equipment;

-- Zaktualizuj pole description dodając szczegóły techniczne
UPDATE equipment
SET description = CASE
  WHEN description IS NULL THEN ''
  ELSE description || E'\n\n'
END || 
TRIM(
  COALESCE(
    CASE 
      WHEN dimensions IS NOT NULL AND dimensions != 'Brak danych' 
      THEN E'Wymiary: ' || dimensions || E'\n'
      ELSE ''
    END ||
    CASE 
      WHEN weight IS NOT NULL AND weight != 0
      THEN E'Waga: ' || weight::text || ' kg\n'
      ELSE ''
    END ||
    CASE 
      WHEN power_supply IS NOT NULL AND power_supply != 'Brak danych'
      THEN E'Zasilanie: ' || power_supply
      ELSE ''
    END,
    ''
  )
);

-- Utwórz funkcję do przywrócenia zmian w razie potrzeby
CREATE OR REPLACE FUNCTION revert_equipment_description_merge()
RETURNS void AS $$
BEGIN
  UPDATE equipment e
  SET 
    description = (eh.changes->>'description')::text,
    dimensions = (eh.changes->>'dimensions')::text,
    weight = (eh.changes->>'weight')::numeric,
    power_supply = (eh.changes->>'power_supply')::text
  FROM equipment_history eh
  WHERE e.id = eh.equipment_id
  AND eh.changed_at = (
    SELECT MAX(changed_at)
    FROM equipment_history
    WHERE equipment_id = e.id
  );
  
  -- Usuń wpisy kopii zapasowej
  DELETE FROM equipment_history
  WHERE changes ? 'dimensions';
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION revert_equipment_description_merge() IS 'Funkcja do przywrócenia stanu sprzed połączenia szczegółów technicznych z opisem';