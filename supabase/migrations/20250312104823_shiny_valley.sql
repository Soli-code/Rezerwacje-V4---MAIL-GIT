/*
  # Add admin privileges to existing user

  1. Changes
    - Update profiles table to set is_admin=true for biuro@solrent.pl user
    - Add policy for viewing profiles
*/

-- Enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Public can view profiles" ON profiles;
DROP POLICY IF EXISTS "Anyone can view profiles" ON profiles;

-- Create new policy
CREATE POLICY "Anyone can view profiles"
  ON profiles
  FOR SELECT
  TO authenticated
  USING (true);

-- Add admin privileges to existing user
INSERT INTO profiles (id, is_admin)
SELECT id, true
FROM auth.users
WHERE email = 'biuro@solrent.pl'
ON CONFLICT (id) DO UPDATE SET is_admin = true;