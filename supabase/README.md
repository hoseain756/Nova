# NOVA account backend

The account migration and Edge Functions have been deployed to the current
NOVA Supabase project. The shared-collection schema and permission-transition
follow-up were deployed on 2026-11-03. New account/profile and shared-collection
tables are RLS-protected. This does
not establish end-to-end readiness: physical client flows remain pending.
Anonymous Auth sign-ins, manual identity linking, email confirmation, and the
two mobile redirect URLs are enabled. The Simkl Edge secrets were entered by
the project owner; a disposable guest call to `simkl-device-exchange` returned
the expected terminal response for an invalid device code on 2026-11-02.
The owner reported rotating the Simkl secret before saving it. Actual approved
device-code exchange still needs an in-app check. The isolated guest/RLS/profile
API smoke passed on 2026-10-30 and its two disposable Auth users were removed.
On 2026-11-02, `auth-login` returned the same generic 401 status and body for
unknown email and username inputs; this is not a timing or known-user test.
The Android Release APK built successfully on 2026-11-02; no physical-device
auth/profile flow has been verified. The old device sync path remains active
until cutover.

Watch Party's two migrations (`20261111091937_watch_parties.sql` and
`20261111092449_watch_party_access_guards.sql`) were deployed on 2026-11-11.
The public `nova_party` invoker delegates to checked private functions; room,
member, chat and rate-limit tables have no client grants and explicit deny RLS.
Realtime topics are private and receive only server-authored messages. The
rollback SQL smoke passed, including authenticated-role API calls and denial
of direct table reads, anonymous RPC calls and forged broadcast inserts. Its
disposable Auth/profile fixtures were rolled back. A public probe verified
WebSocket connectivity; authenticated private-channel and physical-device
playback acceptance remain separate. See `../docs/watch-party/README.md`.

## Release order

1. Remove the legacy direct-Postgres path from the new client. At the later
   approved cutover, revoke its embedded `noor_app` password and close the two
   legacy tables. Old client versions may lose cloud sync after revocation;
   coordinate the cutover and retain recoverable backups.
2. `migrations/20261030072943_accounts_profiles.sql` and
   `migrations/20261030073653_private_rate_limit_key.sql` are applied to the
   intended project. The first creates account shells for existing Auth users;
   the second stores a generated rate-limit key in the private database schema.
3. Supabase Auth has email confirmation, anonymous sign-ins, manual linking,
   and exact mobile redirect URLs enabled. The Email provider now requires at
   least 12 password characters including letters and digits, matching the
   client forms. Review Auth rate limits and configure CAPTCHA/Turnstile before
   public release.
4. Deploy `auth-login` with JWT verification disabled. The rate-limit HMAC key
   is generated and held inside `app_private.rate_limit_hmac_key`; no Edge
   secret needs to be copied for it. The Edge function's service role key is
   read only in the function runtime. Confirm the gateway
   overwrites `x-forwarded-for`; if it does not, configure a trusted network
   identity source before accepting logins. The function fails closed if the
   header is absent.
   The owner rotated the previously exposed Simkl secret and saved
   `SIMKL_CLIENT_ID` and `SIMKL_CLIENT_SECRET` as server-only Edge secrets.
   `simkl-device-exchange` is deployed with JWT verification enabled. The mobile
   app retains only Simkl's public client ID and stores the returned user access
   token in platform secure storage.
5. The nine supplied avatar PNGs were seeded once to `nova-profile-avatars`
   under their stable pack keys. The temporary `seed-avatar-pack` Edge Function
   was replaced with an inert JWT-gated handler. All nine Storage objects have
   source-matching byte sizes, and a public URL returned 200. Public URLs are
   intentional; bucket listing and mobile uploads remain disabled.
6. Deploy the Flutter client only after the policies and login function pass
   staging tests. Avoid logging request bodies or raw Auth/PostgREST errors.
7. After the new client and import path pass production acceptance, use the
   reviewed `cutover/close_legacy_sync.sql` to close the old device-ID tables.
   It is deliberately excluded from automatic migrations and must not run
   while old clients still need that path. It leaves rows intact for recovery.

## Mobile API contract

- `auth-login` POST: `{ "identifier": "email-or-username", "password": "..." }`.
  Success returns `access_token`, `refresh_token`, `token_type`, `expires_in`,
  and `user`; every credential failure is generic. The client must store tokens
  in platform secure storage and use them with Supabase Auth.
- `simkl-device-exchange` authenticated POST: `{ "device_code": "..." }`.
  It returns `{"status":"success","access_token":"..."}` on approval,
  `{"status":"pending"}` for pending/slow-down replies, or
  `{"status":"pending","reason":"transient_network"}` for temporary
  errors; a terminal provider reply returns `{"status":"error"}`. The
  function rate-limits polling by authenticated account ID. The client must
  keep the returned access token in secure storage, not sync buckets.
