/*
  # Walidacja danych firmowych

  1. Nowe funkcje:
    - Formatowanie NIP-u (XXX-XXX-XX-XX)
    - Formatowanie kodu pocztowego (XX-XXX)
    - Walidacja poprawności formatów

  2. Triggery:
    - Automatyczne formatowanie NIP-u
    - Automatyczne formatowanie kodu pocztowego

  3. Ograniczenia:
    - Sprawdzanie poprawności formatu NIP
    - Sprawdzanie poprawności formatu kodu pocztowego
*/

-- Funkcja formatująca NIP
CREATE OR REPLACE FUNCTION format_company_nip()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.company_nip IS NOT NULL THEN
    -- Usuń wszystkie znaki niebędące cyframi
    NEW.company_nip := regexp_replace(NEW.company_nip, '[^0-9]', '', 'g');
    
    -- Jeśli mamy dokładnie 10 cyfr, sformatuj jako XXX-XXX-XX-XX
    IF length(NEW.company_nip) = 10 THEN
      NEW.company_nip := substring(NEW.company_nip, 1, 3) || '-' ||
                        substring(NEW.company_nip, 4, 3) || '-' ||
                        substring(NEW.company_nip, 7, 2) || '-' ||
                        substring(NEW.company_nip, 9, 2);
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Funkcja formatująca kod pocztowy
CREATE OR REPLACE FUNCTION format_postal_code()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.company_postal_code IS NOT NULL THEN
    -- Usuń wszystkie znaki niebędące cyframi
    NEW.company_postal_code := regexp_replace(NEW.company_postal_code, '[^0-9]', '', 'g');
    
    -- Jeśli mamy dokładnie 5 cyfr, sformatuj jako XX-XXX
    IF length(NEW.company_postal_code) = 5 THEN
      NEW.company_postal_code := substring(NEW.company_postal_code, 1, 2) || '-' ||
                                substring(NEW.company_postal_code, 3, 3);
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Dodaj triggery formatujące
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

-- Dodaj ograniczenia sprawdzające format
ALTER TABLE customers DROP CONSTRAINT IF EXISTS valid_nip_format;
ALTER TABLE customers ADD CONSTRAINT valid_nip_format 
  CHECK (company_nip IS NULL OR company_nip ~ '^\d{3}-\d{3}-\d{2}-\d{2}$');

ALTER TABLE customers DROP CONSTRAINT IF EXISTS valid_postal_code_format;
ALTER TABLE customers ADD CONSTRAINT valid_postal_code_format 
  CHECK (company_postal_code IS NULL OR company_postal_code ~ '^\d{2}-\d{3}$');