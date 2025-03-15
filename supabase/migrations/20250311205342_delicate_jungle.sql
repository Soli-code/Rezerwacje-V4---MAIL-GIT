/*
  # Update SMTP host configuration

  1. Changes
    - Update SMTP host to h22.seohost.pl
    - Keep existing port and credentials
    - Update timestamp
*/

-- Update SMTP configuration
UPDATE smtp_settings
SET 
  host = 'h22.seohost.pl',
  updated_at = now()
WHERE id = (
  SELECT id FROM smtp_settings LIMIT 1
);

-- Add comment with DNS records
COMMENT ON TABLE smtp_settings IS E'SMTP Configuration\n\nDKIM: v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA+aRcMCDxMApYfUGX2VxCPz685F2/dJ+X9CBxxL0AFcukksKIa+CVoxfotGgFQYO1SqEXmfznH2MUZLz2MGXpQUymVnl1uo8ckiU7Su9mLosUBfAHAVAI/dsBOOws4/ECFMYvcqlVN9eDJgTzpdbj/JQB7m3B0jXchN++EHs5OabrLBTY4GN+D6iL1XtOBMkMJeqyi+pvAGU6MTyKsLBHnpT9yeTYsQDmX6j/hfVb+KRdPEYgOpwq4Xm2knjlBqPi5bXhkJ9cq4UnQniQWEO0X8+6L64uBfCsJgNajLTk3fpytYIYOBJlAuiGJMejVdo8VYXzGVy7pGh/aAQlYiOc8wIDAQAB\n\nSPF: v=spf1 redirect=_spf-h22.microhost.pl\n\nDMARC: v=DMARC1; p=none; sp=none; rua=mailto:spam-reports@microhost.pl\n\nMX: 10 mail.solrent.pl';