- `accounts` and `profiles`: read with ordinary authenticated selects, limited
  by RLS. `profiles.has_pin` is a nonsecret boolean. Write account/profile
  metadata only through `set_username`, `create_profile`, `update_profile`,
  `delete_profile`, `set_default_profile`, and `set_profile_pin` RPCs. Profile
  creation takes `p_name`, `p_avatar_kind`, `p_avatar_value`, optional `p_pin`
  and optional `p_set_default`. The PIN and default flag are committed with
  creation or the whole operation rolls back. Updating prepends `p_profile_id`.
  Profile PIN RPCs use `p_profile_id`, `p_old_pin`, `p_new_pin`
  (or `p_pin` for verification). PINs are exactly six digits. Failed PIN
  changes return `false` so attempt counters remain committed.
- `account_buckets`: SELECT by `(account_id,bucket)`; only `settings` and
  `addons`. `profile_buckets`: SELECT by `(profile_id,bucket)`; only `lists`,
  `watchlist`, `history`, and `library`. `save_account_bucket` takes `p_bucket`,
  `p_data`, `p_expected_rev`; `save_profile_bucket` also takes `p_profile_id`.
  Both return a one-row `(rev,updated_at)` result. Pass 0 for an absent bucket;
  SQLSTATE `40001` means reload/merge/retry instead of overwriting.
- Shared collections use separate account-owned tables and authenticated RPCs,
  not `profile_buckets.lists`. Deploy
  `migrations/20261103203415_shared_collections.sql` and
  `migrations/20261103203706_shared_collection_permission_transitions.sql`
  before shipping the Flutter client to another project. The owner controls metadata; per-member flags govern view,
  item writes, member management, and invites. New members receive view/add.
  Item and collection edits require the current row version and return SQLSTATE
  `40001` on a stale version. The current invite token is private and rotating
  or disabling it invalidates old links. Only the per-account sync revision
  table enters Realtime; clients refetch under RLS after a signal. See
  `../docs/shared-collections/README.md` for the complete schema/RPC contract.

## Required security checks

- As user A and user B, query every table by A and B IDs. Each receives only
  its own rows. Attempt writes with forged owner IDs and direct table writes;
  all must fail. Repeat with an anonymous Auth user, which has the same
  `authenticated` database role.
- Race six `create_profile` calls for one account; at most five succeed. Race
  deletion of the last two profiles; at least one survives. Verify the default
  belongs to the account and is cleared when deleted.
- Verify a profile PIN rejects non-six-digit values, blocks after five failed
  attempts for 15 minutes, never appears in SELECT results, and cannot be
  modified without the old PIN. Treat it as an app gate, not a separate
  authorization principal: an account session can read its profiles.
- Sign in by known/unknown username and email with wrong passwords. Compare
  body, status, and timing; no account lookup or username-to-email response
  may be exposed. Check rate limits, provider error mapping, and no credential
  logging. Remove expired `app_private.auth_login_limits` rows periodically
  with a server-owned job; prune stale `app_private.simkl_poll_limits` rows as
  well. Do not expose either table to clients.
- Exercise Simkl device polling with a valid anonymous/full Auth session, an
  expired/missing JWT, pending authorization, approval, slow-down, provider
  timeout, and invalid device code. Verify the secret is absent from Flutter
  artifacts and that no endpoint or log echoes it.
- For shared collections, verify two accounts can create, invite, join, and
  contribute; direct table writes and nonmember reads fail; delegated grants
  never modify the owner or escalate rights; a removed member loses RLS access
  and receives an invalidation; a rotated/disabled token fails to join; and
  competing edits produce one `40001` conflict. Repeat with an anonymous Auth
  guest and across two connected clients.

The manual live smoke harness is `tests/manual_live_guest_smoke.mjs`. It is
guarded by `NOVA_LIVE_SMOKE=1`, prints only test user IDs and check results,
and requires an operator to delete only those IDs afterward. The 2026-10-30
run passed guest sign-in, account provisioning, profile/PIN/default operations,
bucket revision conflict, cross-user RLS denial, last-profile protection, and
the five-profile limit. Its two test users and cascaded rows were verified
absent after cleanup. A public avatar URL returned 200; publishable-key bucket
listing returned zero rows, as intended.

`migrations/20261030080505_atomic_profile_create.sql` replaces the original
profile creation RPC with optional PIN and default selection in one database
transaction. The `tests/manual_atomic_profile_smoke.mjs` live run on
2026-10-30 verified that invalid PIN and avatar inputs leave no new profile,
while a valid six-digit PIN, verifier, `has_pin`, and default profile commit
together. Its disposable guest user and cascaded rows were removed afterward.
- Run Supabase security/performance advisors and verify all newly exposed
  tables and functions have the intended grants as well as RLS policies.

The shared-collection migrations were applied to the connected project on
2026-11-03. Structural queries confirmed RLS on all four public tables,
authenticated SELECT without direct writes, no anonymous RPC execution, and
Realtime publication of only `shared_collection_sync`. Rollback-only SQL smoke
tests covered owner operations and two temporary Auth identities across join,
contribution, revocation, delegated rights, removal, invite invalidation, RLS,
and stale-version rejection. Live client, Realtime delivery, and device link
behavior remain unverified.
