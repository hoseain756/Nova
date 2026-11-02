import { createClient } from "https://esm.sh/@supabase/supabase-js@2.118.0";

const responseHeaders = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store",
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
};

const failure = () => new Response(
  JSON.stringify({ error: "Unable to sign in with those credentials." }),
  { status: 401, headers: responseHeaders },
);

function required(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing ${name}`);
  return value;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: responseHeaders });
  }
  if (request.method !== "POST") return failure();

  const started = Date.now();
  try {
    const body = await request.text();
    if (body.length > 8192) return failure();
    const parsed: unknown = JSON.parse(body);
    if (!parsed || typeof parsed !== "object") return failure();
    const input = parsed as Record<string, unknown>;
    if (typeof input.identifier !== "string" ||
      typeof input.password !== "string") return failure();
    const identifier = input.identifier.trim().toLowerCase();
    const password = input.password;
    if (identifier.length < 3 || identifier.length > 254 ||
      password.length === 0 || password.length > 1024) return failure();

    const url = required("SUPABASE_URL");
    const anonKey = required("SUPABASE_ANON_KEY");
    const serviceKey = required("SUPABASE_SERVICE_ROLE_KEY");
    const service = createClient(url, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    // The Supabase gateway must overwrite this header; do not accept a
    // caller-controlled IP header in a different deployment environment.
    const forwarded = request.headers.get("x-forwarded-for");
    if (!forwarded) {
      return new Response(JSON.stringify({ error: "Please try again later." }),
        { status: 503, headers: responseHeaders });
    }
    const address = forwarded.split(",")[0].trim();
    const keys = [
      [`ip:${address}`, 30],
      [`pair:${address}:${identifier}`, 8],
    ] as const;
    for (const [key, max] of keys) {
      const { data, error } = await service.rpc("consume_auth_login_attempt_secure", {
        p_scope: key,
        p_limit: max,
        p_window_seconds: 900,
      });
      if (error || data !== true) {
        return new Response(JSON.stringify({ error: "Please try again later." }),
          { status: 429, headers: responseHeaders });
      }
    }

    let email = identifier;
    if (!identifier.includes("@")) {
      if (!/^[a-z0-9_]{3,24}$/.test(identifier)) return failure();
      const { data, error } = await service.from("accounts")
        .select("id").eq("username", identifier).maybeSingle();
      if (error) return failure();
      if (data) {
        // Auth user emails are never exposed to the mobile client by this
        // lookup. The server uses them only for the password grant.
        const { data: userData, error: userError } =
          await service.auth.admin.getUserById(data.id);
        if (userError) return failure();
        email = userData.user?.email ?? "invalid-user@invalid.example";
      } else {
        email = "invalid-user@invalid.example";
      }
    }

    const auth = createClient(url, anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data, error } = await auth.auth.signInWithPassword({
      email, password,
    });
    // Coarsen timing for unknown usernames. Exact timing must be checked in
    // production against the chosen Auth email provider and gateway.
    const remaining = 400 - (Date.now() - started);
    if (remaining > 0) await new Promise((resolve) => setTimeout(resolve, remaining));
    if (error || !data.session) return failure();
    const session = data.session;
    return new Response(JSON.stringify({
      access_token: session.access_token,
      refresh_token: session.refresh_token,
      token_type: session.token_type,
      expires_in: session.expires_in,
      user: session.user,
    }), { status: 200, headers: responseHeaders });
  } catch {
    // Do not log credentials, identifiers, database errors, or raw requests.
    return failure();
  }
});
