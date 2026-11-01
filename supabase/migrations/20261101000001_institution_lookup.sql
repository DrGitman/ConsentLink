-- ConsentLink: which institution owns an email domain (P2, sign-in #78).
-- The sign-up screen asks before creating an account, so someone whose
-- domain has no institution is told plainly instead of getting an account
-- with no access. Returns only the institution's name, or null.
create or replace function public.institution_for_domain(p_domain text)
returns text
language sql stable security definer set search_path = public as $$
  select name from public.institutions where email_domain = lower(trim(p_domain))
$$;

revoke all on function public.institution_for_domain(text) from public;
grant execute on function public.institution_for_domain(text) to anon, authenticated;
