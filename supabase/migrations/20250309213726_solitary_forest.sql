/*
  # Format customer data

  1. Changes
    - Add function to format NIP number (XXX-XXX-XX-XX)
    - Add function to format postal code (XX-XXX)
    - Add triggers to automatically format data before insert/update

  2. Security
    - Functions are executed with security definer to ensure proper permissions
*/

-- Function to format NIP number
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
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to format postal code
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
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create triggers
DROP TRIGGER IF EXISTS format_company_nip_trigger ON customers;
CREATE TRIGGER format_company_nip_trigger
  BEFORE INSERT OR UPDATE ON customers
  FOR EACH ROW
  EXECUTE FUNCTION format_company_nip();

DROP TRIGGER IF EXISTS format_postal_code_trigger ON customers;
CREATE TRIGGER format_postal_code_trigger
  BEFORE INSERT OR UPDATE ON customers
  FOR EACH ROW
  EXECUTE FUNCTION format_postal_code();