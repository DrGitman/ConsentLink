-- Development seed: two institutions (task 2: "seed 2 institutions").
-- Researchers whose confirmed email ends in email_domain join that institution.
-- To test with another address, change the domain, e.g.:
--   update public.institutions set email_domain = 'gmail.com' where name = 'NUST';
-- and change it back before the demo.
insert into public.institutions (name, email_domain, colour_hex) values
  ('NUST', 'nust.na', '#0E3B2C'),
  ('UNAM', 'unam.na', '#1F4E9C')
on conflict (name) do nothing;
