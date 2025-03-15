/*
  # Add comment field to customers table

  1. Changes
    - Add optional comment field to customers table for storing additional notes from the reservation form

  2. Details
    - New column: comment (text, nullable)
    - No changes to existing data or constraints
*/

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'customers' 
    AND column_name = 'comment'
  ) THEN
    ALTER TABLE customers ADD COLUMN comment text;
  END IF;
END $$;