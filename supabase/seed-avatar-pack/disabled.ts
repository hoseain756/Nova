// The one-time seed endpoint is deliberately inert after upload verification.
Deno.serve(() => new Response("Gone", { status: 410 }));
