/*
  # Add company data fields and validation

  1. New Fields
    - Dodanie pól dla danych firmowych w tabeli customers:
      - company_name (text, nullable)
      - company_nip (text, nullable)
      - company_street (text, nullable)
      - company_postal_code (text, nullable)
      - company_city (text, nullable)

  2. Validation
    - Dodanie walidacji formatu NIP (XXX-XXX-XX-XX)
    - Dodanie walidacji formatu kodu pocztowego (XX-XXX)
    - Dodanie triggerów formatujących NIP i kod pocztowy

  3. Funkcje pomocnicze
    - Funkcja formatująca NIP
    - Funkcja formatująca kod pocztowy
*/

-- Sprawdź czy kolumny już istnieją i dodaj je jeśli nie
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'customers' AND column_name = 'company_name') THEN
    ALTER TABLE customers ADD COLUMN company_name text;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'customers' AND column_name = 'company_nip') THEN
    ALTER TABLE customers ADD COLUMN company_nip text;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'customers' AND column_name = 'company_street') THEN
    ALTER TABLE customers ADD COLUMN company_street text;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'customers' AND column_name = 'company_postal_code') THEN
    ALTER TABLE customers ADD COLUMN company_postal_code text;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'customers' AND column_name = 'company_city') THEN
    ALTER TABLE customers ADD COLUMN company_city text;
  END IF;
END $$;

-- Funkcja formatująca NIP
CREATE OR REPLACE FUNCTION format_company_nip()
RETURNS trigger AS $$
BEGIN
  IF NEW.company_nip IS NOT NULL THEN
    -- Usuń wszystkie znaki niebędące cyframi
    NEW.company_nip := regexp_replace(NEW.company_nip, '[^0-9]', '', 'g');
    -- Formatuj jako XXX-XXX-XX-XX
    NEW.company_nip := regexp_replace(NEW.company_nip, '([0-9]{3})([0-9]{3})([0-9]{2})([0-9]{2})', '\1-\2-\3-\4');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Funkcja formatująca kod pocztowy
CREATE OR REPLACE FUNCTION format_postal_code()
RETURNS trigger AS $$
BEGIN
  IF NEW.company_postal_code IS NOT NULL THEN
    -- Usuń wszystkie znaki niebędące cyframi
    NEW.company_postal_code := regexp_replace(NEW.company_postal_code, '[^0-9]', '', 'g');
    -- Formatuj jako XX-XXX
    NEW.company_postal_code := regexp_replace(NEW.company_postal_code, '([0-9]{2})([0-9]{3})', '\1-\2');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Dodaj triggery formatujące
DROP TRIGGER IF EXISTS format_company_nip_trigger ON customers;
CREATE TRIGGER format_company_nip_trigger
  BEFORE INSERT OR UPDATE OF company_nip ON customers
  FOR EACH ROW
  WHEN (NEW.company_nip IS NOT NULL)
  EXECUTE FUNCTION format_company_nip();

DROP TRIGGER IF EXISTS format_postal_code_trigger ON customers;
CREATE TRIGGER format_postal_code_trigger
  BEFORE INSERT OR UPDATE OF company_postal_code ON customers
  FOR EACH ROW
  WHEN (NEW.company_postal_code IS NOT NULL)
  EXECUTE FUNCTION format_postal_code();

-- Dodaj walidację formatu NIP i kodu pocztowego
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'valid_nip_format_new'
  ) THEN
    ALTER TABLE customers
    ADD CONSTRAINT valid_nip_format_new 
    CHECK (company_nip IS NULL OR company_nip ~ '^[0-9]{3}-[0-9]{3}-[0-9]{2}-[0-9]{2}$');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'valid_postal_code_format_new'
  ) THEN
    ALTER TABLE customers
    ADD CONSTRAINT valid_postal_code_format_new 
    CHECK (company_postal_code IS NULL OR company_postal_code ~ '^[0-9]{2}-[0-9]{3}$');
  END IF;
END $$;