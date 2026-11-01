-- ConsentLink: initial schema (P2, task 2).
-- Run once on a new Supabase project (SQL Editor), then run seed.sql.
-- Conventions match app/lib/contracts and /schemas: snake_case columns,
-- UUID ids made on the device, device time vs server time (received_at).

create extension if not exists pgcrypto with schema extensions;

-- ============================================================
-- Reference data
-- ============================================================

-- Allowed language values. We store the CODE, never the display name,
-- so spelling (Juǀ'hoansi with U+01C0) only lives in the UI.
-- Codes are BCP 47: ISO 639-1 when one exists, else ISO 639-3.
-- Must match app/lib/contracts/languages.dart. Adding a language = one INSERT.
-- Codes are plain a-z so sorting is identical here (collate "C") and in Dart
-- (compareTo), which keeps compute_form_hash in step with form_hash.dart.
-- iso639_3 is the code language packs use (forms/consent-form.<code>.json has
-- an "iso639_3" field). It differs from code only where a 2-letter code exists
-- (hz/her, en/eng, ...). Packs keep their ISO 639-3 code; we map it here.
create table public.languages (
  code     text primary key check (code ~ '^[a-z]{2,3}$'),
  iso639_3 text not null unique check (iso639_3 ~ '^[a-z]{3}$'),
  name     text not null
);

insert into public.languages (code, iso639_3, name) values
  ('en',  'eng', 'English'),
  ('af',  'afr', 'Afrikaans'),
  ('de',  'deu', 'Deutsch'),
  ('hz',  'her', 'Otjiherero'),
  ('naq', 'naq', 'Khoekhoegowab'),
  ('ktz', 'ktz', 'Juǀ''hoansi'),   -- U+01C0, not ASCII
  ('kwn', 'kwn', 'Rukwangali'),
  ('loz', 'loz', 'Silozi'),
  ('ng',  'ndo', 'Oshindonga'),    -- Oshiwambo, Ndonga standard
  ('kj',  'kua', 'Oshikwanyama');  -- Oshiwambo, Kwanyama standard

create table public.institutions (
  id           uuid primary key default gen_random_uuid(),
  name         text not null unique,
  email_domain text unique,            -- researchers whose email ends in this join the institution
  colour_hex   text,
  logo_url     text,
  template_url text,
  created_at   timestamptz not null default now()
);

create table public.profiles (          -- = "Researcher" in the contracts
  id             uuid primary key references auth.users (id) on delete cascade,
  institution_id uuid not null references public.institutions (id),
  name           text,
  email          text not null,
  role           text not null default 'researcher' check (role in ('researcher', 'admin')),
  created_at     timestamptz not null default now()
);

-- ============================================================
-- Helper functions
-- ============================================================

create function public.current_institution() returns uuid
language sql stable security definer set search_path = public as $$
  select institution_id from public.profiles where id = auth.uid()
$$;

create function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select role = 'admin' from public.profiles where id = auth.uid()), false)
$$;

revoke all on function public.current_institution() from public;
revoke all on function public.is_admin() from public;
grant execute on function public.current_institution() to authenticated;
grant execute on function public.is_admin() to authenticated;

-- A new account joins the institution that owns its (confirmed) email domain.
-- No matching domain = no profile = no access to anything.
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_inst uuid;
begin
  select id into v_inst from public.institutions
   where email_domain = lower(split_part(new.email, '@', 2));
  if v_inst is not null then
    insert into public.profiles (id, institution_id, email, name)
    values (new.id, v_inst, new.email,
            coalesce(new.raw_user_meta_data ->> 'name', split_part(new.email, '@', 1)));
  end if;
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Same rule as app/lib/contracts/form_hash.dart: approved sections only,
-- sorted by language then order, "<id>\n<text>" joined with "\n---\n", SHA-256 hex.
create function public.compute_form_hash(sections jsonb) returns text
language sql immutable security definer set search_path = public as $$
  select encode(
    extensions.digest(
      coalesce(string_agg((s ->> 'id') || E'\n' || (s ->> 'text'), E'\n---\n'
                          order by (s ->> 'language') collate "C", (s ->> 'order')::int), ''),
      'sha256'),
    'hex')
  from jsonb_array_elements(sections) s
  where s ->> 'status' = 'approved'
$$;

-- ============================================================
-- Core tables
-- ============================================================

