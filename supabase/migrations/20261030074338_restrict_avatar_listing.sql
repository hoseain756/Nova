-- Public buckets serve known object URLs without a broad SELECT policy.
-- The pack uses fixed keys; clients never need to list all objects.
drop policy if exists nova_avatar_pack_read on storage.objects;
