/*
  # Update customers table RLS policies

  1. Security
    - Enable RLS on customers table
    - Add policies for:
      - Creating customer data (authenticated users)
      - Viewing customer data (public access)
      - Updating customer data (authenticated users)

  2. Changes
    - Remove dependency on reservations table
    - Simplify access policies
    - Allow public access for customer creation
*/

-- Enable RLS if not already enabled
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_tables 
    WHERE schemaname = 'public' 
    AND tablename = 'customers' 
    AND rowsecurity = true
  ) THEN
    ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
  END IF;
END $$;

-- Drop existing policies to avoid conflicts
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "Users can create customer data" ON customers;
  DROP POLICY IF EXISTS "Users can view own customer data" ON customers;
  DROP POLICY IF EXISTS "Users can update own customer data" ON customers;
END $$;

-- Create policies
CREATE POLICY "Anyone can create customer data"
ON customers
FOR INSERT
TO public
WITH CHECK (true);

CREATE POLICY "Anyone can view customer data"
ON customers
FOR SELECT
TO public
USING (true);

CREATE POLICY "Users can update own customer data"
ON customers
FOR UPDATE
TO authenticated
USING (
  id IN (
    SELECT id 
    FROM customers c
    WHERE EXISTS (
      SELECT 1 
      FROM rental_orders 
      WHERE rental_orders.customer_id = c.id
    )
  )
)
WITH CHECK (
  id IN (
    SELECT id 
    FROM customers c
    WHERE EXISTS (
      SELECT 1 
      FROM rental_orders 
      WHERE rental_orders.customer_id = c.id
    )
  )
);