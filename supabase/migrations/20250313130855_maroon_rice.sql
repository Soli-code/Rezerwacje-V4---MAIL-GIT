/*
  # Add customer blocking functionality

  1. Changes
    - Add status column to customers table
    - Add blocked_at and blocked_by columns
    - Add block_reason column
    - Add indexes for performance
    - Add functions and triggers for blocking
*/

-- Add new columns to customers table
ALTER TABLE customers
ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
ADD COLUMN IF NOT EXISTS blocked_at timestamptz,
ADD COLUMN IF NOT EXISTS blocked_by uuid REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS block_reason text;

-- Add index for status column
CREATE INDEX IF NOT EXISTS idx_customers_status ON customers(status);

-- Create customer blocking history table
CREATE TABLE IF NOT EXISTS customer_blocking_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid REFERENCES customers(id) ON DELETE CASCADE,
  action text NOT NULL CHECK (action IN ('block', 'unblock')),
  reason text,
  performed_by uuid REFERENCES auth.users(id),
  performed_at timestamptz DEFAULT now()
);

-- Enable RLS on history table
ALTER TABLE customer_blocking_history ENABLE ROW LEVEL SECURITY;

-- Add policy for admin access to history
CREATE POLICY "Admins can view blocking history"
  ON customer_blocking_history
  FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  ));

-- Function to block customer
CREATE OR REPLACE FUNCTION block_customer(
  p_customer_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  -- Get current user ID
  v_user_id := auth.uid();
  
  -- Check if user is admin
  IF NOT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = v_user_id
    AND is_admin = true
  ) THEN
    RAISE EXCEPTION 'Brak uprawnień do blokowania klientów';
  END IF;

  -- Update customer status
  UPDATE customers
  SET 
    status = 'inactive',
    blocked_at = now(),
    blocked_by = v_user_id,
    block_reason = p_reason
  WHERE id = p_customer_id;

  -- Add history entry
  INSERT INTO customer_blocking_history (
    customer_id,
    action,
    reason,
    performed_by
  ) VALUES (
    p_customer_id,
    'block',
    p_reason,
    v_user_id
  );
END;
$$;

-- Function to unblock customer
CREATE OR REPLACE FUNCTION unblock_customer(
  p_customer_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  -- Get current user ID
  v_user_id := auth.uid();
  
  -- Check if user is admin
  IF NOT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = v_user_id
    AND is_admin = true
  ) THEN
    RAISE EXCEPTION 'Brak uprawnień do odblokowywania klientów';
  END IF;

  -- Update customer status
  UPDATE customers
  SET 
    status = 'active',
    blocked_at = NULL,
    blocked_by = NULL,
    block_reason = NULL
  WHERE id = p_customer_id;

  -- Add history entry
  INSERT INTO customer_blocking_history (
    customer_id,
    action,
    performed_by
  ) VALUES (
    p_customer_id,
    'unblock',
    v_user_id
  );
END;
$$;

-- Function to check if customer is blocked before reservation
CREATE OR REPLACE FUNCTION check_customer_status()
RETURNS trigger AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM customers
    WHERE id = NEW.customer_id
    AND status = 'inactive'
  ) THEN
    RAISE EXCEPTION 'Nie można utworzyć rezerwacji dla zablokowanego klienta';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add trigger to check customer status before reservation
DROP TRIGGER IF EXISTS check_customer_status_trigger ON reservations;
CREATE TRIGGER check_customer_status_trigger
  BEFORE INSERT ON reservations
  FOR EACH ROW
  EXECUTE FUNCTION check_customer_status();

-- Add comment
COMMENT ON TABLE customer_blocking_history IS 'Historia blokad i odblokowań klientów';