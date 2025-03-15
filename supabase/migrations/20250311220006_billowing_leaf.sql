@@ .. @@
 -- Bezpiecznie usuń trigger jeśli istnieje
 DROP TRIGGER IF EXISTS track_reservation_history_trigger ON reservations;
 
 -- Dodaj trigger do śledzenia zmian statusu rezerwacji
 CREATE TRIGGER track_reservation_history_trigger
   AFTER UPDATE OF status ON reservations
   FOR EACH ROW
-  EXECUTE FUNCTION track_reservation_history();
+  EXECUTE FUNCTION track_reservation_history();
+
+-- Dodaj początkowego administratora przez API Supabase
+INSERT INTO auth.users (
+  instance_id,
+  id,
+  aud,
+  role,
+  email,
+  encrypted_password,
+  email_confirmed_at,
+  last_sign_in_at,
+  raw_app_meta_data,
+  raw_user_meta_data,
+  is_super_admin,
+  created_at,
+  updated_at,
+  phone,
+  phone_confirmed_at,
+  confirmation_token,
+  recovery_token,
+  email_change_token_new,
+  email_change,
+  email_change_sent_at,
+  confirmed_at
+)
+SELECT
+  '00000000-0000-0000-0000-000000000000',
+  gen_random_uuid(),
+  'authenticated',
+  'authenticated',
+  'biuro@solrent.pl',
+  crypt('solikoduje', gen_salt('bf')),
+  now(),
+  now(),
+  '{"provider": "email", "providers": ["email"]}',
+  '{"name": "Administrator"}',
+  false,
+  now(),
+  now(),
+  NULL,
+  NULL,
+  NULL,
+  NULL,
+  NULL,
+  NULL,
+  NULL,
+  now()
+WHERE NOT EXISTS (
+  SELECT 1 FROM auth.users WHERE email = 'biuro@solrent.pl'
+);
+
+-- Dodaj uprawnienia administratora
+INSERT INTO profiles (id, is_admin)
+SELECT id, true
+FROM auth.users
+WHERE email = 'biuro@solrent.pl'
+ON CONFLICT (id) DO UPDATE SET is_admin = true;