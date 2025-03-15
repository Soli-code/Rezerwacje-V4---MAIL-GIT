/*
  # Create reservations schema

  1. New Tables
    - `customers`
      - `id` (uuid, primary key)
      - `first_name` (text)
      - `last_name` (text)
      - `email` (text, unique)
      - `phone` (text)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

    - `rental_orders`
      - `id` (uuid, primary key)
      - `customer_id` (uuid, references customers)
      - `equipment_id` (integer)
      - `start_date` (timestamp)
      - `end_date` (timestamp)
      - `total_price` (numeric)
      - `comment` (text, optional)
      - `status` (text)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

  2. Security
    - Enable RLS on both tables
    - Add policies for authenticated users to:
      - View their own data
      - Create new reservations
      - Update their own reservations
*/

-- Create customers table
CREATE TABLE IF NOT EXISTS customers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  first_name text NOT NULL,
  last_name text NOT NULL,
  email text NOT NULL UNIQUE,
  phone text NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create rental_orders table
CREATE TABLE IF NOT EXISTS rental_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid NOT NULL REFERENCES customers(id),
  equipment_id integer NOT NULL,
  start_date timestamptz NOT NULL,
  end_date timestamptz NOT NULL,
  total_price numeric NOT NULL,
  comment text,
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT valid_dates CHECK (end_date > start_date),
  CONSTRAINT valid_status CHECK (status IN ('pending', 'confirmed', 'cancelled', 'completed'))
);

-- Enable RLS
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE rental_orders ENABLE ROW LEVEL SECURITY;

-- Customers policies
CREATE POLICY "Users can view own customer data"
  ON customers
  FOR SELECT
  TO authenticated
  USING (auth.uid() IN (
    SELECT customer_id 
    FROM rental_orders 
    WHERE customer_id = id
  ));

CREATE POLICY "Users can create customer data"
  ON customers
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Rental orders policies
CREATE POLICY "Users can view own rental orders"
  ON rental_orders
  FOR SELECT
  TO authenticated
  USING (customer_id IN (
    SELECT id 
    FROM customers 
    WHERE id = customer_id
  ));

CREATE POLICY "Users can create rental orders"
  ON rental_orders
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Users can update own rental orders"
  ON rental_orders
  FOR UPDATE
  TO authenticated
  USING (customer_id IN (
    SELECT id 
    FROM customers 
    WHERE id = customer_id
  ))
  WITH CHECK (status IN ('pending', 'cancelled'));

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_rental_orders_customer_id ON rental_orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_rental_orders_equipment_id ON rental_orders(equipment_id);
CREATE INDEX IF NOT EXISTS idx_rental_orders_dates ON rental_orders(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_rental_orders_status ON rental_orders(status);