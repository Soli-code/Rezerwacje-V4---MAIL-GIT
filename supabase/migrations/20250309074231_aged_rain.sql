/*
  # Merge equipment specifications into description

  1. Changes
    - Merge technical specifications (dimensions, weight, power_supply) into the description field
    - Back up the data in equipment_history
    - Remove the original columns
    - Create a revert function
    
  2. Notes
    - All operations are safe and check for column existence
    - Data is backed up before removal
    - Revert function provided for rollback capability
*/

-- First check if the columns exist and update description if they do
DO $$ 
BEGIN
  IF EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_name = 'equipment' 
    AND column_name IN ('dimensions', 'weight', 'power_supply')
  ) THEN
    -- Update the description field to include the technical specifications
    UPDATE equipment
    SET description = CASE
      WHEN dimensions IS NOT NULL OR weight IS NOT NULL OR power_supply IS NOT NULL
      THEN description || E'\n\n' ||
           CASE WHEN dimensions IS NOT NULL AND dimensions != 'Brak danych' 
                THEN E'Wymiary: ' || dimensions || E'\n'
                ELSE '' END ||
           CASE WHEN weight IS NOT NULL AND weight::text != 'Brak danych'
                THEN E'Waga: ' || weight::text || ' kg\n'
                ELSE '' END ||
           CASE WHEN power_supply IS NOT NULL AND power_supply != 'Brak danych'
                THEN E'Zasilanie: ' || power_supply
                ELSE '' END
      ELSE description
    END
    WHERE dimensions IS NOT NULL 
       OR weight IS NOT NULL 
       OR power_supply IS NOT NULL;

    -- Create backup of the columns in equipment_history
    INSERT INTO equipment_history (equipment_id, changed_at, changes)
    SELECT 
      id,
      NOW(),
      jsonb_build_object(
        'dimensions', dimensions,
        'weight', weight,
        'power_supply', power_supply
      )
    FROM equipment
    WHERE dimensions IS NOT NULL 
       OR weight IS NOT NULL 
       OR power_supply IS NOT NULL;

    -- Remove the columns
    ALTER TABLE equipment
      DROP COLUMN IF EXISTS dimensions,
      DROP COLUMN IF EXISTS weight,
      DROP COLUMN IF EXISTS power_supply;
  END IF;
END $$;

-- Create revert function in case we need to undo these changes
CREATE OR REPLACE FUNCTION revert_equipment_description_merge()
RETURNS void AS $$
BEGIN
  -- First add back the columns if they don't exist
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'equipment' AND column_name = 'dimensions') THEN
    ALTER TABLE equipment ADD COLUMN dimensions text;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'equipment' AND column_name = 'weight') THEN
    ALTER TABLE equipment ADD COLUMN weight numeric;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'equipment' AND column_name = 'power_supply') THEN
    ALTER TABLE equipment ADD COLUMN power_supply text;
  END IF;

  -- Restore the data from equipment_history
  UPDATE equipment e
  SET 
    dimensions = (h.changes->>'dimensions')::text,
    weight = (h.changes->>'weight')::numeric,
    power_supply = (h.changes->>'power_supply')::text
  FROM equipment_history h
  WHERE e.id = h.equipment_id
    AND h.changes ? 'dimensions';

  -- Remove the merged technical specs from description
  UPDATE equipment
  SET description = regexp_replace(
    description,
    E'\n\n(Wymiary: .*\n)?(Waga: .*\n)?(Zasilanie: .*)?$',
    '',
    'g'
  )
  WHERE description ~ E'\n\n(Wymiary|Waga|Zasilanie):';
END;
$$ LANGUAGE plpgsql;