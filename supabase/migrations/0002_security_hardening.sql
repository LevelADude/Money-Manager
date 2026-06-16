-- =====================================================================
-- Money-Manager · 0002_security_hardening.sql
-- =====================================================================
-- Behebt Hinweise des Supabase-Security-Advisors:
--   1) Trigger-Hilfsfunktion bekommt einen festen (immutable) search_path.
--   2) Trigger-Funktionen sollen NICHT über den öffentlichen REST-RPC-
--      Endpunkt aufrufbar sein. (Trigger feuern unabhängig von EXECUTE-Rechten,
--      daher bleibt das Verhalten der App unverändert.)
--
-- Hinweis: Die Policies `*_all` mit `using (true)` sind ABSICHTLICH so – das
-- ist das gewünschte Modell "vertrauenswürdige Gruppe, alle dürfen alles".
-- =====================================================================

alter function public.set_updated_at() set search_path = '';

revoke execute on function public.set_updated_at()  from public, anon, authenticated;
revoke execute on function public.handle_new_user() from public, anon, authenticated;
