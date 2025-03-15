/*
  # Update customers table timezone to Poland time

  1. Changes
    - Convert existing timestamp columns to Europe/Warsaw timezone
    - Add one hour to align with Poland's timezone
    - Add trigger to automatically handle timezone conversion for new entries
    
  2. Affected Columns
    - rental_start_date
    - rental_end_date
    - created_at
    - updated_at

  Note: This migration ensures all timestamps are stored and displayed in Poland's timezone with +1 hour adjustment
*/

-- Function to convert UTC to Warsaw time with +1 hour adjustment
CREATE OR REPLACE FUNCTION convert_to_warsaw_timezone(utc_time timestamptz) 
RETURNS timestamptz AS $$
BEGIN
  -- Convert to Warsaw time and add 1 hour
  RETURN (utc_time AT TIME ZONE 'Europe/Warsaw' + interval '1 hour') AT TIME ZONE 'Europe/Warsaw';
END;
$$ LANGUAGE plpgsql;

-- Update existing records to Warsaw timezone with +1 hour
DO $$ 
BEGIN
  -- Update rental dates and timestamps
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

-- Create or replace trigger function to handle timezone conversion for new entries
CREATE OR REPLACE FUNCTION handle_customer_timezone()
RETURNS TRIGGER AS $$
BEGIN
  -- Apply timezone conversion to new entries
  IF NEW.rental_start_date IS NOT NULL THEN
    NEW.rental_start_date = convert_to_warsaw_timezone(NEW.rental_start_date);
  END IF;
  
  IF NEW.rental_end_date IS NOT NULL THEN
    NEW.rental_end_date = convert_to_warsaw_timezone(NEW.rental_end_date);
  END IF;
  
  IF NEW.created_at IS NOT NULL THEN
    NEW.created_at = convert_to_warsaw_timezone(NEW.created_at);
  END IF;
  
  IF NEW.updated_at IS NOT NULL THEN
    NEW.updated_at = convert_to_warsaw_timezone(NEW.updated_at);
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate trigger for new entries
DROP TRIGGER IF EXISTS customer_timezone_trigger ON customers;
CREATE TRIGGER customer_timezone_trigger
  BEFORE INSERT OR UPDATE ON customers
  FOR EACH ROW
  EXECUTE FUNCTION handle_customer_timezone();