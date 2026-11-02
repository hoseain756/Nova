// Manual production smoke. Creates TWO disposable anonymous Auth users.
// An operator must delete exactly the printed test user IDs after reviewing
// the result. Never print access/refresh tokens or PIN values.
if (process.env.NOVA_LIVE_SMOKE !== '1') {
  throw new Error('Set NOVA_LIVE_SMOKE=1 to acknowledge test-user creation.');
}
const base = process.env.NOVA_SUPABASE_URL;
const key = process.env.NOVA_SUPABASE_PUBLISHABLE_KEY;
if (!base || !key) throw new Error('Missing Supabase URL or publishable key.');

const ids = [];
const checks = {};
async function call(path, method, bearer, body) {
  const response = await fetch(`${base}${path}`, {
    method,
    headers: {
      apikey: key,
      Authorization: `Bearer ${bearer ?? key}`,
      ...(body === undefined ? {} : { 'Content-Type': 'application/json' }),
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  const raw = await response.text();
  let data;
  try { data = raw ? JSON.parse(raw) : null; } catch { data = null; }
  return { status: response.status, data };
}
function check(name, value) { checks[name] = Boolean(value); }
function code(reply) {
  return reply.data?.code ?? reply.data?.error_code ?? `HTTP_${reply.status}`;
}
try {
  const first = await call('/auth/v1/signup', 'POST', null, {});
  if (!first.data?.user?.id || !first.data?.access_token) {
    checks.guest_signup = `failed:${code(first)}`;
  } else {
    ids.push(first.data.user.id);
    check('guest_signup', first.status === 200 && first.data.user.is_anonymous === true);
    const a = first.data.access_token;
    const second = await call('/auth/v1/signup', 'POST', null, {});
    if (!second.data?.user?.id || !second.data?.access_token) {
      checks.second_guest_signup = `failed:${code(second)}`;
    } else {
      ids.push(second.data.user.id);
      check('second_guest_signup', second.status === 200 && second.data.user.is_anonymous === true);
      const b = second.data.access_token;
      const accountA = await call(`/rest/v1/accounts?select=id&id=eq.${ids[0]}`, 'GET', a);
      check('account_trigger', accountA.status === 200 && accountA.data?.length === 1);
      const create = (token, name, avatar) => call('/rest/v1/rpc/create_profile', 'POST', token, {
        p_name: name, p_avatar_kind: 'pack', p_avatar_value: avatar,
      });
      const pa = await create(a, 'NOVA smoke A', 'nova_avatar_01_smile');
      const pb = await create(b, 'NOVA smoke B', 'nova_avatar_02_surprised');
      const profileA = pa.data?.id;
      const profileB = pb.data?.id;
      check('profile_create', pa.status === 200 && pb.status === 200 && !!profileA && !!profileB);
      if (profileA && profileB) {
        const pinSet = await call('/rest/v1/rpc/set_profile_pin', 'POST', a, {
          p_profile_id: profileA, p_old_pin: null, p_new_pin: '739462',
        });
        const pinBad = await call('/rest/v1/rpc/verify_profile_pin', 'POST', a, {
          p_profile_id: profileA, p_pin: '000000',
        });
        const pinGood = await call('/rest/v1/rpc/verify_profile_pin', 'POST', a, {
          p_profile_id: profileA, p_pin: '739462',
        });
        const profileRead = await call(`/rest/v1/profiles?select=id,has_pin&id=eq.${profileA}`, 'GET', a);
        check('pin', pinSet.data === true && pinBad.data === false &&
          pinGood.data === true && profileRead.data?.[0]?.has_pin === true);

        const setDefault = await call('/rest/v1/rpc/set_default_profile', 'POST', a, {
          p_profile_id: profileA,
        });
        const defaultRead = await call(`/rest/v1/accounts?select=default_profile_id&id=eq.${ids[0]}`, 'GET', a);
        check('default_profile', setDefault.status < 300 &&
          defaultRead.data?.[0]?.default_profile_id === profileA);

        const saveA = await call('/rest/v1/rpc/save_profile_bucket', 'POST', a, {
          p_profile_id: profileA, p_bucket: 'watchlist',
          p_data: { watchlist: [{ id: 'nova-smoke-only' }] }, p_expected_rev: 0,
        });
        const saveAgain = await call('/rest/v1/rpc/save_profile_bucket', 'POST', a, {
          p_profile_id: profileA, p_bucket: 'watchlist',
          p_data: { watchlist: [] }, p_expected_rev: 0,
        });
        check('bucket_cas', saveA.status === 200 && saveA.data?.[0]?.rev === 1 &&
          saveAgain.status >= 400);

        const crossRead = await call(`/rest/v1/profiles?select=id&id=eq.${profileB}`, 'GET', a);
        const crossBucketRead = await call(`/rest/v1/profile_buckets?select=profile_id&profile_id=eq.${profileA}`, 'GET', b);
        const crossWrite = await call('/rest/v1/rpc/save_profile_bucket', 'POST', a, {
          p_profile_id: profileB, p_bucket: 'watchlist',
          p_data: { watchlist: [] }, p_expected_rev: 0,
        });
        const directWrite = await call('/rest/v1/profiles', 'POST', a, {
          account_id: ids[0], name: 'forged', avatar_kind: 'pack',
          avatar_value: 'nova_avatar_01_smile',
        });
        const anonRead = await call(`/rest/v1/profiles?select=id&id=eq.${profileA}`, 'GET', null);
        check('rls_cross_read', crossRead.status === 200 && crossRead.data?.length === 0 &&
          crossBucketRead.status === 200 && crossBucketRead.data?.length === 0);
        check('rls_cross_write', crossWrite.status >= 400 && directWrite.status >= 400 &&
          (anonRead.status >= 400 || anonRead.data?.length === 0));

        const lastDelete = await call('/rest/v1/rpc/delete_profile', 'POST', a, {
          p_profile_id: profileA,
        });
        check('last_profile_protected', lastDelete.status >= 400);

        for (let i = 2; i <= 5; i++) {
          const added = await create(a, `NOVA smoke ${i}`, 'nova_avatar_01_smile');
          check(`profile_${i}`, added.status === 200);
        }
        const sixth = await create(a, 'NOVA smoke 6', 'nova_avatar_01_smile');
        check('profile_limit', sixth.status >= 400);
      }
    }
  }
} catch (error) {
  checks.unexpected_failure = String(error?.name ?? 'error');
} finally {
  console.log(JSON.stringify({ test_user_ids: ids, checks }));
}
