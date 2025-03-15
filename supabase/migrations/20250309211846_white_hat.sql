/*
  # Add company fields to customers table

  1. New Columns
    - company_name (text) - pełna nazwa firmy
    - company_nip (text) - numer NIP firmy w formacie XXX-XXX-XX-XX
    - company_street (text) - ulica i numer siedziby firmy
    - company_postal_code (text) - kod pocztowy w formacie XX-XXX
    - company_city (text) - miasto siedziby firmy

  2. Validation
    - Dodano walidację formatu NIP
    - Dodano walidację formatu kodu pocztowego
    - Wszystkie pola są opcjonalne

  3. Changes
    - Dodano nowe kolumny do tabeli customers
    - Dodano walidację formatów danych
*/

-- Dodaj nowe kolumny do tabeli customers
ALTER TABLE customers
ADD COLUMN company_name text,
ADD COLUMN company_nip text,
ADD COLUMN company_street text,
ADD COLUMN company_postal_code text,
ADD COLUMN company_city text;

-- Dodaj walidację formatu NIP
ALTER TABLE customers
ADD CONSTRAINT valid_nip_format
CHECK (
  company_nip IS NULL OR 
  company_nip ~ '^[0-9]{3}-[0-9]{3}-[0-9]{2}-[0-9]{2}$'
);

-- Dodaj walidację formatu kodu pocztowego
ALTER TABLE customers
ADD CONSTRAINT valid_postal_code_format
CHECK (
  company_postal_code IS NULL OR 
  company_postal_code ~ '^[0-9]{2}-[0-9]{3}$'
);

-- Dodaj trigger do automatycznego formatowania NIP
CREATE OR REPLACE FUNCTION format_company_nip()
RETURNS trigger AS $$
BEGIN
  IF NEW.company_nip IS NOT NULL THEN
    -- Usuń wszystkie znaki niebędące cyframi
    NEW.company_nip := regexp_replace(NEW.company_nip, '[^0-9]', '', 'g');
    -- Dodaj myślniki w odpowiednich miejscach
    NEW.company_nip := substring(NEW.company_nip, 1, 3) || '-' ||
                      substring(NEW.company_nip, 4, 3) || '-' ||
                      substring(NEW.company_nip, 7, 2) || '-' ||
                      substring(NEW.company_nip, 9, 2);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER format_company_nip_trigger
BEFORE INSERT OR UPDATE ON customers
FOR EACH ROW
EXECUTE FUNCTION format_company_nip();

-- Dodaj trigger do automatycznego formatowania kodu pocztowego
CREATE OR REPLACE FUNCTION format_postal_code()
RETURNS trigger AS $$
BEGIN
  IF NEW.company_postal_code IS NOT NULL THEN
    -- Usuń wszystkie znaki niebędące cyframi
    NEW.company_postal_code := regexp_replace(NEW.company_postal_code, '[^0-9]', '', 'g');
    -- Dodaj myślnik w odpowiednim miejscu
    NEW.company_postal_code := substring(NEW.company_postal_code, 1, 2) || '-' ||
                              substring(NEW.company_postal_code, 3, 3);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER format_postal_code_trigger
BEFORE INSERT OR UPDATE ON customers
FOR EACH ROW
EXECUTE FUNCTION format_postal_code();