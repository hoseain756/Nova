// Live, opt-in smoke for Edge Function configuration. It creates one
// disposable anonymous user; remove the printed user ID from auth.users after
// checking the result. Never print bearer tokens, provider bodies, or secrets.
if (process.env.NOVA_LIVE_SMOKE !== '1') {
  throw new Error('Set NOVA_LIVE_SMOKE=1 to acknowledge test-user creation.');
}
const base = process.env.NOVA_SUPABASE_URL;
const key = process.env.NOVA_SUPABASE_PUBLISHABLE_KEY;
if (!base || !key) throw new Error('Missing public Supabase configuration.');

const signup = await fetch(`${base}/auth/v1/signup`, {
  method: 'POST',
  headers: { apikey: key, 'Content-Type': 'application/json' },
  body: '{}',
});
const guest = await signup.json();
if (!signup.ok || !guest.user?.id || !guest.access_token) {
  throw new Error(`Anonymous signup failed: HTTP_${signup.status}`);
}
const response = await fetch(`${base}/functions/v1/simkl-device-exchange`, {
  method: 'POST',
  headers: {
    apikey: key,
    Authorization: `Bearer ${guest.access_token}`,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({ device_code: 'nova_invalid_device_code_0123456789' }),
});
let result = {};
try { result = await response.json(); } catch { /* Keep output generic. */ }
console.log(JSON.stringify({
  disposable_user_id: guest.user.id,
  function_http_status: response.status,
  function_result: ['error', 'pending'].includes(result.status)
    ? result.status
    : 'unexpected',
}));
if (response.status !== 200 || !['error', 'pending'].includes(result.status)) {
  process.exitCode = 1;
}
