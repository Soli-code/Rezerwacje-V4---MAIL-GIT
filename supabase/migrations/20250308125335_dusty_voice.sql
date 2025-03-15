/*
  # Add Equipment Management Features

  1. New Tables
    - `equipment_history`: Track changes to equipment
    - `equipment_drafts`: Store draft versions of equipment
    - `specifications`: Technical specifications for equipment
    - `features`: Key features of equipment
    - `variants`: Product variants with different prices

  2. Changes
    - Add new columns to equipment table
    - Add tracking for modifications

  3. Security
    - Add RLS policies for new tables
    - Restrict access to admin users
*/

-- Add new columns to equipment table
ALTER TABLE equipment
ADD COLUMN IF NOT EXISTS last_modified_by uuid REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now(),
ADD COLUMN IF NOT EXISTS technical_details jsonb;

-- Create equipment history table
CREATE TABLE IF NOT EXISTS equipment_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id uuid REFERENCES equipment(id) ON DELETE CASCADE,
  changed_at timestamptz DEFAULT now(),
  changed_by uuid REFERENCES auth.users(id),
  changes jsonb NOT NULL
);

-- Create equipment drafts table
CREATE TABLE IF NOT EXISTS equipment_drafts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id uuid REFERENCES equipment(id) ON DELETE CASCADE,
  draft_data jsonb NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  last_modified_by uuid REFERENCES auth.users(id)
);

-- Create specifications table
CREATE TABLE IF NOT EXISTS specifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id uuid REFERENCES equipment(id) ON DELETE CASCADE,
  key text NOT NULL,
  value text NOT NULL,
  sort_order integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- Create features table
CREATE TABLE IF NOT EXISTS features (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id uuid REFERENCES equipment(id) ON DELETE CASCADE,
  text text NOT NULL,
  sort_order integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- Create variants table
CREATE TABLE IF NOT EXISTS variants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id uuid REFERENCES equipment(id) ON DELETE CASCADE,
  name text NOT NULL,
  price numeric NOT NULL CHECK (price >= 0),
  sort_order integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- Create trigger function to track equipment changes
CREATE OR REPLACE FUNCTION track_equipment_changes()
RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    INSERT INTO equipment_history (
      equipment_id,
      changed_by,
      changes
    ) VALUES (
      NEW.id,
      NEW.last_modified_by,
      jsonb_build_object(
        'before', to_jsonb(OLD),
        'after', to_jsonb(NEW)
      )
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for equipment changes
CREATE TRIGGER equipment_history_trigger
  AFTER UPDATE ON equipment
  FOR EACH ROW
  EXECUTE FUNCTION track_equipment_changes();

-- Enable RLS
ALTER TABLE equipment_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE equipment_drafts ENABLE ROW LEVEL SECURITY;
ALTER TABLE specifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE features ENABLE ROW LEVEL SECURITY;
ALTER TABLE variants ENABLE ROW LEVEL SECURITY;

-- RLS Policies for equipment_history
CREATE POLICY "Admins can view equipment history"
  ON equipment_history FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND is_admin = true
    )
  );

-- RLS Policies for equipment_drafts
CREATE POLICY "Admins can manage drafts"
  ON equipment_drafts FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND is_admin = true
    )
  );

-- RLS Policies for specifications
CREATE POLICY "Public can view specifications"
  ON specifications FOR SELECT
  TO public
  USING (true);

CREATE POLICY "Admins can manage specifications"
  ON specifications FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND is_admin = true
    )
  );

-- RLS Policies for features
CREATE POLICY "Public can view features"
  ON features FOR SELECT
  TO public
  USING (true);

CREATE POLICY "Admins can manage features"
  ON features FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND is_admin = true
    )
  );

-- RLS Policies for variants
CREATE POLICY "Public can view variants"
  ON variants FOR SELECT
  TO public
  USING (true);

CREATE POLICY "Admins can manage variants"
  ON variants FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND is_admin = true
    )
  );

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_equipment_history_equipment_id ON equipment_history(equipment_id);
CREATE INDEX IF NOT EXISTS idx_equipment_drafts_equipment_id ON equipment_drafts(equipment_id);
CREATE INDEX IF NOT EXISTS idx_specifications_equipment_id ON specifications(equipment_id);
CREATE INDEX IF NOT EXISTS idx_features_equipment_id ON features(equipment_id);
CREATE INDEX IF NOT EXISTS idx_variants_equipment_id ON variants(equipment_id);