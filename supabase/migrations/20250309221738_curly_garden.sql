/*
  # Add promotional price feature

  This migration adds support for promotional pricing when renting equipment for 7 or more days.

  1. Changes
    - Add promotional_price column to equipment table (if not exists)
    - Add validation function and trigger for promotional price
    - Add constraint to ensure promotional price is lower than regular price

  2. Validation Rules
    - Promotional price must be lower than regular price
    - Promotional price cannot be negative
    - Promotional price is optional (can be NULL)

  3. Technical Details
    - Uses DO blocks to safely check for existing objects
    - Includes proper error handling
    - Maintains data integrity
*/

DO $$ 
BEGIN
  -- Add promotional_price column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_name = 'equipment' 
    AND column_name = 'promotional_price'
  ) THEN
    ALTER TABLE equipment 
    ADD COLUMN promotional_price numeric DEFAULT NULL;
  END IF;
END $$;

-- Create or replace validation function
CREATE OR REPLACE FUNCTION validate_promotional_price()
RETURNS trigger AS $$
BEGIN
  IF NEW.promotional_price IS NOT NULL THEN
    IF NEW.promotional_price >= NEW.price THEN
      RAISE EXCEPTION 'Promotional price must be lower than regular price';
    END IF;
    IF NEW.promotional_price < 0 THEN
      RAISE EXCEPTION 'Promotional price cannot be negative';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if exists and create new one
DO $$ 
BEGIN
  IF EXISTS (
    SELECT 1 
    FROM pg_trigger 
    WHERE tgname = 'validate_promotional_price_trigger'
  ) THEN
    DROP TRIGGER validate_promotional_price_trigger ON equipment;
  END IF;
END $$;

CREATE TRIGGER validate_promotional_price_trigger
BEFORE INSERT OR UPDATE ON equipment
FOR EACH ROW
EXECUTE FUNCTION validate_promotional_price();

-- Drop existing constraint if exists and create new one
DO $$ 
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'promotional_price_check'
  ) THEN
    ALTER TABLE equipment DROP CONSTRAINT promotional_price_check;
  END IF;
END $$;

ALTER TABLE equipment
ADD CONSTRAINT promotional_price_check 
CHECK ((promotional_price IS NULL) OR (promotional_price >= 0 AND promotional_price < price));