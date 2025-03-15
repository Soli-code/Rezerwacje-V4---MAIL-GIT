-- Sprawdź ostatni wpis w email_logs
SELECT 
  el.*,
  r.start_date,
  r.end_date,
  c.email as customer_email,
  c.first_name,
  c.last_name
FROM email_logs el
JOIN reservations r ON r.id = el.reservation_id 
JOIN customers c ON c.id = r.customer_id
ORDER BY el.sent_at DESC
LIMIT 1;