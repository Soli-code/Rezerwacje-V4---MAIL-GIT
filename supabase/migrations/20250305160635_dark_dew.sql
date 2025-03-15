/*
  # Complete schema backup - DZIALA JAK NALEZY

  1. Tables
    - profiles
    - rental_orders
    - customers
    - reservations
    - reservation_items

  2. Security
    - RLS policies for all tables
    - Foreign key constraints
    - Check constraints

  3. Indexes
    - Performance optimized indexes for common queries
*/

-- Create tables
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  is_admin boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.customers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  first_name text NOT NULL,
  last_name text NOT NULL,
  email text UNIQUE NOT NULL,
  phone text NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  user_id uuid REFERENCES auth.users(id),
  anonymous_id uuid DEFAULT gen_random_uuid(),
  product_name text,
  rental_start_date timestamptz,
  rental_end_date timestamptz,
  rental_days integer,
  total_amount numeric,
  deposit_amount numeric,
  comment text
);

CREATE TABLE IF NOT EXISTS public.reservations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid REFERENCES public.customers(id) ON DELETE CASCADE,
  start_date timestamptz NOT NULL,
  end_date timestamptz NOT NULL,
  start_time text NOT NULL,
  end_time text NOT NULL,
  total_price numeric NOT NULL,
  status text DEFAULT 'pending' NOT NULL,
  comment text,
  created_at timestamptz DEFAULT now(),
  CONSTRAINT valid_dates CHECK (end_date >= start_date)
);

CREATE TABLE IF NOT EXISTS public.reservation_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reservation_id uuid REFERENCES public.reservations(id) ON DELETE CASCADE,
  equipment_id integer NOT NULL,
  quantity integer NOT NULL,
  price_per_day numeric NOT NULL,
  deposit numeric DEFAULT 0 NOT NULL,
  CONSTRAINT reservation_items_quantity_check CHECK (quantity > 0)
);

CREATE TABLE IF NOT EXISTS public.rental_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid NOT NULL REFERENCES public.customers(id),
  equipment_id integer NOT NULL,
  start_date timestamptz NOT NULL,
  end_date timestamptz NOT NULL,
  total_price numeric NOT NULL,
  comment text,
  status text DEFAULT 'pending' NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT valid_dates CHECK (end_date > start_date),
  CONSTRAINT valid_status CHECK (status = ANY (ARRAY['pending', 'confirmed', 'cancelled', 'completed']))
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_rental_orders_customer_id ON public.rental_orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_rental_orders_equipment_id ON public.rental_orders(equipment_id);
CREATE INDEX IF NOT EXISTS idx_rental_orders_dates ON public.rental_orders(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_rental_orders_status ON public.rental_orders(status);
CREATE INDEX IF NOT EXISTS idx_customers_rental_dates ON public.customers(rental_start_date, rental_end_date);

-- Enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reservation_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rental_orders ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "Anyone can view profiles" ON public.profiles;
  DROP POLICY IF EXISTS "Users can create rental orders" ON public.rental_orders;
  DROP POLICY IF EXISTS "Users can update own rental orders" ON public.rental_orders;
  DROP POLICY IF EXISTS "Users can view own rental orders" ON public.rental_orders;
  DROP POLICY IF EXISTS "Public can create customers" ON public.customers;
  DROP POLICY IF EXISTS "Public can update customers" ON public.customers;
  DROP POLICY IF EXISTS "Public can view customers" ON public.customers;
  DROP POLICY IF EXISTS "Public can create reservations" ON public.reservations;
  DROP POLICY IF EXISTS "Public can view reservations" ON public.reservations;
  DROP POLICY IF EXISTS "Public can create reservation items" ON public.reservation_items;
  DROP POLICY IF EXISTS "Public can view reservation items" ON public.reservation_items;
END $$;

-- Create policies
CREATE POLICY "Anyone can view profiles" ON public.profiles
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Users can create rental orders" ON public.rental_orders
  FOR INSERT TO authenticated
  WITH CHECK (true);

CREATE POLICY "Users can update own rental orders" ON public.rental_orders
  FOR UPDATE TO authenticated
  USING (customer_id IN (SELECT id FROM customers WHERE id = rental_orders.customer_id))
  WITH CHECK (status = ANY (ARRAY['pending', 'cancelled']));

CREATE POLICY "Users can view own rental orders" ON public.rental_orders
  FOR SELECT TO authenticated
  USING (customer_id IN (SELECT id FROM customers WHERE id = rental_orders.customer_id));

CREATE POLICY "Public can create customers" ON public.customers
  FOR INSERT TO public
  WITH CHECK (true);

CREATE POLICY "Public can update customers" ON public.customers
  FOR UPDATE TO public
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Public can view customers" ON public.customers
  FOR SELECT TO public
  USING (true);

CREATE POLICY "Public can create reservations" ON public.reservations
  FOR INSERT TO public
  WITH CHECK (true);

CREATE POLICY "Public can view reservations" ON public.reservations
  FOR SELECT TO public
  USING (true);

CREATE POLICY "Public can create reservation items" ON public.reservation_items
  FOR INSERT TO public
  WITH CHECK (true);

CREATE POLICY "Public can view reservation items" ON public.reservation_items
  FOR SELECT TO public
  USING (true);