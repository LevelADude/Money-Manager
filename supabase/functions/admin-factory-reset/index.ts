// Edge Function: admin-factory-reset
// Setzt das Projekt auf WERKSEINSTELLUNGEN zurück: alle Daten, ALLE Profile,
// die Whitelist UND alle Login-Konten (auth.users) werden gelöscht. Danach ist
// die Datenbank im Neuzustand – die nächste Registrierung wird neuer Besitzer.
// Nur für den BESITZER (prüft profiles.is_owner des Aufrufers).
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
      .select('is_owner')
      .eq('id', caller.user.id)
      .maybeSingle();
    if (!prof?.is_owner) {
      return json({ error: 'Nur der Besitzer darf zurücksetzen' }, 403);
    }

    // 1) Belege im Storage entfernen.
    await admin.storage.emptyBucket('receipts');

    // 2) Alle Tabellen leeren (inkl. Profile + Whitelist). TRUNCATE umgeht den
    //    Besitzer-Schutz-Trigger, daher wird auch das Besitzer-Profil entfernt.
    const { error: rpcErr } = await admin.rpc('admin_factory_reset');
    if (rpcErr) return json({ error: rpcErr.message }, 400);

    // 3) Alle Login-Konten löschen (zuletzt – inkl. des Aufrufers, der dadurch
    //    ausgeloggt wird). Profile sind bereits leer → kein Cascade/Trigger.
    const all: { id: string }[] = [];
    for (let page = 1; ; page++) {
      const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 1000 });
      if (error) return json({ error: error.message }, 400);
      const users = data?.users ?? [];
      all.push(...users);
      if (users.length < 1000) break;
    }
    for (const u of all) {
      await admin.auth.admin.deleteUser(u.id);
    }

    return json({ ok: true, deletedUsers: all.length }, 200);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
