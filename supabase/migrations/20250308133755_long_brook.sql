/*
  # Create contact info table

  1. New Tables
    - `contact_info`
      - `id` (uuid, primary key)
      - `phone_number` (text)
      - `email` (text)
      - `updated_at` (timestamp with time zone)

  2. Security
    - Enable RLS on `contact_info` table
    - Add policy for public read access
*/

CREATE TABLE IF NOT EXISTS contact_info (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone_number text NOT NULL,
  email text NOT NULL,
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE contact_info ENABLE ROW LEVEL SECURITY;

-- Add RLS policies
CREATE POLICY "Allow public read access to contact info"
  ON contact_info
  FOR SELECT
  TO public
  USING (true);

-- Insert default contact info
INSERT INTO contact_info (phone_number, email)
VALUES ('694 171 171', 'kontakt@solrent.pl');