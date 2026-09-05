
-- FOOD & FUN VOUCHER WALLET
-- Supabase database schema + security + real-time
-- Run this whole script in Supabase SQL Editor.

create extension if not exists pgcrypto;

create table if not exists public.wallets (
  id uuid primary key default gen_random_uuid(),
  join_code text unique not null,
  name text not null default 'Our Monthly Voucher Wallet',
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.wallet_members (
  wallet_id uuid not null references public.wallets(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  display_name text not null default '',
  joined_at timestamptz not null default now(),
  primary key(wallet_id,user_id)
);

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  wallet_id uuid not null references public.wallets(id) on delete cascade,
  name text not null,
  icon text not null default '✨',
  limit_count integer not null default 0 check(limit_count >= 0),
  active boolean not null default true,
  sort_order integer not null default 0
);

create unique index if not exists categories_wallet_name_uidx
on public.categories(wallet_id, lower(name));

create table if not exists public.activities (
  id uuid primary key default gen_random_uuid(),
  wallet_id uuid not null references public.wallets(id) on delete cascade,
  date date not null,
  category_id uuid not null references public.categories(id) on delete restrict,
  place text not null default '',
  amount numeric(12,2) not null default 0 check(amount >= 0),
  rating integer check(rating between 1 and 10),
  worth_it text not null default '' check(worth_it in ('','Yes','No')),
  suggested_by text not null default '' check(suggested_by in ('','Me','Partner','Both','Spontaneous')),
  mood text not null default '',
  remarks text not null default '',
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists activities_wallet_date_idx
on public.activities(wallet_id,date desc);

create index if not exists activities_wallet_category_date_idx
on public.activities(wallet_id,category_id,date);

-- ---------- membership helper ----------
create or replace function public.is_wallet_member(p_wallet_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(
    select 1 from public.wallet_members
    where wallet_id=p_wallet_id and user_id=auth.uid()
  );
$$;

grant execute on function public.is_wallet_member(uuid) to authenticated;

-- ---------- create shared wallet ----------
create or replace function public.create_shared_wallet(
  p_name text default 'Our Monthly Voucher Wallet',
  p_display_name text default ''
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_wallet uuid;
  v_code text;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  loop
    v_code := upper(substr(encode(gen_random_bytes(5),'hex'),1,8));
    exit when not exists(select 1 from public.wallets where join_code=v_code);
  end loop;

  insert into public.wallets(name,join_code,created_by)
  values(coalesce(nullif(trim(p_name),''),'Our Monthly Voucher Wallet'),v_code,auth.uid())
  returning id into v_wallet;

  insert into public.wallet_members(wallet_id,user_id,display_name)
  values(v_wallet,auth.uid(),coalesce(trim(p_display_name),''));

  insert into public.categories(wallet_id,name,icon,limit_count,active,sort_order) values
    (v_wallet,'Fast Food','🍔',4,true,0),
    (v_wallet,'Wings / Buffet','🍗',1,true,1),
    (v_wallet,'Tusok-Tusok','🌭',6,true,2),
    (v_wallet,'Coffee','☕',3,true,3),
    (v_wallet,'Dessert','🍰',0,false,4),
    (v_wallet,'Other','✨',0,false,5);

  return v_wallet;
end;
$$;

grant execute on function public.create_shared_wallet(text,text) to authenticated;

-- ---------- join shared wallet ----------
create or replace function public.join_shared_wallet(
  p_join_code text,
  p_display_name text default ''
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_wallet uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  select id into v_wallet from public.wallets
  where join_code=upper(trim(p_join_code));

  if v_wallet is null then
    raise exception 'Wallet not found';
  end if;

  insert into public.wallet_members(wallet_id,user_id,display_name)
  values(v_wallet,auth.uid(),coalesce(trim(p_display_name),''))
  on conflict(wallet_id,user_id)
  do update set display_name=excluded.display_name;

  return v_wallet;
end;
$$;

grant execute on function public.join_shared_wallet(text,text) to authenticated;

-- ---------- security ----------
alter table public.wallets enable row level security;
alter table public.wallet_members enable row level security;
alter table public.categories enable row level security;
alter table public.activities enable row level security;

-- Wallets: members can read their wallet.
drop policy if exists wallets_select_member on public.wallets;
create policy wallets_select_member on public.wallets
for select to authenticated
using (public.is_wallet_member(id));

-- Members can read members in wallets they belong to.
drop policy if exists wallet_members_select_member on public.wallet_members;
create policy wallet_members_select_member on public.wallet_members
for select to authenticated
using (public.is_wallet_member(wallet_id));

-- Members can update their own display name.
drop policy if exists wallet_members_update_self on public.wallet_members;
create policy wallet_members_update_self on public.wallet_members
for update to authenticated
using (user_id=auth.uid() and public.is_wallet_member(wallet_id))
with check (user_id=auth.uid() and public.is_wallet_member(wallet_id));

-- Categories: shared read/write for members.
drop policy if exists categories_select_member on public.categories;
create policy categories_select_member on public.categories
for select to authenticated
using (public.is_wallet_member(wallet_id));

drop policy if exists categories_update_member on public.categories;
create policy categories_update_member on public.categories
for update to authenticated
using (public.is_wallet_member(wallet_id))
with check (public.is_wallet_member(wallet_id));

drop policy if exists categories_insert_member on public.categories;
create policy categories_insert_member on public.categories
for insert to authenticated
with check (public.is_wallet_member(wallet_id));

-- Activities: shared read/write for members.
drop policy if exists activities_select_member on public.activities;
create policy activities_select_member on public.activities
for select to authenticated
using (public.is_wallet_member(wallet_id));

drop policy if exists activities_insert_member on public.activities;
create policy activities_insert_member on public.activities
for insert to authenticated
with check (public.is_wallet_member(wallet_id) and created_by=auth.uid());

drop policy if exists activities_update_member on public.activities;
create policy activities_update_member on public.activities
for update to authenticated
using (public.is_wallet_member(wallet_id))
with check (public.is_wallet_member(wallet_id));

drop policy if exists activities_delete_member on public.activities;
create policy activities_delete_member on public.activities
for delete to authenticated
using (public.is_wallet_member(wallet_id));

grant select on public.wallets, public.wallet_members, public.categories, public.activities to authenticated;
grant insert, update, delete on public.categories, public.activities to authenticated;

-- ---------- updated_at ----------
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at=now();
  return new;
end;
$$;

drop trigger if exists activities_touch_updated_at on public.activities;
create trigger activities_touch_updated_at
before update on public.activities
for each row execute function public.touch_updated_at();

-- ---------- hard monthly voucher limit ----------
create or replace function public.enforce_monthly_activity_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_limit integer;
  v_count integer;
  v_month date;
begin
  select limit_count into v_limit
  from public.categories
  where id=new.category_id and wallet_id=new.wallet_id and active=true;

  if v_limit is null then
    raise exception 'Invalid or inactive category';
  end if;

  -- Serialize concurrent writes for the same wallet/category/month.
  perform pg_advisory_xact_lock(hashtext(
    new.wallet_id::text || ':' || new.category_id::text || ':' || to_char(new.date,'YYYY-MM')
  ));

  v_month := date_trunc('month',new.date)::date;

  select count(*) into v_count
  from public.activities
  where wallet_id=new.wallet_id
    and category_id=new.category_id
    and date >= v_month
    and date < (v_month + interval '1 month')::date
    and id <> coalesce(new.id,'00000000-0000-0000-0000-000000000000'::uuid);

  if v_count >= v_limit then
    raise exception '% has reached its monthly voucher limit of %', (
      select name from public.categories where id=new.category_id
    ), v_limit;
  end if;

  return new;
end;
$$;

drop trigger if exists activities_enforce_limit on public.activities;
create trigger activities_enforce_limit
before insert or update of wallet_id,category_id,date on public.activities
for each row execute function public.enforce_monthly_activity_limit();

-- ---------- realtime ----------
alter table public.activities replica identity full;
alter table public.categories replica identity full;

do $$
begin
  begin
    alter publication supabase_realtime add table public.activities;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.categories;
  exception when duplicate_object then null;
  end;
end $$;

-- Note:
-- Supabase Realtime + RLS uses the SELECT policies above to decide which
-- rows each connected authenticated user is allowed to receive.
