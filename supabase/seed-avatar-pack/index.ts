// One-time deployment template. The deploy step substitutes the exact PNG
// bytes from assets/avatars into `avatars`, invokes once, then replaces this
// function with disabled.ts. Never leave this handler active after seeding.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.118.0";

const avatars: Record<string, string> = {};

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key || Object.keys(avatars).length !== 9) {
    return new Response("Seed unavailable", { status: 503 });
  }
  const client = createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  let uploaded = 0;
  let failed = 0;
  for (const [name, base64] of Object.entries(avatars)) {
    const bytes = Uint8Array.from(atob(base64), (c) => c.charCodeAt(0));
    const { error } = await client.storage.from("nova-profile-avatars")
      .upload(name, bytes, { contentType: "image/png", upsert: false });
    if (error) failed++; else uploaded++;
  }
  return new Response(JSON.stringify({ uploaded, failed }), {
    headers: { "content-type": "application/json", "cache-control": "no-store" },
  });
});
