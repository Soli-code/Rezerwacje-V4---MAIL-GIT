/*
  # Add promotional price validation function

  1. Changes
    - Add function to validate promotional price
    - Add trigger to validate promotional price on insert/update
    - Skip constraint as it already exists

  2. Validation Rules
    - Promotional price must be lower than regular price
    - Promotional price can be null (no promotion)
    - Promotional price must be >= 0 when set
*/

-- Create function to validate promotional price
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

-- Create trigger to validate promotional price on insert/update
CREATE TRIGGER validate_promotional_price_trigger
BEFORE INSERT OR UPDATE ON equipment
FOR EACH ROW
EXECUTE FUNCTION validate_promotional_price();