create table public.studies (
  id              uuid primary key default gen_random_uuid(),
  institution_id  uuid not null references public.institutions (id),
  researcher_id   uuid not null references public.profiles (id),
  title           text not null,
  involves_minors boolean not null default false,
  status          text not null default 'draft' check (status in ('draft', 'approved', 'active', 'closed')),
  form_version    integer not null default 0,   -- 0 = nothing published yet
  form_hash       text,
  created_at      timestamptz not null default now()
);

create table public.consent_sections (
  id               uuid primary key default gen_random_uuid(),
  study_id         uuid not null references public.studies (id),
  institution_id   uuid not null references public.institutions (id),
  "order"          integer not null check ("order" >= 0),
  language         text not null references public.languages (code),
  text             text not null,
  source_page      integer,
  source_quote     text,
  changes          jsonb not null default '[]'::jsonb,
  confidence       text check (confidence in ('low', 'medium', 'high')),
  required_element text,
  status           text not null default 'draft' check (status in ('draft', 'edited', 'approved')),
  approved_by      uuid references public.profiles (id),
  approved_at      timestamptz,
  created_at       timestamptz not null default now(),
  check ((status = 'approved') = (approved_by is not null and approved_at is not null))
);

-- Frozen snapshot of a published form. Consents point at (study, version, hash).
create table public.form_versions (
  id             uuid primary key default gen_random_uuid(),
  study_id       uuid not null references public.studies (id),
  institution_id uuid not null references public.institutions (id),
  version        integer not null check (version >= 1),
  form_hash      text not null,
  sections       jsonb not null,
  published_by   uuid references public.profiles (id),
  published_at   timestamptz not null default now(),
  unique (study_id, version)
);

create table public.participants (
  id             uuid primary key default gen_random_uuid(),
  study_id       uuid not null references public.studies (id),
  institution_id uuid not null references public.institutions (id),
  language       text not null references public.languages (code),
  is_minor       boolean not null,
  created_at     timestamptz not null default now()
);

create table public.consents (
  id               uuid primary key default gen_random_uuid(),
  study_id         uuid not null references public.studies (id),
  institution_id   uuid not null references public.institutions (id),
  participant_id   uuid not null references public.participants (id),
  language         text not null references public.languages (code),
  decision         text not null check (decision in ('yes', 'no')),
  method           text not null check (method in ('signature', 'thumbprint', 'verbal')),
  witness_name     text,
  interpreter_name text,
  guardian_consent boolean,
  child_assent     boolean,
  form_version     integer not null,
  form_hash        text not null,
  signed_at        timestamptz not null,                -- device time
  received_at      timestamptz not null default now(),  -- server time
  withdrawn_at     timestamptz,
  withdrawal_reason text
);

create table public.consent_files (
  id             uuid primary key default gen_random_uuid(),
  consent_id     uuid not null references public.consents (id),
  study_id       uuid not null references public.studies (id),
  institution_id uuid not null references public.institutions (id),
  kind           text not null check (kind in ('signature', 'thumbprint', 'witness', 'audio')),
  storage_path   text not null,
  sha256         text not null check (sha256 ~ '^[0-9a-f]{64}$'),
  created_at     timestamptz not null default now()
);

create table public.audit_log (
  id             uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions (id),
  study_id       uuid not null references public.studies (id),
  actor_id       uuid not null references public.profiles (id),
  action         text not null check (action in
                   ('study_created', 'section_approved', 'form_published',
                    'consent_signed', 'consent_exported', 'consent_withdrawn')),
  entity_id      uuid not null,
  created_at     timestamptz not null default now(),   -- when it happened (device time if known)
  received_at    timestamptz not null default now()    -- server time
);

create index on public.consent_sections (study_id);
create index on public.consents (study_id);
create index on public.audit_log (study_id);
create index on public.participants (study_id);

-- ============================================================
-- Triggers: the server does not trust what the app sends
-- ============================================================

-- institution_id on child rows always comes from the study, never the app.
create function public.set_institution_from_study() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  select institution_id into new.institution_id from public.studies where id = new.study_id;
  if new.institution_id is null then
    raise exception 'unknown study';
  end if;
  return new;
end $$;

create trigger set_institution before insert on public.consent_sections for each row execute function public.set_institution_from_study();
create trigger set_institution before insert on public.form_versions    for each row execute function public.set_institution_from_study();
create trigger set_institution before insert on public.participants     for each row execute function public.set_institution_from_study();
create trigger set_institution before insert on public.consents         for each row execute function public.set_institution_from_study();
create trigger set_institution before insert on public.consent_files    for each row execute function public.set_institution_from_study();
create trigger set_institution before insert on public.audit_log        for each row execute function public.set_institution_from_study();

