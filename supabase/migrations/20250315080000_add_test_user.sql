-- Dodaj użytkownika testowego kubens11r@gmail.com, jeśli jeszcze nie istnieje
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
  updated_at
)
SELECT
  '00000000-0000-0000-0000-000000000000',
  gen_random_uuid(),
  'authenticated',
  'authenticated',
  'kubens11r@gmail.com',
  crypt('testpassword123', gen_salt('bf')),
  now(),
  '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Test User"}'::jsonb,
  now(),
  now()
WHERE NOT EXISTS (
  SELECT 1 FROM auth.users WHERE email = 'kubens11r@gmail.com'
);

-- Dodaj uprawnienia administratora dla użytkownika testowego
INSERT INTO profiles (id, is_admin)
SELECT id, true
FROM auth.users
WHERE email = 'kubens11r@gmail.com'
ON CONFLICT (id) DO UPDATE SET is_admin = true; 