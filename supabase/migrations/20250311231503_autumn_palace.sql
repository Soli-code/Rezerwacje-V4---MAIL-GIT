-- Drop existing policies if they exist
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "Admins can view debug logs" ON debug_logs;
  DROP POLICY IF EXISTS "Public can insert debug logs" ON debug_logs;
  DROP POLICY IF EXISTS "Public can view debug logs" ON debug_logs;
EXCEPTION
  WHEN undefined_object THEN NULL;
END $$;

-- Enable RLS
ALTER TABLE debug_logs ENABLE ROW LEVEL SECURITY;

-- Add policies for debug_logs
CREATE POLICY "Public can insert debug logs"
  ON debug_logs
  FOR INSERT
  TO public
  WITH CHECK (true);

CREATE POLICY "Public can view debug logs"
  ON debug_logs
  FOR SELECT
  TO public
  USING (true);

-- Add policy for reservation_items
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'reservation_items' 
    AND policyname = 'Public can create and view reservation items'
  ) THEN
    CREATE POLICY "Public can create and view reservation items"
      ON reservation_items
      FOR ALL
      TO public
      USING (true)
      WITH CHECK (true);
  END IF;
END $$;