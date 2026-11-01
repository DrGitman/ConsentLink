-- ConsentLink: let PowerSync read changes (P2, sync). Needs 20261016000001_init.sql.
-- PowerSync follows the `powersync` publication to send new rows to phones.
-- Which rows a phone gets is decided by supabase/powersync/sync-rules.yaml.
--
-- Safe to run on a project where PowerSync's guided Supabase setup already
-- made the publication (our live project): it never drops or narrows it, it
-- only adds any of our tables that are missing. Safe to run twice.
do $$
declare
  t text;
  synced text[] := array['institutions', 'profiles', 'studies', 'consent_sections',
                         'form_versions', 'participants', 'consents',
                         'consent_files', 'audit_log'];
begin
  if not exists (select 1 from pg_publication where pubname = 'powersync') then
    execute 'create publication powersync for table '
         || (select string_agg(format('public.%I', x), ', ') from unnest(synced) x);
  elsif not (select puballtables from pg_publication where pubname = 'powersync') then
    foreach t in array synced loop
      if not exists (select 1 from pg_publication_tables
                      where pubname = 'powersync' and schemaname = 'public' and tablename = t) then
        execute format('alter publication powersync add table public.%I', t);
      end if;
    end loop;
  end if;
end $$;
