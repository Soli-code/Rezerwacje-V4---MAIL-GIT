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
  recovery_token,
  email_change_token_new,
  email_change,
  phone,
  phone_confirmed_at,
  email_change_sent_at
)
SELECT
  '00000000-0000-0000-0000-000000000000',
  gen_random_uuid(),
  'authenticated',
  'authenticated',
  'biuro@solrent.pl',
  crypt('solikoduje', gen_salt('bf')),
  now(),
  jsonb_build_object(
    'provider', 'email',
    'providers', ARRAY['email']
  ),
  jsonb_build_object(
    'name', 'Administrator'
  ),
  now(),
  now(),
  '',
  '',
  '',
  '',
  NULL,
  NULL,
  NULL
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