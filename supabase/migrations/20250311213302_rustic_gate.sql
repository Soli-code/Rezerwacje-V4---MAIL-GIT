/*
  # Remove backup system

  1. Changes
    - Remove all backup-related tables
    - Remove backup-related functions
    - Remove backup-related triggers
*/

-- Drop backup tables if they exist
DROP TABLE IF EXISTS temp_reservation_items CASCADE;
DROP TABLE IF EXISTS equipment_drafts CASCADE;
DROP TABLE IF EXISTS equipment_history CASCADE;

-- Drop backup functions if they exist
DROP FUNCTION IF EXISTS revert_equipment_description_merge() CASCADE;
DROP FUNCTION IF EXISTS track_equipment_changes() CASCADE;

-- Remove backup triggers
DROP TRIGGER IF EXISTS equipment_history_trigger ON equipment;