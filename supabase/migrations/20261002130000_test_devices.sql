-- Google Play's pre-launch report crawls every testing-track upload on
-- ~10 Firebase Test Lab phones, each signed into a Google account, and the
-- crawler signs in with Google. The app now marks those accounts (it reads
-- the `firebase.test.lab` system flag), so they can be counted out.

alter table public.profiles
  add column if not exists is_test_device boolean not null default false;

-- Real people only: the number to watch instead of the Auth user count.
create or replace view public.real_users
with (security_invoker = true) as
select p.*
from public.profiles p
where not p.is_test_device;

revoke all on public.real_users from anon, authenticated;
