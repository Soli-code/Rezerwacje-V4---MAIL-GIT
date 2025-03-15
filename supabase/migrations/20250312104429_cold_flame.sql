/*
  # Remove admin user

  1. Changes
    - Remove admin user from auth.users table
    - Remove admin profile from profiles table
    - Keep RLS policies and other security settings
*/

-- Remove admin profile
DELETE FROM profiles 
WHERE id IN (
  SELECT id FROM auth.users WHERE email = 'biuro@solrent.pl'
);

-- Remove admin user
DELETE FROM auth.users 
WHERE email = 'biuro@solrent.pl';