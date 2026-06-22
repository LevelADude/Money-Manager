// Edge Function: archive-proxy
// Proxy für die Jahres-Archivierung nach GitHub. Ver-/entschlüsselt die
// Jahresdateien (AES-GCM) und spricht die GitHub Contents API.
//
// Repo-URL, GitHub-Token UND Verschlüsselungs-Schlüssel werden NICHT als
// Function-Secrets gehalten, sondern aus der Tabelle `archive_config` gelesen
// (serverseitig, via service_role). So richtet jeder Fork-Betreiber sein Repo
// direkt in der App ein, ohne dass das Token je in den (öffentlichen) Client
// gelangt.
//
// Aktionen (POST-Body { action, year?, payload? }):
//   write  { year, payload } -> verschlüsselt payload, PUT archive/<year>.json.enc
//   read   { year }          -> GET + entschlüsseln, liefert payload zurück
//   list                     -> listet archivierte Jahre (Name/Größe/sha)
//   delete { year }          -> löscht archive/<year>.json.enc
//
// Rechte: write/delete nur Admin; read/list für alle Angemeldeten (damit
// archivierte Jahre für alle einsehbar bleiben).
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import {
  decodeBase64,
  encodeBase64,
} from 'https://deno.land/std@0.224.0/encoding/base64.ts';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });
}

const DIR = 'archive';

// --- Verschlüsselung (AES-256-GCM) -----------------------------------
async function importKey(encKeyB64: string): Promise<CryptoKey> {
  const raw = decodeBase64(encKeyB64);
  if (raw.length !== 32) {
    throw new Error('Verschlüsselungs-Schlüssel muss Base64 von 32 Byte sein.');
  }
  return crypto.subtle.importKey('raw', raw, { name: 'AES-GCM' }, false, [
    'encrypt',
    'decrypt',
  ]);
}

/// Datei-Inhalt (String), der auf GitHub landet: JSON-Umschlag mit IV + CT.
async function encryptPayload(key: CryptoKey, payload: unknown): Promise<string> {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const pt = new TextEncoder().encode(JSON.stringify(payload));
  const ct = new Uint8Array(
    await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, key, pt),
  );
  return JSON.stringify({
    alg: 'AES-256-GCM',
    iv: encodeBase64(iv),
    ct: encodeBase64(ct),
  });
}

async function decryptPayload(key: CryptoKey, fileContent: string): Promise<unknown> {
  const env = JSON.parse(fileContent) as { iv: string; ct: string };
  const iv = decodeBase64(env.iv);
  const ct = decodeBase64(env.ct);
  const pt = new Uint8Array(
    await crypto.subtle.decrypt({ name: 'AES-GCM', iv }, key, ct),
  );
  return JSON.parse(new TextDecoder().decode(pt));
}

// --- GitHub Contents API ---------------------------------------------
function ghHeaders(token: string, extra: Record<string, string> = {}): HeadersInit {
  return {
    Authorization: `Bearer ${token}`,
    Accept: 'application/vnd.github+json',
    'User-Agent': 'money-manager-archive',
    'X-GitHub-Api-Version': '2022-11-28',
    ...extra,
  };
}

function filePath(year: number): string {
  return `${DIR}/${year}.json.enc`;
}

function contentsUrl(repo: string, path: string): string {
  return `https://api.github.com/repos/${repo}/contents/${path}`;
}

/// Verzeichnis-Listing von archive/ (Metadaten, unabhängig von Dateigröße).
async function listDir(
  repo: string,
  token: string,
): Promise<Array<{ name: string; size: number; sha: string }>> {
  const res = await fetch(contentsUrl(repo, DIR), { headers: ghHeaders(token) });
  if (res.status === 404) return [];
  if (!res.ok) throw new Error(`GitHub-List fehlgeschlagen (${res.status}): ${await res.text()}`);
  const arr = (await res.json()) as Array<{ name: string; size: number; sha: string; type: string }>;
  return arr.filter((e) => e.type === 'file').map((e) => ({ name: e.name, size: e.size, sha: e.sha }));
}

async function shaFor(repo: string, token: string, year: number): Promise<string | null> {
  const entries = await listDir(repo, token);
  return entries.find((e) => e.name === `${year}.json.enc`)?.sha ?? null;
}

