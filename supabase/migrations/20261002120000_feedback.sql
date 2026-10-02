-- Shake-to-report: bug reports and feature requests from the app.
-- Users can send their own reports and nothing else; reading them is for
-- the dashboard / service role only. Rows and screenshots go with the
-- account (delete-account removes auth.users, which cascades here).

create table public.feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  kind text not null check (kind in ('bug', 'idea')),
  message text not null check (char_length(message) between 1 and 4000),
  screen_name text,
  screenshot_path text,
  app_version text not null,
  build_version text,
  platform text not null,
  os_version text,
  device_manufacturer text,
  device_model text,
  locale text
);

create index feedback_created_idx on public.feedback (created_at desc);

alter table public.feedback enable row level security;

create policy "feedback_insert_own"
  on public.feedback
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

-- Screenshots: a private bucket, one folder per user, upload only.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('feedback-screenshots', 'feedback-screenshots', false, 3145728, array['image/png'])
on conflict (id) do nothing;

create policy "feedback_screenshots_insert_own"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'feedback-screenshots'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
