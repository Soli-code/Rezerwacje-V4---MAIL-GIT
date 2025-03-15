/*
  # Update customers table policies

  1. Changes
    - Enable RLS on customers table
    - Create public access policies for customers table

  2. Security
    - Enable RLS
    - Add policies for:
      - Public creation of customer records
      - Public viewing of customer data
      - Public updating of customer data
*/

-- Enable RLS
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "Public can create customers" ON customers;
DROP POLICY IF EXISTS "Public can view customers" ON customers;
DROP POLICY IF EXISTS "Public can update customers" ON customers;

-- Create new public policies for customers table
CREATE POLICY "Public can create customers"
ON customers FOR INSERT
TO public
WITH CHECK (true);

CREATE POLICY "Public can view customers"
ON customers FOR SELECT
TO public
USING (true);

CREATE POLICY "Public can update customers"
ON customers FOR UPDATE
TO public
USING (true)
WITH CHECK (true);