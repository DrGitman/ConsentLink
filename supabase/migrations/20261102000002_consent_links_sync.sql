-- ConsentLink: share links, follow-up to 20261102000001_consent_links.sql.
-- Safe to run whichever version of that file was applied first.
--
-- 1. link_signatures keeps the PNG as base64 text with the consent id as
--    its id, so PowerSync can sync it to the study owner's phone
--    (sync-rules.yaml) and the consent PDF shows the signature.
-- 2. link_form also returns the institution's name and colour, for the
--    participant page header (Figma 14.2 to 14.6).

do $$
begin
  if exists (select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'link_signatures'
                and column_name = 'consent_id') then
    alter table public.link_signatures rename column consent_id to id;
  end if;
  if exists (select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'link_signatures'
                and column_name = 'png') then
    alter table public.link_signatures add column if not exists png_base64 text;
    update public.link_signatures
       set png_base64 = replace(encode(png, 'base64'), E'\n', '')
     where png_base64 is null;
    alter table public.link_signatures alter column png_base64 set not null;
    alter table public.link_signatures drop column png;
  end if;
end $$;
create index if not exists link_signatures_study_id_idx on public.link_signatures (study_id);

create or replace function public.link_form(p_token text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_link    public.consent_links;
  v_problem text;
  v_study   public.studies;
  v_form    public.form_versions;
  v_inst    public.institutions;
begin
  select * into v_link from public.consent_links where token = p_token;
  v_problem := public._link_problem(v_link);
  if v_problem is not null then
    return jsonb_build_object('ok', false, 'reason', v_problem);
  end if;
  select * into v_study from public.studies where id = v_link.study_id;
  select * into v_inst from public.institutions where id = v_study.institution_id;
  select * into v_form from public.form_versions
   where study_id = v_study.id order by version desc limit 1;
  return jsonb_build_object(
    'ok', true,
    'title', v_study.title,
    'institution', v_inst.name,
    'colour', v_inst.colour_hex,
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

create or replace function public.link_submit(
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
