/*
  # Add CASCADE delete behavior to foreign keys

  1. Changes
    - Add ON DELETE CASCADE to the foreign key constraint in reservations table
    - Add ON DELETE CASCADE to the foreign key constraint in reservation_items table

  2. Purpose
    - Allow automatic deletion of related reservations when a customer is deleted
    - Allow automatic deletion of reservation items when a reservation is deleted
*/

-- First, drop existing foreign key constraints
ALTER TABLE reservations 
DROP CONSTRAINT IF EXISTS reservations_customer_id_fkey;

ALTER TABLE reservation_items
DROP CONSTRAINT IF EXISTS reservation_items_reservation_id_fkey;

-- Re-create foreign key constraints with CASCADE delete
ALTER TABLE reservations
ADD CONSTRAINT reservations_customer_id_fkey 
FOREIGN KEY (customer_id) 
REFERENCES customers(id) 
ON DELETE CASCADE;

ALTER TABLE reservation_items
ADD CONSTRAINT reservation_items_reservation_id_fkey 
FOREIGN KEY (reservation_id) 
REFERENCES reservations(id) 
ON DELETE CASCADE;