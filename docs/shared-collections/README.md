# Shared collections

Shared collections are account-owned server data, separate from the existing
profile-scoped custom-list snapshot. The creator's Supabase Auth account ID is
the owner. Viewing profiles and profile PINs do not grant collection rights.
Anonymous Auth guests have account IDs and may participate; upgrading that
guest preserves membership, while losing its session can lose access to it.

## Data model

| Table | Purpose |
| --- | --- |
| `shared_collections` | Owner, trimmed name and description, optimistic `version`, timestamps. |
| `shared_collection_members` | One row per account and collection, role (`owner` or `member`) and six explicit permission flags. New members start with `view` and `add`. The owner row has every flag and cannot be edited or removed. |
| `shared_collection_items` | Media type (`series`, `anime`, `movie`), title, optional catalog ID and poster URL, contributor account ID and immutable server-set display-name snapshot, optimistic `version`, timestamps. |
| `app_private.shared_collection_invites` | Current 256-bit token and enabled state. The raw token is available only through an authorized invite RPC so the owner can view the link. |
| `shared_collection_sync` | One revision row per account. Only this small invalidation table is published to Realtime. |

All exposed tables have RLS. Authenticated clients receive SELECT only, scoped
to collections with `view` permission or their own sync row. They have no
direct table write grants. The private invite table has no client grants.

## API contract

The Flutter client invokes these authenticated PostgREST RPCs. Each write runs
in one database transaction, derives the actor from `auth.uid()`, checks the
current membership and permission on the server, then increments sync
revisions for affected accounts. A caller cannot submit an owner/contributor
ID in place of its own identity.

| Action | RPC and main inputs | Required right |
| --- | --- | --- |
| Create | `create_shared_collection(name, description)` | Auth account; creator becomes owner. |
| Edit/delete collection | `update_shared_collection(id, name, description, expected_version)`, `delete_shared_collection(id)` | Owner. |
| Read/rotate/disable invite | `read_shared_collection_invite(id)`, `rotate_shared_collection_invite(id)`, `disable_shared_collection_invite(id)` | `manage_invites`. |
| Join | `join_shared_collection(token)` | Valid, enabled current token and Auth account. |
| Read members | `shared_collection_member_details(id)` | `view`. Returns usernames only within that collection. |
| Change rights/remove member | `set_shared_collection_member_permissions(id, account_id, flags...)`, `remove_shared_collection_member(id, account_id)` | `manage_members`; never the owner or the actor's own flags. A delegated manager may grant only rights it holds. A member may leave by removing itself. |
| Add/edit/delete item | `add_shared_collection_item(id, type, title, media_id, poster_url)`, `update_shared_collection_item(item_id, expected_version, type, title, media_id, poster_url)`, `delete_shared_collection_item(item_id, expected_version)` | `add`, `edit`, or `delete` respectively. |

The generated REST endpoint for each RPC is `/rest/v1/rpc/<function_name>`.
Collection, item, and member reads use RLS-protected `/rest/v1/<table_name>`.
An edit or deletion with an old version fails with SQLSTATE `40001`; the client
reloads the current row and lets the user reconcile before another write.
Disabled, malformed, or rotated invites fail with `22023`. Names, titles,
media IDs, and URLs have server-side length and format checks; Flutter renders
them as text and never uses them as HTML.

## Realtime and invitation flow

`shared_collection_sync` is in the `supabase_realtime` publication. Each account
subscribes to its own row. A committed item, member, collection, or invite
change increments that row; the client refetches the RLS-scoped collection,
members, and items. This also covers deletions and removed members, whose old
collection rows are no longer visible under RLS. Reads after reconnect or
foreground resume recover missed events. Updates to a single item compare its
version under a row lock, so concurrent edits cannot silently overwrite one
another.

The owner shares `app.nova.mobile://collection-invite?token=<64 hex>`. Android
and iOS route the installed-app scheme to the link listener. The listener
keeps a pending token in platform secure storage through signup, login, and
profile selection, then calls the join RPC. The Library also accepts a pasted
link or token for messaging apps that do not open custom schemes. Rotating or
disabling a link invalidates the old token immediately. Removing a member
rotates an enabled token before commit so that member cannot rejoin with a
previously known link.

The owner panel reads members and the current invite, then calls the specific
permission, removal, invite, edit, or delete RPC. All controls reflect the
latest server response; hiding a control in Flutter is only a presentation
choice, never the authorization boundary.

## Deployment and acceptance

Apply `supabase/migrations/20261103203415_shared_collections.sql` and
`supabase/migrations/20261103203706_shared_collection_permission_transitions.sql`
before shipping the client to another project. Both were applied to the
connected NOVA project on 2026-11-03. Rollback-only SQL smoke tests exercised
the owner RPCs and two temporary Auth identities: create, join, add, revoke,
delegated permission edits, removal, invite invalidation, RLS isolation and a
stale item version. They left no collection or test-account rows. This is
database evidence, not a live multi-device test. Check the Supabase security
and performance advisors and the Data API grants after deployment. Repeat
with two real clients and concurrent writes, then on Android and iOS for
cold/warm links, signup continuation, background reconnect, and RTL layouts.

The custom-scheme link requires NOVA to be installed. A web landing page and
verified HTTPS App/Universal Link require a controlled domain and are not
configured here.
