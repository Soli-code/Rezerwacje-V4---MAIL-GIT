/*
  # Setup rental system schema
  
  1. New Tables
    - reservations
      - id (uuid, primary key)
      - customer_id (uuid, references customers)
      - start_date (timestamptz)
      - end_date (timestamptz)
      - start_time (text)
      - end_time (text)
      - total_price (numeric)
      - status (text)
      - comment (text)
      - created_at (timestamptz)
      
    - reservation_items
      - id (uuid, primary key)
      - reservation_id (uuid, references reservations)
      - equipment_id (integer)
      - quantity (integer)
      - price_per_day (numeric)
      - deposit (numeric)
      
  2. Security
    - Enable RLS on all tables
    - Add policies for public access
*/

-- Create reservations table
CREATE TABLE IF NOT EXISTS reservations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid REFERENCES customers(id),
  start_date timestamptz NOT NULL,
  end_date timestamptz NOT NULL,
  start_time text NOT NULL,
  end_time text NOT NULL,
  total_price numeric NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  comment text,
  created_at timestamptz DEFAULT now(),
  CONSTRAINT valid_dates CHECK (end_date >= start_date)
);

-- Create reservation items table
CREATE TABLE IF NOT EXISTS reservation_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reservation_id uuid REFERENCES reservations(id) ON DELETE CASCADE,
  equipment_id integer NOT NULL,
  quantity integer NOT NULL CHECK (quantity > 0),
  price_per_day numeric NOT NULL,
  deposit numeric NOT NULL DEFAULT 0
);

-- Enable RLS
ALTER TABLE reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE reservation_items ENABLE ROW LEVEL SECURITY;

-- Create policies for reservations
CREATE POLICY "Public can create reservations"
ON reservations FOR INSERT
TO public
WITH CHECK (true);

CREATE POLICY "Public can view reservations"
ON reservations FOR SELECT
TO public
USING (true);

-- Create policies for reservation items
CREATE POLICY "Public can create reservation items"
ON reservation_items FOR INSERT
TO public
WITH CHECK (true);

CREATE POLICY "Public can view reservation items"
ON reservation_items FOR SELECT
TO public
USING (true);