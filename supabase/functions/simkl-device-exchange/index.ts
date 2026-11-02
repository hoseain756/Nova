import { createClient } from "https://esm.sh/@supabase/supabase-js@2.118.0";

const headers = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store",
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
};

function json(status: number, body: Record<string, string>): Response {
  return new Response(JSON.stringify(body), { status, headers });
}

function required(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing ${name}`);
  return value;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers });
  }
  if (request.method !== "POST") return json(405, { status: "error" });
  const authorization = request.headers.get("authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) {
    return json(401, { status: "error" });
  }

  try {
    const body = await request.text();
    if (body.length > 2048) return json(400, { status: "error" });
    let input: unknown;
    try {
      input = JSON.parse(body);
    } catch {
      return json(400, { status: "error" });
    }
    if (!input || typeof input !== "object" ||
      !("device_code" in input) ||
      typeof input.device_code !== "string" ||
      !/^[\x21-\x7e]{8,512}$/.test(input.device_code)) {
      return json(400, { status: "error" });
    }

    const url = required("SUPABASE_URL");
    const anonKey = required("SUPABASE_ANON_KEY");
    const serviceKey = required("SUPABASE_SERVICE_ROLE_KEY");
    const simklId = required("SIMKL_CLIENT_ID");
    const simklSecret = required("SIMKL_CLIENT_SECRET");
    const identity = createClient(url, anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const token = authorization.slice(7);
    const { data: userData, error: userError } =
      await identity.auth.getUser(token);
    if (userError || !userData.user) return json(401, { status: "error" });

    const service = createClient(url, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: canPoll, error: limitError } = await service.rpc(
      "consume_simkl_poll_secure",
      { p_scope: `simkl:${userData.user.id}`, p_min_seconds: 5 },
    );
    if (limitError) return json(503, { status: "error" });
    if (canPoll !== true) return json(200, { status: "pending" });

    let provider: Response;
    try {
      provider = await fetch("https://api.simkl.com/oauth2/token", {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "simkl-api-key": simklId,
        },
        body: JSON.stringify({
          client_id: simklId,
          client_secret: simklSecret,
          device_code: input.device_code,
          grant_type: "urn:ietf:params:oauth:grant-type:device_code",
        }),
        signal: AbortSignal.timeout(12000),
      });
    } catch {
      return json(200, { status: "pending", reason: "transient_network" });
    }

    if (provider.status === 408 || provider.status === 425 ||
      provider.status >= 500) {
      return json(200, { status: "pending", reason: "transient_network" });
    }
    const providerText = await provider.text();
    if (providerText.length > 32768) return json(200, { status: "error" });
    let parsed: Record<string, unknown> = {};
    try { parsed = JSON.parse(providerText); } catch { /* Terminal provider reply. */ }
    const accessToken = parsed.access_token;
    if (provider.ok && typeof accessToken === "string" &&
      accessToken.length > 0) {
      return json(200, { status: "success", access_token: accessToken });
    }
    const code = String(parsed.error ?? "");
    if (code.includes("pending") || code.includes("slow_down") ||
      provider.status === 429) {
      return json(200, { status: "pending" });
    }
    return json(200, { status: "error" });
  } catch {
    // No token, device code, provider body, or raw error is logged or exposed.
    return json(503, { status: "error" });
  }
});
