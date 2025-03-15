/*
  # Add initial admin user

  1. Changes
    - Add admin user with email and password
    - Set admin flag in profiles table
*/

-- Add initial admin user if not exists
INSERT INTO auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  confirmation_token,
  recovery_token
)
SELECT
  '00000000-0000-0000-0000-000000000000',
  gen_random_uuid(),
  'authenticated',
  'authenticated',
  'biuro@solrent.pl',
  crypt('solikoduje', gen_salt('bf')),
  now(),
  '{"provider": "email", "providers": ["email"]}',
  '{"name": "Administrator"}',
  now(),
  now(),
  '',
  ''
WHERE NOT EXISTS (
  SELECT 1 FROM auth.users WHERE email = 'biuro@solrent.pl'
)
RETURNING id;

-- Add admin privileges
INSERT INTO profiles (id, is_admin)
SELECT id, true
FROM auth.users
WHERE email = 'biuro@solrent.pl'
ON CONFLICT (id) DO UPDATE SET is_admin = true;