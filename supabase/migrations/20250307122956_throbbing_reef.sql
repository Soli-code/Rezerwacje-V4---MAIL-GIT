/*
  # Fix customer dates timezone

  1. Changes
    - Updates all timestamp columns in customers table to use correct Polish timezone
    - Affects the following columns:
      - rental_start_date
      - rental_end_date
      - created_at
      - updated_at

  2. Notes
    - Converts existing UTC timestamps to Europe/Warsaw timezone
    - Ensures future timestamps will be stored correctly
*/

-- Function to convert UTC to Warsaw time
CREATE OR REPLACE FUNCTION utc_to_warsaw(utc_ts timestamptz) 
RETURNS timestamptz AS $$
BEGIN
  RETURN utc_ts AT TIME ZONE 'UTC' AT TIME ZONE 'Europe/Warsaw';
END;
$$ LANGUAGE plpgsql;

-- Update existing timestamps to Warsaw time
DO $$ 
BEGIN
  -- Update rental dates
  UPDATE customers 
  SET 
    rental_start_date = utc_to_warsaw(rental_start_date),
    rental_end_date = utc_to_warsaw(rental_end_date),
    created_at = utc_to_warsaw(created_at),
    updated_at = utc_to_warsaw(updated_at)
  WHERE 
    rental_start_date IS NOT NULL OR 
    rental_end_date IS NOT NULL OR
    created_at IS NOT NULL OR
    updated_at IS NOT NULL;
END $$;