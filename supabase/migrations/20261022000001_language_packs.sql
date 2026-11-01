-- ConsentLink: language packs (P2).
-- A language pack form is the consent form translated into one language,
-- section by section, exactly as in forms/consent-form.<iso639_3>.json and
-- read by app/lib/ai/language/translated_form_parser.dart.
--
-- Rule this file enforces on the server (same as review_status.dart):
--   only sections marked reviewed or verified_official, checked by a
--   first-language or fluent reviewer, may ever reach a participant.
-- Researchers can see every pack (they need drafts to review them). Field
-- capture reads ONLY public.participant_language_packs, which leaves out
-- unchecked sections and packs whose required sections aren't all checked.

create table public.language_packs (
  id             uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions (id),
  form_id        text not null,            -- "id" in the file, e.g. consent-master-v1
  language       text not null references public.languages (code),
  version        text not null,            -- "version" in the file, e.g. 0.1.0
  content        jsonb not null,           -- the whole file, as uploaded
  ready          boolean not null default false,  -- set by the server, see below
  uploaded_by    uuid references public.profiles (id),
  created_at     timestamptz not null default now(),
  unique (institution_id, form_id, language, version)
);
create index on public.language_packs (language);

-- A pack is never edited in place: a new translation or review = a new version.
create function public.language_packs_immutable() returns trigger language plpgsql as $$
begin
  raise exception 'a language pack cannot be changed; upload a new version';
end $$;
create trigger language_packs_no_update before update on public.language_packs
  for each row execute function public.language_packs_immutable();

-- The reviewer that counts for a section: its own, else the form's.
-- Shells carry a reviewer whose fields are all null; that counts as none.
create function public.pack_reviewer(section jsonb, form jsonb) returns jsonb
language sql immutable as $$
  select r from (values (section -> 'reviewer'), (form -> 'reviewer')) v(r)
   where jsonb_typeof(r) = 'object'
     and exists (select 1 from jsonb_each(r) e where e.value <> 'null'::jsonb)
   limit 1
$$;

create function public.language_packs_before_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_iso     text := new.content ->> 'iso639_3';
  v_section jsonb;
  v_status  text;
  v_rev     jsonb;
  v_any     boolean := false;
  v_ready   boolean := true;
begin
  new.institution_id := public.current_institution();
  new.uploaded_by    := auth.uid();
  if new.institution_id is null then raise exception 'not signed in to an institution'; end if;

  -- The file's own fields must agree with the row.
  if new.content ->> 'id' is distinct from new.form_id
     or new.content ->> 'version' is distinct from new.version then
    raise exception 'form_id and version must match the file';
  end if;
  if v_iso is not null and not exists
       (select 1 from languages where code = new.language and iso639_3 = v_iso) then
    raise exception 'file iso639_3 "%" is not language "%"', v_iso, new.language;
  end if;

  -- An untranslated shell has "sections": {} (never ready).
  if jsonb_typeof(new.content -> 'sections') = 'object'
     and new.content -> 'sections' = '{}'::jsonb then
    new.ready := false;
    return new;
  end if;
  if jsonb_typeof(new.content -> 'sections') <> 'array' then
    raise exception '"sections" must be a list';
  end if;

  for v_section in select * from jsonb_array_elements(new.content -> 'sections') loop
    v_any := true;
    v_status := v_section ->> 'status';
    if v_status is null or v_status not in
       ('machine_draft', 'needs_review', 'reviewed', 'verified_official') then
      raise exception 'section "%": unknown status "%"', v_section ->> 'key', v_status;
    end if;
    if coalesce(btrim(v_section ->> 'key'), '') = ''
       or coalesce(btrim(v_section ->> 'text'), '') = ''
       or jsonb_typeof(v_section -> 'required') <> 'boolean' then
      raise exception 'every section needs key, text and required';
    end if;
    -- A checked section needs a named first-language or fluent reviewer.
    if v_status in ('reviewed', 'verified_official') then
      v_rev := public.pack_reviewer(v_section, new.content);
      if v_rev is null
         or coalesce(btrim(v_rev ->> 'name'), '') = ''
         or coalesce(v_rev ->> 'fluency', '') not in ('first_language', 'fluent') then
        raise exception 'section "%" is marked % but has no first-language or fluent reviewer',
          v_section ->> 'key', v_status;
      end if;
    elsif (v_section ->> 'required')::boolean then
      v_ready := false;   -- a required section is still unchecked
    end if;
  end loop;

  new.ready := v_any and v_ready;
  return new;
end $$;
create trigger language_packs_check before insert on public.language_packs
  for each row execute function public.language_packs_before_insert();

-- What field capture may download: ready packs only, checked sections only.
create view public.participant_language_packs
with (security_invoker = true) as
select p.id, p.form_id, p.language, p.version, p.created_at,
       jsonb_set(p.content, '{sections}',
         coalesce((select jsonb_agg(s order by ord)
                     from jsonb_array_elements(p.content -> 'sections') with ordinality t(s, ord)
                    where s ->> 'status' in ('reviewed', 'verified_official')),
                  '[]'::jsonb)) as content
  from public.language_packs p
 where p.ready;

alter table public.language_packs enable row level security;
create policy language_packs_read on public.language_packs for select to authenticated
  using (institution_id = public.current_institution());
create policy language_packs_insert on public.language_packs for insert to authenticated
  with check (institution_id = public.current_institution());

revoke all on public.language_packs, public.participant_language_packs from anon, authenticated;
grant select, insert on public.language_packs to authenticated;
grant select on public.participant_language_packs to authenticated;
