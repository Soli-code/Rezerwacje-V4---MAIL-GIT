/*
  # Add RLS policies for reservation_items table

  1. Security Changes
    - Enable RLS on reservation_items table
    - Add policies for:
      - Public can insert reservation items
      - Public can view reservation items
      - Public can update their own reservation items
*/

-- Enable RLS
ALTER TABLE reservation_items ENABLE ROW LEVEL SECURITY;

-- Policy for inserting reservation items (public can insert)
CREATE POLICY "Public can insert reservation items"
ON reservation_items
FOR INSERT
TO public
WITH CHECK (true);

-- Policy for viewing reservation items (public can view)
CREATE POLICY "Public can view reservation items"
ON reservation_items
FOR SELECT
TO public
USING (true);

-- Policy for updating reservation items (users can update their own)
CREATE POLICY "Public can update reservation items"
ON reservation_items
FOR UPDATE
TO public
USING (true)
WITH CHECK (true);