/*
  # Usunięcie tabel związanych z obsługą maili

  1. Usuwane tabele:
    - email_logs - logi wysyłki maili
    - email_templates - szablony wiadomości
    - email_template_variables - zmienne w szablonach
    - email_retry_settings - ustawienia ponownych prób
    - smtp_settings - konfiguracja SMTP
    - smtp_settings_safe - widok bezpiecznej konfiguracji SMTP

  2. Zmiany:
    - Usunięcie wszystkich tabel związanych z mailami
    - Usunięcie powiązanych polityk dostępu
    - Usunięcie powiązanych wyzwalaczy
*/

-- Usunięcie widoku
DROP VIEW IF EXISTS smtp_settings_safe;

-- Usunięcie tabel w odpowiedniej kolejności (ze względu na zależności)
DROP TABLE IF EXISTS email_logs;
DROP TABLE IF EXISTS email_template_variables;
DROP TABLE IF EXISTS email_templates;
DROP TABLE IF EXISTS email_retry_settings;
DROP TABLE IF EXISTS smtp_settings;