// --- Hauptlogik ------------------------------------------------------
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

    const body = (await req.json().catch(() => ({}))) as {
      action?: string;
      year?: number;
      payload?: unknown;
    };
    const { action, year } = body;

    // write/delete nur für Admins.
    if (action === 'write' || action === 'delete') {
      const { data: prof } = await admin
        .from('profiles')
        .select('is_admin')
        .eq('id', caller.user.id)
        .maybeSingle();
      if (!prof?.is_admin) return json({ error: 'Keine Admin-Rechte' }, 403);
    }

    // Archiv-Repo-Konfiguration serverseitig laden.
    const { data: cfg } = await admin
      .from('archive_config')
      .select('github_repo, github_token, enc_key')
      .eq('id', 1)
      .maybeSingle();
    const repo = (cfg?.github_repo ?? '').trim();
    const token = cfg?.github_token ?? '';
    const encKeyB64 = cfg?.enc_key ?? '';
    if (!repo || !token || !encKeyB64) {
      return json({ error: 'Kein Archiv-Repo eingerichtet.' }, 400);
    }

    switch (action) {
      case 'list': {
        const entries = await listDir(repo, token);
        const years = entries
          .map((e) => {
            const m = e.name.match(/^(\d{4})\.json\.enc$/);
            return m ? { year: Number(m[1]), size: e.size, sha: e.sha } : null;
          })
          .filter((x): x is { year: number; size: number; sha: string } => x !== null)
          .sort((a, b) => a.year - b.year);
        return json({ ok: true, years }, 200);
      }

      case 'write': {
        if (typeof year !== 'number') return json({ error: 'year fehlt' }, 400);
        const key = await importKey(encKeyB64);
        const fileContent = await encryptPayload(key, body.payload ?? {});
        const sha = await shaFor(repo, token, year);
        const res = await fetch(contentsUrl(repo, filePath(year)), {
          method: 'PUT',
          headers: ghHeaders(token, { 'Content-Type': 'application/json' }),
          body: JSON.stringify({
            message: `Archiviere Jahr ${year} (Money-Manager)`,
            content: encodeBase64(new TextEncoder().encode(fileContent)),
            ...(sha ? { sha } : {}),
          }),
        });
        if (!res.ok) {
          return json({ error: `GitHub-Write fehlgeschlagen (${res.status}): ${await res.text()}` }, 502);
        }
        const out = (await res.json()) as { content?: { sha?: string; size?: number; path?: string } };
        return json(
          {
            ok: true,
            path: out.content?.path ?? filePath(year),
            sha: out.content?.sha ?? null,
            size: out.content?.size ?? fileContent.length,
          },
          200,
        );
      }

      case 'read': {
        if (typeof year !== 'number') return json({ error: 'year fehlt' }, 400);
        // Raw-Media-Type liefert den vollen Inhalt (bis 100 MB), umgeht das
        // 1-MB-Limit der JSON-Darstellung der Contents API.
        const res = await fetch(contentsUrl(repo, filePath(year)), {
          headers: ghHeaders(token, { Accept: 'application/vnd.github.raw' }),
        });
        if (res.status === 404) return json({ error: `Jahr ${year} ist nicht archiviert.` }, 404);
        if (!res.ok) {
          return json({ error: `GitHub-Read fehlgeschlagen (${res.status}): ${await res.text()}` }, 502);
        }
        const key = await importKey(encKeyB64);
        const data = await decryptPayload(key, await res.text());
        return json({ ok: true, data }, 200);
      }

      case 'delete': {
        if (typeof year !== 'number') return json({ error: 'year fehlt' }, 400);
        const sha = await shaFor(repo, token, year);
        if (!sha) return json({ ok: true, alreadyGone: true }, 200);
        const res = await fetch(contentsUrl(repo, filePath(year)), {
          method: 'DELETE',
          headers: ghHeaders(token, { 'Content-Type': 'application/json' }),
          body: JSON.stringify({ message: `Entferne Archiv Jahr ${year} (Money-Manager)`, sha }),
        });
        if (!res.ok) {
          return json({ error: `GitHub-Delete fehlgeschlagen (${res.status}): ${await res.text()}` }, 502);
        }
        return json({ ok: true }, 200);
      }

      default:
        return json({ error: `Unbekannte Aktion: ${action}` }, 400);
    }
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
