-- ConsentLink: share link / QR code consent (P1, 03.4 "Share link / QR code").
-- Needs 20261016000001_init.sql.
--
-- A researcher shares a link (or its QR code) for a study with a published
-- form. The participant opens it on their own phone (participant_web/),
-- reads the published form in a language it has in full, chooses, and signs
-- with a finger. Nothing else is reachable with the link: the two functions
-- below are the only way in for anon, and both check the token every time.
--
-- Rules:
--   * only a published, open study without minors (minors need a guardian and
--     the child's own assent in person, 10.x screens);
--   * links expire (30 days by default, 90 at most) and can be turned off;
--   * every link has a use limit;
--   * the consent goes through the normal consents checks (published form
--     version and fingerprint), and the audit trail records it as done by the
--     researcher who shared the link.

create table public.consent_links (
  id             uuid primary key default gen_random_uuid(),
  token          text not null unique default encode(extensions.gen_random_bytes(18), 'hex'),
  study_id       uuid not null references public.studies (id),
  institution_id uuid not null references public.institutions (id),
  created_by     uuid not null references public.profiles (id),
  expires_at     timestamptz not null default now() + interval '30 days',
  max_uses       integer not null default 200 check (max_uses between 1 and 1000),
  uses           integer not null default 0,
  revoked_at     timestamptz,
  created_at     timestamptz not null default now()
);
create index on public.consent_links (study_id);

create function public.consent_links_before_insert() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.created_by := auth.uid();
  if new.created_by is null then raise exception 'not signed in'; end if;
  select institution_id into new.institution_id from public.studies
   where id = new.study_id
     and institution_id = public.current_institution()
     and status <> 'closed'
     and not involves_minors;
  if new.institution_id is null then
    raise exception 'links are only for open studies of your institution without minors';
  end if;
  if not exists (select 1 from public.form_versions where study_id = new.study_id) then
    raise exception 'publish the consent form before sharing a link';
  end if;
  new.uses := 0;
  new.revoked_at := null;
  new.expires_at := least(coalesce(new.expires_at, now() + interval '30 days'),
                          now() + interval '90 days');
  return new;
end $$;
create trigger consent_links_fill before insert on public.consent_links
  for each row execute function public.consent_links_before_insert();

-- Signatures drawn on the participant's own phone. Kept in the database (no
-- storage upload from anon); readable only by the institution. id is the
-- consent's id. PNG as base64 text, because PowerSync syncs text: the study
-- owner's phone gets it (sync-rules.yaml) and puts it in the consent PDF.
create table public.link_signatures (
  id             uuid primary key references public.consents (id),
  study_id       uuid not null references public.studies (id),
  institution_id uuid not null references public.institutions (id),
  png_base64     text not null,
  sha256         text not null check (sha256 ~ '^[0-9a-f]{64}$'),
  created_at     timestamptz not null default now()
);
create index on public.link_signatures (study_id);

alter table public.consent_links   enable row level security;
alter table public.link_signatures enable row level security;
create policy consent_links_read on public.consent_links for select to authenticated
  using (institution_id = public.current_institution());
create policy consent_links_insert on public.consent_links for insert to authenticated
  with check (institution_id = public.current_institution());
create policy consent_links_revoke on public.consent_links for update to authenticated
  using (institution_id = public.current_institution());
create policy link_signatures_read on public.link_signatures for select to authenticated
  using (institution_id = public.current_institution());

revoke all on public.consent_links, public.link_signatures from anon, authenticated;
grant select, insert on public.consent_links to authenticated;
grant update (revoked_at) on public.consent_links to authenticated;
grant select on public.link_signatures to authenticated;

create function public._link_problem(v_link public.consent_links) returns text
language plpgsql stable security definer set search_path = public as $$
declare v_study public.studies;
begin
  if v_link.id is null or v_link.revoked_at is not null or v_link.expires_at < now() then
    return 'This link has expired or was turned off. Ask the researcher for a new one.';
  end if;
  if v_link.uses >= v_link.max_uses then
    return 'This link has been used as many times as allowed. Ask the researcher for a new one.';
  end if;
  select * into v_study from public.studies where id = v_link.study_id;
  if v_study.status = 'closed' then return 'This study is closed.'; end if;
  if v_study.involves_minors then
    return 'This study includes people under 18, so consent is taken in person.';
  end if;
  return null;
end $$;
revoke all on function public._link_problem(public.consent_links) from public;

