// Manual live test: creates one disposable anonymous Auth user. Delete exactly
// the printed ID after review. No token or PIN is written to output.
if (process.env.NOVA_LIVE_SMOKE !== '1') throw new Error('Set NOVA_LIVE_SMOKE=1.');
const base = process.env.NOVA_SUPABASE_URL;
const key = process.env.NOVA_SUPABASE_PUBLISHABLE_KEY;
if (!base || !key) throw new Error('Missing public project configuration.');
let testUserId = null;
const checks = {};
async function request(path, method, token, body) {
  const response = await fetch(`${base}${path}`, {
    method,
    headers: {
      apikey: key,
      Authorization: `Bearer ${token ?? key}`,
      ...(body === undefined ? {} : { 'Content-Type': 'application/json' }),
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  const raw = await response.text();
  let data;
  try { data = raw ? JSON.parse(raw) : null; } catch { data = null; }
  return { status: response.status, data };
}
try {
  const guest = await request('/auth/v1/signup', 'POST', null, {});
  if (!guest.data?.user?.id || !guest.data?.access_token) {
    checks.signup = false;
  } else {
    testUserId = guest.data.user.id;
    checks.signup = guest.data.user.is_anonymous === true;
    const token = guest.data.access_token;
    const common = {
      p_name: 'NOVA atomic smoke', p_avatar_kind: 'pack',
      p_avatar_value: 'nova_avatar_01_smile', p_set_default: true,
    };
    const invalid = await request('/rest/v1/rpc/create_profile', 'POST', token,
      { ...common, p_pin: '123' });
    const afterInvalid = await request('/rest/v1/profiles?select=id', 'GET', token);
    checks.invalid_pin_rolls_back = invalid.status >= 400 &&
      afterInvalid.status === 200 && afterInvalid.data?.length === 0;

    const valid = await request('/rest/v1/rpc/create_profile', 'POST', token,
      { ...common, p_pin: '739462' });
    const id = valid.data?.id;
    const account = await request('/rest/v1/accounts?select=default_profile_id', 'GET', token);
    const verifier = id
      ? await request('/rest/v1/rpc/verify_profile_pin', 'POST', token,
        { p_profile_id: id, p_pin: '739462' })
      : null;
    checks.atomic_pin_and_default = valid.status === 200 && !!id &&
      valid.data.has_pin === true &&
      account.data?.[0]?.default_profile_id === id && verifier?.data === true;

    const invalidAvatar = await request('/rest/v1/rpc/create_profile', 'POST', token,
      { ...common, p_name: 'bad avatar', p_avatar_value: 'not_a_pack_key', p_pin: null });
    const afterAvatar = await request('/rest/v1/profiles?select=id', 'GET', token);
    const afterAccount = await request('/rest/v1/accounts?select=default_profile_id', 'GET', token);
    checks.bad_avatar_rolls_back = invalidAvatar.status >= 400 &&
      afterAvatar.data?.length === 1 &&
      afterAccount.data?.[0]?.default_profile_id === id;
  }
} catch (error) {
  checks.unexpected_failure = String(error?.name ?? 'error');
} finally {
  console.log(JSON.stringify({ test_user_id: testUserId, checks }));
}
