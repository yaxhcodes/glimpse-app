create extension if not exists pgcrypto with schema extensions;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  last_seen timestamptz,
  display_name text,
  platform text not null,
  app_version text not null,
  build_version text,
  country text,
  timezone text,
  onboarding_completed boolean not null default false
);

create table public.subscriptions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  revenuecat_customer_id text not null,
  plan text not null default 'free' check (plan in ('free', 'premium')),
  updated_at timestamptz not null default now()
);

create table public.analytics_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  session_id uuid not null,
  event_name text not null,
  screen_name text,
  created_at timestamptz not null default now(),
  app_version text not null,
  build_version text,
  platform text not null,
  os_version text,
  device_manufacturer text,
  device_model text
);

create index analytics_events_user_created_idx
  on public.analytics_events (user_id, created_at desc);

create index analytics_events_session_idx
  on public.analytics_events (session_id);

create index analytics_events_event_created_idx
  on public.analytics_events (event_name, created_at desc);

alter table public.profiles enable row level security;
alter table public.subscriptions enable row level security;
alter table public.analytics_events enable row level security;

create policy "profiles_select_own"
  on public.profiles
  for select
  to authenticated
  using ((select auth.uid()) = id);

create policy "profiles_insert_own"
  on public.profiles
  for insert
  to authenticated
  with check ((select auth.uid()) = id);

create policy "profiles_update_own"
  on public.profiles
  for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

create policy "subscriptions_select_own"
  on public.subscriptions
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "subscriptions_insert_own"
  on public.subscriptions
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "subscriptions_update_own"
  on public.subscriptions
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "analytics_events_insert_own"
  on public.analytics_events
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

grant select, insert, update on public.profiles to authenticated;
grant select, insert, update on public.subscriptions to authenticated;
grant insert on public.analytics_events to authenticated;
