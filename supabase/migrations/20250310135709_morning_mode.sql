/*
  # Email System Improvements - Part 2

  1. New Features
    - Add email priority tracking
    - Add delivery metrics
    - Improve error handling

  2. Changes
    - Add new columns for better monitoring
    - Add indexes for performance
    - Update constraints for better data integrity
*/

-- Add new columns for better monitoring
ALTER TABLE email_notifications
ADD COLUMN IF NOT EXISTS priority text DEFAULT 'normal',
ADD COLUMN IF NOT EXISTS delivery_time interval,
ADD COLUMN IF NOT EXISTS retry_count integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS headers jsonb,
ADD COLUMN IF NOT EXISTS metrics jsonb;

-- Add check constraint for priority
ALTER TABLE email_notifications
ADD CONSTRAINT email_notifications_priority_check
CHECK (priority IN ('high', 'normal', 'low'));

-- Add index for monitoring
CREATE INDEX IF NOT EXISTS idx_email_notifications_delivery_time
ON email_notifications(delivery_time)
WHERE delivery_time IS NOT NULL;

-- Create view for email metrics
CREATE OR REPLACE VIEW email_delivery_metrics AS
SELECT
  date_trunc('hour', created_at) as time_bucket,
  type,
  status,
  count(*) as count,
  avg(EXTRACT(EPOCH FROM delivery_time)) as avg_delivery_time_seconds,
  sum(retry_count) as total_retries
FROM email_notifications
GROUP BY 1, 2, 3
ORDER BY 1 DESC;

-- Function to calculate delivery time
CREATE OR REPLACE FUNCTION update_email_delivery_time()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'delivered' AND OLD.status != 'delivered' THEN
    NEW.delivery_time = NEW.updated_at - NEW.created_at;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for delivery time calculation
CREATE TRIGGER calculate_delivery_time
  BEFORE UPDATE OF status ON email_notifications
  FOR EACH ROW
  EXECUTE FUNCTION update_email_delivery_time();

-- Function to update retry count
CREATE OR REPLACE FUNCTION increment_retry_count()
RETURNS TRIGGER AS $$
BEGIN
  NEW.retry_count = OLD.retry_count + 1;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for retry count
CREATE TRIGGER update_retry_count
  BEFORE UPDATE OF status ON email_notifications
  FOR EACH ROW
  WHEN (NEW.status = 'pending' AND OLD.status = 'failed')
  EXECUTE FUNCTION increment_retry_count();