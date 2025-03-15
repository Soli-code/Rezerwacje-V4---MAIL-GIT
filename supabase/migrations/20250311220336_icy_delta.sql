/*
  # Create admin user

  1. Changes
    - Create admin user with proper schema
    - Add admin role to profiles table
    - Use proper column constraints
*/

-- Dodaj początkowego administratora
INSERT INTO auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  last_sign_in_at
)
SELECT
  '00000000-0000-0000-0000-000000000000',
  gen_random_uuid(),
  'authenticated',
  'authenticated',
  'biuro@solrent.pl',
  crypt('solikoduje', gen_salt('bf')),
  '{"provider": "email", "providers": ["email"]}',
  '{"name": "Administrator"}',
  now(),
  now(),
  now()
WHERE NOT EXISTS (
  SELECT 1 FROM auth.users WHERE email = 'biuro@solrent.pl'
)
RETURNING id;

-- Dodaj uprawnienia administratora
INSERT INTO profiles (id, is_admin)
SELECT id, true
FROM auth.users
WHERE email = 'biuro@solrent.pl'
ON CONFLICT (id) DO UPDATE SET is_admin = true;