-- Audit writer used by the triggers below (runs with full rights, so the app
-- never has to, and cannot, write these entries itself).
create function public.write_audit(p_action text, p_entity uuid, p_study uuid, p_at timestamptz)
returns void language plpgsql security definer set search_path = public as $$
begin
  insert into public.audit_log (study_id, action, entity_id, created_at)
  values (p_study, p_action, p_entity, coalesce(p_at, now()));
end $$;
revoke all on function public.write_audit(text, uuid, uuid, timestamptz) from public;

-- audit_log: actor comes from the login, time of arrival from the server.
create function public.audit_before_insert() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.actor_id := auth.uid();
  if new.actor_id is null then raise exception 'not signed in'; end if;
  new.received_at := now();
  return new;
end $$;
create trigger audit_fill before insert on public.audit_log
  for each row execute function public.audit_before_insert();

-- audit_log is append-only for everyone, including admins and service_role.
create function public.audit_immutable() returns trigger language plpgsql as $$
begin
  raise exception 'audit_log is append-only';
end $$;
create trigger audit_no_update before update or delete on public.audit_log
  for each row execute function public.audit_immutable();
create trigger audit_no_truncate before truncate on public.audit_log
  for each statement execute function public.audit_immutable();

-- studies
create function public.studies_before_insert() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.institution_id := public.current_institution();
  new.researcher_id  := auth.uid();
  new.form_version   := 0;
  new.form_hash      := null;
  return new;
end $$;
create trigger studies_fill before insert on public.studies
  for each row execute function public.studies_before_insert();

create function public.studies_after_insert() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform public.write_audit('study_created', new.id, new.id, new.created_at);
  return new;
end $$;
create trigger studies_audit after insert on public.studies
  for each row execute function public.studies_after_insert();

-- consent_sections: editing approved text drops the approval; approval is
-- stamped with the logged-in researcher.
create function public.sections_before_write() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'UPDATE' and old.status = 'approved' and new.text is distinct from old.text then
    new.status := 'edited';
  end if;
  if new.status = 'approved' then
    if tg_op = 'INSERT' or old.status <> 'approved' then
      new.approved_by := auth.uid();
      new.approved_at := coalesce(new.approved_at, now());
    else
      new.approved_by := old.approved_by;
      new.approved_at := old.approved_at;
    end if;
  else
    new.approved_by := null;
    new.approved_at := null;
  end if;
  return new;
end $$;
create trigger sections_fill before insert or update on public.consent_sections
  for each row execute function public.sections_before_write();

create function public.sections_after_write() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'approved' and (tg_op = 'INSERT' or old.status <> 'approved') then
    perform public.write_audit('section_approved', new.id, new.study_id, new.approved_at);
  end if;
  return new;
end $$;
create trigger sections_audit after insert or update on public.consent_sections
  for each row execute function public.sections_after_write();

-- form_versions: the server recomputes the fingerprint and checks the version number.
create function public.form_versions_before_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_current integer;
begin
  select form_version into v_current from public.studies where id = new.study_id;
  if new.version <> v_current + 1 then
    raise exception 'form version must be %', v_current + 1;
  end if;
  if new.form_hash <> public.compute_form_hash(new.sections) then
    raise exception 'form_hash does not match the sections';
  end if;
  if jsonb_array_length(new.sections) = 0
     or exists (select 1 from jsonb_array_elements(new.sections) s where s ->> 'status' <> 'approved') then
    raise exception 'every section must be approved before publishing';
  end if;
  new.published_by := auth.uid();
  return new;
end $$;
create trigger form_versions_check before insert on public.form_versions
  for each row execute function public.form_versions_before_insert();

create function public.form_versions_after_insert() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update public.studies set form_version = new.version, form_hash = new.form_hash
   where id = new.study_id;
  perform public.write_audit('form_published', new.id, new.study_id, new.published_at);
  return new;
end $$;
create trigger form_versions_apply after insert on public.form_versions
  for each row execute function public.form_versions_after_insert();

-- consents: must match a published form; minors need guardian consent AND
-- the child's own assent for a Yes (a child's No always wins); no un-withdrawing.
create function public.consents_before_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_minor boolean;
begin
  if not exists (select 1 from public.form_versions
                  where study_id = new.study_id
                    and version = new.form_version
                    and form_hash = new.form_hash) then
    raise exception 'consent does not match a published form version';
  end if;
  select is_minor into v_minor from public.participants
   where id = new.participant_id and study_id = new.study_id;
  if not found then
    raise exception 'unknown participant for this study';
  end if;
  if v_minor then
    if new.guardian_consent is null or new.child_assent is null then
      raise exception 'a minor needs guardian_consent and child_assent recorded';
    end if;
    if new.decision = 'yes' and not (new.guardian_consent and new.child_assent) then
      raise exception 'a Yes for a minor needs guardian consent and the child''s own assent';
    end if;
  end if;
  new.received_at := now();
  return new;
