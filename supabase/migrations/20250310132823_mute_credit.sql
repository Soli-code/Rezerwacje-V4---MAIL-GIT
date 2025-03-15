/*
  # Usunięcie systemu mailowego

  1. Zmiany:
    - Usunięcie triggera wysyłki maili z tabeli reservations
    - Usunięcie funkcji obsługującej wysyłkę maili
    - Usunięcie referencji do email_templates

  2. Bezpieczeństwo:
    - Zachowanie integralności danych rezerwacji
    - Brak wpływu na istniejące rezerwacje
*/

-- Usuń trigger wysyłki maili z tabeli reservations
DROP TRIGGER IF EXISTS send_new_reservation_email ON reservations;

-- Usuń funkcję obsługującą wysyłkę maili
DROP FUNCTION IF EXISTS handle_new_reservation_email();

-- Usuń funkcję obsługującą ponowne próby wysyłki
DROP FUNCTION IF EXISTS handle_email_retry();

-- Usuń funkcję sprawdzającą ustawienia SMTP
DROP FUNCTION IF EXISTS check_smtp_settings_count();

-- Usuń funkcję logującą dostęp do SMTP
DROP FUNCTION IF EXISTS log_smtp_access();

-- Upewnij się, że status rezerwacji jest ustawiany poprawnie bez maili
CREATE OR REPLACE FUNCTION update_reservation_status(
  p_reservation_id uuid,
  p_new_status text,
  p_comment text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Sprawdź czy status jest poprawny
  IF p_new_status NOT IN ('pending', 'confirmed', 'cancelled', 'completed') THEN
    RAISE EXCEPTION 'Invalid status: %', p_new_status;
  END IF;

  -- Zaktualizuj status rezerwacji
  UPDATE reservations 
  SET status = p_new_status,
      updated_at = now()
  WHERE id = p_reservation_id;

  -- Zapisz historię zmiany
  INSERT INTO reservation_history (
    reservation_id,
    previous_status,
    new_status,
    changed_at,
    changed_by,
    comment
  )
  SELECT 
    p_reservation_id,
    status,
    p_new_status,
    now(),
    auth.uid(),
    p_comment
  FROM reservations
  WHERE id = p_reservation_id;

END;
$$;