/*
  # Create equipment and related tables

  1. New Tables
    - equipment: Main equipment table with basic info
    - equipment_specifications: Technical specifications
    - equipment_features: Equipment features
    - equipment_variants: Product variants
    - contact_info: Contact information
    
  2. Security
    - Enable RLS on all tables
    - Add policies for public access and admin management
    
  3. Indexes
    - Add indexes for foreign keys and frequently queried columns
*/

-- Create equipment table if not exists
CREATE TABLE IF NOT EXISTS equipment (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text NOT NULL,
  price numeric NOT NULL CHECK (price >= 0),
  deposit numeric NOT NULL DEFAULT 0 CHECK (deposit >= 0),
  image text NOT NULL,
  categories text[] NOT NULL DEFAULT ARRAY['budowlany'],
  quantity integer NOT NULL DEFAULT 1 CHECK (quantity >= 0),
  dimensions text,
  weight numeric,
  power_supply text,
  technical_details jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  last_modified_by uuid REFERENCES auth.users(id)
);

-- Create equipment_specifications table
CREATE TABLE IF NOT EXISTS equipment_specifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id uuid REFERENCES equipment(id) ON DELETE CASCADE,
  key text NOT NULL,
  value text NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create equipment_features table
CREATE TABLE IF NOT EXISTS equipment_features (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id uuid REFERENCES equipment(id) ON DELETE CASCADE,
  text text NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create equipment_variants table
CREATE TABLE IF NOT EXISTS equipment_variants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id uuid REFERENCES equipment(id) ON DELETE CASCADE,
  name text NOT NULL,
  price numeric NOT NULL CHECK (price >= 0),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create contact_info table
CREATE TABLE IF NOT EXISTS contact_info (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone_number text NOT NULL,
  email text NOT NULL,
  updated_at timestamptz DEFAULT now()
);

-- Enable Row Level Security
DO $$ 
BEGIN
  -- Enable RLS for each table if not already enabled
  IF NOT EXISTS (
    SELECT 1 FROM pg_tables 
    WHERE schemaname = 'public' 
    AND tablename = 'equipment' 
    AND rowsecurity = true
  ) THEN
    ALTER TABLE equipment ENABLE ROW LEVEL SECURITY;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_tables 
    WHERE schemaname = 'public' 
    AND tablename = 'equipment_specifications' 
    AND rowsecurity = true
  ) THEN
    ALTER TABLE equipment_specifications ENABLE ROW LEVEL SECURITY;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_tables 
    WHERE schemaname = 'public' 
    AND tablename = 'equipment_features' 
    AND rowsecurity = true
  ) THEN
    ALTER TABLE equipment_features ENABLE ROW LEVEL SECURITY;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_tables 
    WHERE schemaname = 'public' 
    AND tablename = 'equipment_variants' 
    AND rowsecurity = true
  ) THEN
    ALTER TABLE equipment_variants ENABLE ROW LEVEL SECURITY;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_tables 
    WHERE schemaname = 'public' 
    AND tablename = 'contact_info' 
    AND rowsecurity = true
  ) THEN
    ALTER TABLE contact_info ENABLE ROW LEVEL SECURITY;
  END IF;
END $$;

-- Create policies
DO $$ 
BEGIN
  -- Equipment policies
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'equipment' AND policyname = 'Anyone can view equipment') THEN
    CREATE POLICY "Anyone can view equipment" ON equipment FOR SELECT TO public USING (true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'equipment' AND policyname = 'Only admins can insert equipment') THEN
    CREATE POLICY "Only admins can insert equipment" ON equipment FOR INSERT TO authenticated
    WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.is_admin = true));
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'equipment' AND policyname = 'Only admins can update equipment') THEN
    CREATE POLICY "Only admins can update equipment" ON equipment FOR UPDATE TO authenticated
    USING (EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.is_admin = true))
    WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.is_admin = true));
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'equipment' AND policyname = 'Only admins can delete equipment') THEN
    CREATE POLICY "Only admins can delete equipment" ON equipment FOR DELETE TO authenticated
    USING (EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.is_admin = true));
  END IF;

  -- Equipment specifications policies
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'equipment_specifications' AND policyname = 'Anyone can view specifications') THEN
    CREATE POLICY "Anyone can view specifications" ON equipment_specifications FOR SELECT TO public USING (true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'equipment_specifications' AND policyname = 'Only admins can modify specifications') THEN
    CREATE POLICY "Only admins can modify specifications" ON equipment_specifications FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.is_admin = true));
  END IF;

  -- Equipment features policies
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'equipment_features' AND policyname = 'Anyone can view features') THEN
    CREATE POLICY "Anyone can view features" ON equipment_features FOR SELECT TO public USING (true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'equipment_features' AND policyname = 'Only admins can modify features') THEN
    CREATE POLICY "Only admins can modify features" ON equipment_features FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.is_admin = true));
  END IF;

  -- Equipment variants policies
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'equipment_variants' AND policyname = 'Anyone can view variants') THEN
    CREATE POLICY "Anyone can view variants" ON equipment_variants FOR SELECT TO public USING (true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'equipment_variants' AND policyname = 'Only admins can modify variants') THEN
    CREATE POLICY "Only admins can modify variants" ON equipment_variants FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.is_admin = true));
  END IF;

  -- Contact info policies
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'contact_info' AND policyname = 'Anyone can view contact info') THEN
    CREATE POLICY "Anyone can view contact info" ON contact_info FOR SELECT TO public USING (true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'contact_info' AND policyname = 'Only admins can modify contact info') THEN
    CREATE POLICY "Only admins can modify contact info" ON contact_info FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.is_admin = true));
  END IF;
END $$;

-- Insert default contact info if not exists
INSERT INTO contact_info (phone_number, email)
VALUES ('694 171 171', 'kontakt@solrent.pl')
ON CONFLICT DO NOTHING;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_equipment_categories ON equipment USING GIN (categories);
CREATE INDEX IF NOT EXISTS idx_equipment_specifications_equipment_id ON equipment_specifications (equipment_id);
CREATE INDEX IF NOT EXISTS idx_equipment_features_equipment_id ON equipment_features (equipment_id);
CREATE INDEX IF NOT EXISTS idx_equipment_variants_equipment_id ON equipment_variants (equipment_id);