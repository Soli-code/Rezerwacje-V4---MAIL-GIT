/*
  # Fix company data validation

  1. Changes
    - Update NIP format validation to handle input formatting
    - Update postal code format validation to handle input formatting
    - Add triggers to automatically format data before insert/update
    - Update constraints to properly validate formats

  2. Security
    - Functions are executed with security definer to ensure proper permissions
*/

-- Function to format and validate NIP
CREATE OR REPLACE FUNCTION format_company_nip()
RETURNS trigger AS $$
BEGIN
  IF NEW.company_nip IS NOT NULL THEN
    -- Remove all non-digit characters
    NEW.company_nip := regexp_replace(NEW.company_nip, '[^0-9]', '', 'g');
    
    -- Check if we have exactly 10 digits
    IF length(NEW.company_nip) = 10 THEN
      -- Format as XXX-XXX-XX-XX
      NEW.company_nip := regexp_replace(NEW.company_nip, '(\d{3})(\d{3})(\d{2})(\d{2})', '\1-\2-\3-\4');
    ELSE
      RAISE EXCEPTION 'Nieprawidłowy format NIP. Wymagane jest 10 cyfr.';
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to format and validate postal code
CREATE OR REPLACE FUNCTION format_postal_code()
RETURNS trigger AS $$
BEGIN
  IF NEW.company_postal_code IS NOT NULL THEN
    -- Remove all non-digit characters
    NEW.company_postal_code := regexp_replace(NEW.company_postal_code, '[^0-9]', '', 'g');
    
    -- Check if we have exactly 5 digits
    IF length(NEW.company_postal_code) = 5 THEN
      -- Format as XX-XXX
      NEW.company_postal_code := regexp_replace(NEW.company_postal_code, '(\d{2})(\d{3})', '\1-\2');
    ELSE
      RAISE EXCEPTION 'Nieprawidłowy format kodu pocztowego. Wymagane jest 5 cyfr.';
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing triggers if they exist
DROP TRIGGER IF EXISTS format_company_nip_trigger ON customers;
DROP TRIGGER IF EXISTS format_postal_code_trigger ON customers;

-- Create new triggers
CREATE TRIGGER format_company_nip_trigger
  BEFORE INSERT OR UPDATE OF company_nip ON customers
  FOR EACH ROW
  WHEN (NEW.company_nip IS NOT NULL)
  EXECUTE FUNCTION format_company_nip();

CREATE TRIGGER format_postal_code_trigger
  BEFORE INSERT OR UPDATE OF company_postal_code ON customers
  FOR EACH ROW
  WHEN (NEW.company_postal_code IS NOT NULL)
  EXECUTE FUNCTION format_postal_code();

-- Update constraints
ALTER TABLE customers DROP CONSTRAINT IF EXISTS valid_nip_format;
ALTER TABLE customers DROP CONSTRAINT IF EXISTS valid_postal_code_format;

ALTER TABLE customers ADD CONSTRAINT valid_nip_format
  CHECK (company_nip IS NULL OR company_nip ~ '^\d{3}-\d{3}-\d{2}-\d{2}$');

ALTER TABLE customers ADD CONSTRAINT valid_postal_code_format
  CHECK (company_postal_code IS NULL OR company_postal_code ~ '^\d{2}-\d{3}$');