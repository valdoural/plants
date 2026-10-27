-- Leafy: схема данных сада. Каждый пользователь видит только свои строки (RLS).
-- Вход анонимный: Authentication → Sign In / Providers → Allow anonymous sign-ins.

create table public.plants (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  nickname text not null,
  scientific_name text,
  common_name text,
  photo_url text,
  location text not null default 'indoor',
  species jsonb,
  created_at timestamptz not null default now()
);

create table public.care_tasks (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  plant_id uuid not null references public.plants on delete cascade,
  type text not null,
  interval_days int not null check (interval_days > 0),
  next_due timestamptz not null,
  last_done timestamptz,
  enabled boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.notes (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  plant_id uuid not null references public.plants on delete cascade,
  text text not null default '',
  photo_url text,
  created_at timestamptz not null default now()
);

create table public.identifications (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  provider text not null,
  photo_url text,
  candidates jsonb not null default '[]',
  created_at timestamptz not null default now()
);

create table public.diagnoses (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  plant_id uuid references public.plants on delete set null,
  photo_url text,
  result jsonb not null,
  created_at timestamptz not null default now()
);

create index on public.plants (user_id);
create index on public.care_tasks (user_id, next_due);
create index on public.notes (plant_id);
create index on public.identifications (user_id, created_at desc);
create index on public.diagnoses (user_id, created_at desc);

do $$
declare t text;
begin
  foreach t in array array['plants', 'care_tasks', 'notes', 'identifications', 'diagnoses'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format(
      'create policy "own rows" on public.%I for all to authenticated
         using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()))', t);
  end loop;
end $$;

-- Фото: публичное чтение по ссылке (пути случайные), запись — только в свою папку {user_id}/...
insert into storage.buckets (id, name, public) values ('photos', 'photos', true)
on conflict (id) do nothing;

create policy "upload own photos" on storage.objects for insert to authenticated
  with check (bucket_id = 'photos' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "delete own photos" on storage.objects for delete to authenticated
  using (bucket_id = 'photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
