// Edge Function: admin-delete-user
// Löscht ein Auth-Konto. Nur für Admins (prüft profiles.is_admin des Aufrufers).
// Der service_role-Key bleibt serverseitig (nie in der App).
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  try {
    const jwt = (req.headers.get('Authorization') ?? '').replace('Bearer ', '');
    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const { data: caller, error: callerErr } = await admin.auth.getUser(jwt);
    if (callerErr || !caller?.user) return json({ error: 'Nicht angemeldet' }, 401);

    const { data: prof } = await admin
      .from('profiles')
      .select('is_admin')
      .eq('id', caller.user.id)
      .maybeSingle();
    if (!prof?.is_admin) return json({ error: 'Keine Admin-Rechte' }, 403);

    const { userId } = await req.json();
    if (!userId) return json({ error: 'userId fehlt' }, 400);
    if (userId === caller.user.id) {
      return json({ error: 'Eigenes Konto kann hier nicht gelöscht werden' }, 400);
    }

    // Der Besitzer ist geschützt und kann nicht gelöscht werden.
    const { data: target } = await admin
      .from('profiles')
      .select('is_owner')
      .eq('id', userId)
      .maybeSingle();
    if (target?.is_owner) {
      return json({ error: 'Der Besitzer kann nicht gelöscht werden' }, 400);
    }

    const { error: delErr } = await admin.auth.admin.deleteUser(userId);
    if (delErr) return json({ error: delErr.message }, 400);

    return json({ ok: true }, 200);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
