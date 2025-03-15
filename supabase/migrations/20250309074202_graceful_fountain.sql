/*
  # Add equipment physical specifications

  1. Changes
    - Add new columns to equipment table:
      - dimensions (TEXT): Product dimensions in format "SxWxG mm"
      - weight (DECIMAL): Product weight in kilograms
      - power_supply (TEXT): Power supply specifications
    
  2. Notes
    - All columns are nullable to maintain compatibility with existing records
    - Added comments to explain the expected format and units for each column
*/

-- Add new columns if they don't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'equipment' AND column_name = 'dimensions'
  ) THEN
    ALTER TABLE equipment ADD COLUMN dimensions TEXT;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'equipment' AND column_name = 'weight'
  ) THEN
    ALTER TABLE equipment ADD COLUMN weight DECIMAL;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'equipment' AND column_name = 'power_supply'
  ) THEN
    ALTER TABLE equipment ADD COLUMN power_supply TEXT;
  END IF;
END $$;

-- Add column comments
COMMENT ON COLUMN equipment.dimensions IS 'Product dimensions in format "SxWxG mm" (e.g., "300x400x500 mm")';
COMMENT ON COLUMN equipment.weight IS 'Product weight in kilograms (kg)';
COMMENT ON COLUMN equipment.power_supply IS 'Power supply specifications (e.g., "230V/50Hz", "24V DC")';