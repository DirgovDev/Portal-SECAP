-- supabase/migrations/20261113120000_remove_modernization.sql
drop function if exists public.mod_import(jsonb, jsonb, boolean);
drop function if exists public.mod_rate_request(text, integer, text);
drop function if exists public.mod_change_status(text, text, text, text);
drop function if exists public.mod_create_request(jsonb);
drop function if exists public.mod_detail(text);
drop function if exists public.mod_text(text);

drop table if exists public.modernization_history;
drop table if exists public.modernization_requests;
drop table if exists public.modernization_seq;

notify pgrst, 'reload schema';