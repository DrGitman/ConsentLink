-- ConsentLink: let PowerSync read changes (P2, sync). Needs 20261016000001_init.sql.
-- PowerSync follows this publication to send new rows to phones. Which rows a
-- phone gets is decided by supabase/powersync/sync-rules.yaml, not here.
-- The PowerSync database user is created by hand, with a password that is
-- never committed (see supabase/powersync/README.md).
create publication powersync for table
  public.institutions,
  public.profiles,
  public.studies,
  public.consent_sections,
  public.form_versions,
  public.participants,
  public.consents,
  public.consent_files,
  public.audit_log;
