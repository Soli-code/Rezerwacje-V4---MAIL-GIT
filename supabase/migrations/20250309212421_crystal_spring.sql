/*
  # Poprawa formatu NIP i walidacji danych firmowych

  1. Zmiany w tabeli customers:
    - Modyfikacja ograniczenia valid_nip_format
    - Dodanie funkcji formatującej NIP
    - Aktualizacja triggera format_company_nip

  2. Bezpieczeństwo:
    - Zachowanie istniejących polityk dostępu
    - Walidacja formatu NIP przed zapisem
*/

-- Usuń stare ograniczenie
ALTER TABLE customers DROP CONSTRAINT IF EXISTS valid_nip_format;

-- Dodaj nowe ograniczenie z bardziej elastycznym formatem
ALTER TABLE customers ADD CONSTRAINT valid_nip_format 
  CHECK (company_nip IS NULL OR company_nip ~ '^\d{10}$' OR company_nip ~ '^\d{3}-\d{3}-\d{2}-\d{2}$');

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

-- Upewnij się, że trigger jest aktywny
DROP TRIGGER IF EXISTS format_company_nip_trigger ON customers;
CREATE TRIGGER format_company_nip_trigger
  BEFORE INSERT OR UPDATE ON customers
  FOR EACH ROW
  EXECUTE FUNCTION format_company_nip();