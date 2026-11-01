-- ConsentLink: storage for signature, thumbprint, witness and audio files
-- (P2, #80). Needs 20261016000001_init.sql.
-- One private bucket. Files sit under <study_id>/<consent_id>/<file>, and
-- only researchers of the institution that owns the study can upload or
-- read them, so each institution sees only its own files. There is no update
-- or delete policy: a stored file is never replaced. consent_files records
-- each file with its SHA-256.
insert into storage.buckets (id, name, public, file_size_limit)
values ('consent-files', 'consent-files', false, 26214400)  -- 25 MB
on conflict (id) do nothing;

create function public.owns_study_folder(p_name text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.studies s
     where s.id::text = (storage.foldername(p_name))[1]
       and s.institution_id = public.current_institution())
$$;
revoke all on function public.owns_study_folder(text) from public;
grant execute on function public.owns_study_folder(text) to authenticated;

create policy consent_files_upload on storage.objects for insert to authenticated
  with check (bucket_id = 'consent-files' and public.owns_study_folder(name));
create policy consent_files_read on storage.objects for select to authenticated
  using (bucket_id = 'consent-files' and public.owns_study_folder(name));
