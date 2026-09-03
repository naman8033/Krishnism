-- Customer business records. Passwords remain exclusively in Supabase Auth.
create table if not exists public.customer_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  full_name text,
  phone text,
  shipping_address text,
  city text,
  pin_code text,
  whatsapp_added boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.customer_profiles add column if not exists shipping_address text;
alter table public.customer_profiles add column if not exists city text;
alter table public.customer_profiles add column if not exists pin_code text;

create or replace function public.handle_new_customer()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.customer_profiles(id,email,full_name)
  values (new.id, new.email, coalesce(new.raw_user_meta_data ->> 'full_name', ''))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_customer_created on auth.users;
create trigger on_auth_customer_created
  after insert on auth.users
  for each row execute procedure public.handle_new_customer();

alter table public.customer_profiles enable row level security;
revoke all on public.customer_profiles from anon;
grant select, update on public.customer_profiles to authenticated;
drop policy if exists "Customers manage own profile" on public.customer_profiles;
drop policy if exists "Admin manages customer profiles" on public.customer_profiles;
create policy "Customers manage own profile" on public.customer_profiles
  for all to authenticated using (auth.uid() = id) with check (auth.uid() = id);
create policy "Admin manages customer profiles" on public.customer_profiles
  for all to authenticated using (public.is_store_admin()) with check (public.is_store_admin());

-- Optional: make profiles for existing authenticated users before the trigger was installed.
insert into public.customer_profiles(id,email)
select id,email from auth.users
on conflict (id) do nothing;
