-- Najpierw usuń referencje do usuwanego użytkownika
UPDATE customer_activities
SET created_by = NULL
WHERE created_by IN (
  SELECT id FROM auth.users WHERE email = 'biuro@solrent.pl'
);

UPDATE reservation_history
SET changed_by = NULL
WHERE changed_by IN (
  SELECT id FROM auth.users WHERE email = 'biuro@solrent.pl'
);

UPDATE customer_tags
SET created_by = NULL
WHERE created_by IN (
  SELECT id FROM auth.users WHERE email = 'biuro@solrent.pl'
);

UPDATE crm_contacts
SET assigned_to = NULL
WHERE assigned_to IN (
  SELECT id FROM auth.users WHERE email = 'biuro@solrent.pl'
);

UPDATE crm_tasks
SET assigned_to = NULL
WHERE assigned_to IN (
  SELECT id FROM auth.users WHERE email = 'biuro@solrent.pl'
);

UPDATE crm_documents
SET uploaded_by = NULL
WHERE uploaded_by IN (
  SELECT id FROM auth.users WHERE email = 'biuro@solrent.pl'
);

UPDATE crm_interactions
SET created_by = NULL
WHERE created_by IN (
  SELECT id FROM auth.users WHERE email = 'biuro@solrent.pl'
);

UPDATE equipment
SET last_modified_by = NULL
WHERE last_modified_by IN (
  SELECT id FROM auth.users WHERE email = 'biuro@solrent.pl'
);

-- Usuń istniejącego użytkownika administratora
DELETE FROM auth.users WHERE email = 'biuro@solrent.pl';

-- Utwórz nowego użytkownika administratora
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
  updated_at
)
VALUES (
  '00000000-0000-0000-0000-000000000000',
  gen_random_uuid(),
  'authenticated',
  'authenticated',
  'biuro@solrent.pl',
  crypt('admin123', gen_salt('bf')),
  '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Administrator"}'::jsonb,
  now(),
  now()
);

-- Dodaj uprawnienia administratora
INSERT INTO profiles (id, is_admin)
SELECT id, true
FROM auth.users
WHERE email = 'biuro@solrent.pl'
ON CONFLICT (id) DO UPDATE SET is_admin = true;