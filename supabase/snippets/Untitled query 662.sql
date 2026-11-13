ALTER TABLE account_requests 
ADD COLUMN IF NOT EXISTS salt TEXT,
ADD COLUMN IF NOT EXISTS password_hash TEXT;

-- Notifica o PostgREST para recarregar a estrutura das tabelas
NOTIFY pgrst, 'reload schema';