-- What the participant page shows: the newest published form, approved
-- sections only.
create function public.link_form(p_token text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_link    public.consent_links;
  v_problem text;
  v_study   public.studies;
  v_form    public.form_versions;
begin
  select * into v_link from public.consent_links where token = p_token;
  v_problem := public._link_problem(v_link);
  if v_problem is not null then
    return jsonb_build_object('ok', false, 'reason', v_problem);
  end if;
  select * into v_study from public.studies where id = v_link.study_id;
  select * into v_form from public.form_versions
   where study_id = v_study.id order by version desc limit 1;
  return jsonb_build_object(
    'ok', true,
    'title', v_study.title,
    'form_version', v_form.version,
    'expires_at', v_link.expires_at,
    'sections', coalesce((
      select jsonb_agg(jsonb_build_object(
               'language', s ->> 'language',
               'order', (s ->> 'order')::int,
               'element', s ->> 'required_element',
               'text', s ->> 'text')
             order by s ->> 'language', (s ->> 'order')::int)
        from jsonb_array_elements(v_form.sections) s
       where s ->> 'status' = 'approved'), '[]'::jsonb));
end $$;

-- Records the participant's decision. p_signature is a base64 PNG, needed
-- for a Yes.
create function public.link_submit(
  p_token text,
  p_language text,
  p_decision text,
  p_signature text default null,
  p_signed_at timestamptz default null
) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_link        public.consent_links;
  v_problem     text;
  v_study       public.studies;
  v_form        public.form_versions;
  v_participant uuid;
  v_consent     uuid;
  v_png         bytea;
begin
  select * into v_link from public.consent_links where token = p_token for update;
  v_problem := public._link_problem(v_link);
  if v_problem is not null then
    return jsonb_build_object('ok', false, 'reason', v_problem);
  end if;
  if p_decision is null or p_decision not in ('yes', 'no') then
    return jsonb_build_object('ok', false, 'reason', 'Choose yes or no.');
  end if;
  select * into v_study from public.studies where id = v_link.study_id;
  select * into v_form from public.form_versions
   where study_id = v_study.id order by version desc limit 1;
  if not exists (select 1 from jsonb_array_elements(v_form.sections) s
                  where s ->> 'language' = p_language) then
    return jsonb_build_object('ok', false, 'reason', 'That language is not in this form.');
  end if;
  if p_decision = 'yes' then
    begin
      v_png := decode(coalesce(p_signature, ''), 'base64');
    exception when others then
      v_png := null;
    end;
    if v_png is null or length(v_png) < 100
       or substring(v_png from 1 for 8) <> '\x89504e470d0a1a0a'::bytea then
      return jsonb_build_object('ok', false, 'reason', 'Please sign with your finger first.');
    end if;
    if length(v_png) > 1048576 then
      return jsonb_build_object('ok', false, 'reason', 'The signature is too large. Clear it and sign again.');
    end if;
  end if;

  -- The researcher who shared the link is the actor in the audit trail
  -- (audit_before_insert reads auth.uid()). Local to this transaction.
  perform set_config('request.jwt.claim.sub', v_link.created_by::text, true);
  perform set_config('request.jwt.claims',
    jsonb_build_object('sub', v_link.created_by, 'role', 'authenticated')::text, true);

  insert into public.participants (study_id, language, is_minor)
  values (v_study.id, p_language, false)
  returning id into v_participant;
  insert into public.consents (study_id, participant_id, language, decision, method,
                               form_version, form_hash, signed_at)
  values (v_study.id, v_participant, p_language, p_decision, 'signature',
          v_form.version, v_form.form_hash,
          least(coalesce(p_signed_at, now()), now()))
  returning id into v_consent;
  if v_png is not null then
    insert into public.link_signatures (id, study_id, institution_id, png_base64, sha256)
    values (v_consent, v_study.id, v_study.institution_id,
            replace(encode(v_png, 'base64'), E'\n', ''),
            encode(extensions.digest(v_png, 'sha256'), 'hex'));
  end if;
  update public.consent_links set uses = uses + 1 where id = v_link.id;
  return jsonb_build_object(
    'ok', true,
    'reference', upper(substring(replace(v_consent::text, '-', '') for 8)));
end $$;

revoke all on function public.link_form(text) from public;
revoke all on function public.link_submit(text, text, text, text, timestamptz) from public;
grant execute on function public.link_form(text) to anon, authenticated;
grant execute on function public.link_submit(text, text, text, text, timestamptz) to anon, authenticated;