end $$;
create trigger consents_check before insert on public.consents
  for each row execute function public.consents_before_insert();

create function public.consents_before_update() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if old.withdrawn_at is not null and new.withdrawn_at is distinct from old.withdrawn_at then
    raise exception 'a withdrawal cannot be changed or undone';
  end if;
  return new;
end $$;
create trigger consents_withdraw_check before update on public.consents
  for each row execute function public.consents_before_update();

create function public.consents_after_write() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    perform public.write_audit('consent_signed', new.id, new.study_id, new.signed_at);
  elsif old.withdrawn_at is null and new.withdrawn_at is not null then
    perform public.write_audit('consent_withdrawn', new.id, new.study_id, new.withdrawn_at);
  end if;
  return new;
end $$;
create trigger consents_audit after insert or update on public.consents
  for each row execute function public.consents_after_write();

-- ============================================================
-- Row-level security: each institution sees only its own data
-- ============================================================

alter table public.languages        enable row level security;
alter table public.institutions     enable row level security;
alter table public.profiles         enable row level security;
alter table public.studies          enable row level security;
alter table public.consent_sections enable row level security;
alter table public.form_versions    enable row level security;
alter table public.participants     enable row level security;
alter table public.consents         enable row level security;
alter table public.consent_files    enable row level security;
alter table public.audit_log        enable row level security;

create policy languages_read on public.languages for select to anon, authenticated using (true);

create policy institutions_read on public.institutions for select to authenticated
  using (id = public.current_institution());
create policy institutions_admin_update on public.institutions for update to authenticated
  using (id = public.current_institution() and public.is_admin())
  with check (id = public.current_institution() and public.is_admin());

create policy profiles_read on public.profiles for select to authenticated
  using (institution_id = public.current_institution());
create policy profiles_update_self on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

create policy studies_read   on public.studies for select to authenticated using (institution_id = public.current_institution());
create policy studies_insert on public.studies for insert to authenticated with check (institution_id = public.current_institution());
create policy studies_update on public.studies for update to authenticated
  using (institution_id = public.current_institution()) with check (institution_id = public.current_institution());

do $$
declare t text;
begin
  foreach t in array array['consent_sections', 'form_versions', 'participants', 'consents', 'consent_files', 'audit_log']
  loop
    execute format('create policy %I on public.%I for select to authenticated using (institution_id = public.current_institution())', t || '_read', t);
  end loop;
  foreach t in array array['consent_sections', 'form_versions', 'participants', 'consents', 'consent_files']
  loop
    execute format('create policy %I on public.%I for insert to authenticated with check (institution_id = public.current_institution())', t || '_insert', t);
  end loop;
end $$;

-- The app may only record exports itself. Everything else in the audit log is
-- written by the triggers above.
create policy audit_log_insert_export on public.audit_log for insert to authenticated
  with check (institution_id = public.current_institution() and action = 'consent_exported');

create policy consent_sections_update on public.consent_sections for update to authenticated
  using (institution_id = public.current_institution()) with check (institution_id = public.current_institution());
create policy consents_withdraw on public.consents for update to authenticated
  using (institution_id = public.current_institution()) with check (institution_id = public.current_institution());

-- ============================================================
-- Privileges: start from nothing, grant only what is needed
-- ============================================================

revoke all on all tables in schema public from anon, authenticated;

grant select on public.languages to anon, authenticated;
grant select on public.institutions, public.profiles, public.studies, public.consent_sections,
                public.form_versions, public.participants, public.consents,
                public.consent_files, public.audit_log to authenticated;
grant insert on public.studies, public.consent_sections, public.form_versions, public.participants,
                public.consents, public.consent_files, public.audit_log to authenticated;

-- Columns the app may change after creation. Everything else is fixed or server-set.
grant update (name, colour_hex, logo_url, template_url) on public.institutions to authenticated;
grant update (name) on public.profiles to authenticated;
grant update (title, involves_minors, status) on public.studies to authenticated;
grant update (text, status, "order", changes, confidence, required_element, source_page, source_quote, approved_at)
  on public.consent_sections to authenticated;
grant update (withdrawn_at, withdrawal_reason) on public.consents to authenticated;
