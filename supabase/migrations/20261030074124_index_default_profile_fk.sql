-- Cover the composite FK check when a profile is deleted or reassigned.
create index accounts_default_profile_fk_idx
  on public.accounts(id, default_profile_id)
  where default_profile_id is not null;
