/*
  # Fix contact info table

  1. Changes
    - Clean up duplicate entries in contact_info table
    - Keep only the most recently updated record
    - Add unique constraint to prevent multiple active records
    
  2. Security
    - Maintain existing RLS policies
*/

-- First, delete all but the most recent contact info record
DELETE FROM contact_info 
WHERE id NOT IN (
  SELECT id 
  FROM contact_info 
  ORDER BY updated_at DESC 
  LIMIT 1
);

-- Add a check constraint to ensure only one active record
CREATE OR REPLACE FUNCTION check_contact_info_count()
RETURNS TRIGGER AS $$
BEGIN
  IF (SELECT COUNT(*) FROM contact_info) > 0 AND TG_OP = 'INSERT' THEN
    -- If inserting and records exist, delete the old record
    DELETE FROM contact_info WHERE id != NEW.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop the trigger if it exists
DROP TRIGGER IF EXISTS ensure_single_contact_info ON contact_info;

-- Create the trigger
CREATE TRIGGER ensure_single_contact_info
  BEFORE INSERT ON contact_info
  FOR EACH ROW
  EXECUTE FUNCTION check_contact_info_count();