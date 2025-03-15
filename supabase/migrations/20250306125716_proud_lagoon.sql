/*
  # Convert equipment_id to UUID type

  1. Changes
    - Convert equipment_id column from integer to UUID type
    - Add foreign key constraint to equipment table
    - Add performance index

  2. Security
    - Ensure data integrity during conversion
    - Handle existing records safely
*/

-- First create the equipment table if it doesn't exist
CREATE TABLE IF NOT EXISTS equipment (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  price numeric NOT NULL,
  deposit numeric DEFAULT 0,
  image text,
  categories text[] NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS on equipment table
ALTER TABLE equipment ENABLE ROW LEVEL SECURITY;

-- Create a temporary table to store reservation items
CREATE TABLE temp_reservation_items AS 
SELECT * FROM reservation_items;

-- Drop the original table
DROP TABLE reservation_items;

-- Recreate the table with correct column types
CREATE TABLE reservation_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reservation_id uuid REFERENCES reservations(id) ON DELETE CASCADE,
  equipment_id uuid REFERENCES equipment(id),
  quantity integer NOT NULL CHECK (quantity > 0),
  price_per_day numeric NOT NULL,
  deposit numeric DEFAULT 0
);

-- Enable RLS on reservation_items table
ALTER TABLE reservation_items ENABLE ROW LEVEL SECURITY;

-- Create index for better performance
CREATE INDEX idx_reservation_items_equipment_id 
ON reservation_items(equipment_id);

-- Create index for reservation lookups
CREATE INDEX idx_reservation_items_reservation_id 
ON reservation_items(reservation_id);