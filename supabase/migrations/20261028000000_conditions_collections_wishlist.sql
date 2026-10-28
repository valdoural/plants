-- Условия растения, свои папки и список желаний.

alter table public.plants
  add column if not exists conditions jsonb not null default '{}',
  add column if not exists collection_ids jsonb not null default '[]';

create table public.collections (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  name text not null,
  created_at timestamptz not null default now()
);

create table public.wishlist (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  taxon_id int,
  scientific_name text not null,
  common_name text,
  photo_url text,
  created_at timestamptz not null default now()
);

create index on public.collections (user_id);
create index on public.wishlist (user_id, created_at desc);

do $$
declare t text;
begin
  foreach t in array array['collections', 'wishlist'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format(
      'create policy "own rows" on public.%I for all to authenticated
         using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()))', t);
  end loop;
end $$;
