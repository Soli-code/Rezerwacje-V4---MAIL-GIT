/*
  # Add promotional price column

  1. Changes
    - Add promotional_price column to equipment table
    - Add check constraint to ensure promotional price is lower than regular price
    - Add trigger to validate promotional price on insert/update

  2. Security
    - Maintain existing RLS policies
*/

-- Add promotional_price column
ALTER TABLE equipment 
ADD COLUMN promotional_price numeric;

-- Add check constraint
ALTER TABLE equipment
ADD CONSTRAINT promotional_price_check 
CHECK (promotional_price IS NULL OR (promotional_price >= 0 AND promotional_price < price));

-- Create validation trigger function
CREATE OR REPLACE FUNCTION validate_promotional_price()
RETURNS trigger AS $$
BEGIN
  IF NEW.promotional_price IS NOT NULL AND NEW.promotional_price >= NEW.price THEN
    RAISE EXCEPTION 'Promotional price must be lower than regular price';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
CREATE TRIGGER validate_promotional_price_trigger
BEFORE INSERT OR UPDATE ON equipment
FOR EACH ROW
EXECUTE FUNCTION validate_promotional_price();