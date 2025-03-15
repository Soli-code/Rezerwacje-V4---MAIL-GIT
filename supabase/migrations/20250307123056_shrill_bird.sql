/*
  # Update customers table timezone

  1. Changes
    - Convert existing timestamp columns to Europe/Warsaw timezone
    - Add trigger to automatically handle timezone conversion for new entries
    
  2. Affected Columns
    - rental_start_date
    - rental_end_date
    - created_at
    - updated_at

  Note: This migration ensures all timestamps are stored and displayed in Poland's timezone
*/

-- Function to convert UTC to Warsaw time
CREATE OR REPLACE FUNCTION convert_to_warsaw_timezone(utc_time timestamptz) 
RETURNS timestamptz AS $$
BEGIN
  RETURN utc_time AT TIME ZONE 'Europe/Warsaw';
END;
$$ LANGUAGE plpgsql;

-- Update existing records to Warsaw timezone
DO $$ 
BEGIN
  -- Update rental dates
  UPDATE customers 
  SET 
    rental_start_date = convert_to_warsaw_timezone(rental_start_date),
    rental_end_date = convert_to_warsaw_timezone(rental_end_date),
    created_at = convert_to_warsaw_timezone(created_at),
    updated_at = convert_to_warsaw_timezone(updated_at)
  WHERE 
    rental_start_date IS NOT NULL 
    OR rental_end_date IS NOT NULL
    OR created_at IS NOT NULL
    OR updated_at IS NOT NULL;
END $$;

-- Create trigger function to handle timezone conversion for new entries
CREATE OR REPLACE FUNCTION handle_customer_timezone()
RETURNS TRIGGER AS $$
BEGIN
  NEW.rental_start_date = convert_to_warsaw_timezone(NEW.rental_start_date);
  NEW.rental_end_date = convert_to_warsaw_timezone(NEW.rental_end_date);
  NEW.created_at = convert_to_warsaw_timezone(NEW.created_at);
  NEW.updated_at = convert_to_warsaw_timezone(NEW.updated_at);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for new entries
DROP TRIGGER IF EXISTS customer_timezone_trigger ON customers;
CREATE TRIGGER customer_timezone_trigger
  BEFORE INSERT OR UPDATE ON customers
  FOR EACH ROW
  EXECUTE FUNCTION handle_customer_timezone();