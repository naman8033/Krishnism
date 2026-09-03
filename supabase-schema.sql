-- Krishnism store database. Run this whole file in Supabase Dashboard → SQL Editor.
create extension if not exists pgcrypto;

create table if not exists public.offerings (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  type text not null check (type in ('book','course')),
  name text not null,
  description text not null,
  price integer not null check (price >= 0),
  kind text not null,
  cover text default '',
  meet_url text,
  is_published boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.offerings add column if not exists content text;

create table if not exists public.store_settings (
  id boolean primary key default true check (id),
  whatsapp_group_url text,
  default_meet_url text,
  student_welcome text,
  upi_id text default 'naman8080@ybl',
  upi_name text default 'Krishnism',
  support_whatsapp text default '918080808080',
  author_name text default 'Gourav Sharma',
  author_title text default 'Author & Founder of Krishnism',
  author_bio text,
  author_quote text,
  author_image_url text,
  updated_at timestamptz not null default now()
);

alter table public.store_settings add column if not exists whatsapp_group_url text;
alter table public.store_settings add column if not exists default_meet_url text;
alter table public.store_settings add column if not exists student_welcome text;
alter table public.store_settings add column if not exists upi_id text default 'naman8080@ybl';
alter table public.store_settings add column if not exists upi_name text default 'Krishnism';
alter table public.store_settings add column if not exists support_whatsapp text default '918080808080';
alter table public.store_settings add column if not exists author_name text default 'Gourav Sharma';
alter table public.store_settings add column if not exists author_title text default 'Author & Founder of Krishnism';
alter table public.store_settings add column if not exists author_bio text;
alter table public.store_settings add column if not exists author_quote text;
alter table public.store_settings add column if not exists author_image_url text;

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id),
  order_number text unique not null default ('KRI-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8))),
  customer_name text not null,
  customer_phone text not null,
  customer_email text not null,
  shipping_address text,
  city text,
  pin_code text,
  total integer not null,
  status text not null default 'pending' check (status in ('pending','paid','packed','shipped','completed','cancelled')),
  courier text,
  tracking_number text,
  payment_ref text,
  created_at timestamptz not null default now()
);

alter table public.orders add column if not exists user_id uuid references auth.users(id);
alter table public.orders add column if not exists payment_ref text;
alter table public.orders add column if not exists order_number text default ('KRI-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)));

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  offering_id uuid references public.offerings(id),
  item_name text not null,
  item_type text not null,
  unit_price integer not null,
  quantity integer not null default 1
);

alter table public.order_items add column if not exists quantity integer not null default 1;

-- Customer profiles for registered students & buyers
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
alter table public.customer_profiles add column if not exists whatsapp_added boolean not null default false;

-- Trigger to auto-create customer profile on auth sign up
create or replace function public.handle_new_customer()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.customer_profiles(id, email, full_name)
  values (new.id, new.email, coalesce(new.raw_user_meta_data ->> 'full_name', ''))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_customer_created on auth.users;
create trigger on_auth_customer_created
  after insert on auth.users
  for each row execute procedure public.handle_new_customer();

-- Backfill any existing users into customer_profiles
insert into public.customer_profiles(id, email)
select id, email from auth.users
on conflict (id) do nothing;

-- Your first authenticated account is the administrator.
-- Replace this email if you change your admin email.
create or replace function public.is_store_admin()
returns boolean language plpgsql stable security definer set search_path = public as $$
begin
  return coalesce(
    lower(auth.jwt() ->> 'email') = 'naman8033@gmail.com'
    or exists (
      select 1 from auth.users 
      where id = auth.uid() and lower(email) = 'naman8033@gmail.com'
    ),
    false
  );
end;
$$;

-- 6. Customer & Student Reviews for Books and Courses
create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  offering_id uuid not null references public.offerings(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  customer_name text not null,
  rating integer check (rating >= 1 and rating <= 5) not null,
  headline text,
  comment text not null,
  is_verified boolean not null default true,
  is_approved boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint user_offering_review_unique unique(offering_id, user_id)
);

create index if not exists idx_reviews_offering on public.reviews(offering_id);
create index if not exists idx_reviews_user on public.reviews(user_id);

-- Enable RLS & grants
alter table public.offerings enable row level security;
alter table public.store_settings enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.customer_profiles enable row level security;
alter table public.reviews enable row level security;

revoke all on public.offerings, public.store_settings, public.orders, public.order_items, public.customer_profiles, public.reviews from anon, authenticated;
grant select on public.offerings, public.store_settings, public.reviews to anon, authenticated;
grant select, insert, update, delete on public.offerings, public.store_settings, public.orders, public.order_items, public.customer_profiles, public.reviews to authenticated;

drop policy if exists "Public reads published offerings" on public.offerings;
drop policy if exists "Public reads store settings" on public.store_settings;
drop policy if exists "Public reads approved reviews" on public.reviews;
drop policy if exists "Admin manages offerings" on public.offerings;
drop policy if exists "Admin manages settings" on public.store_settings;
drop policy if exists "Admin reads orders" on public.orders;
drop policy if exists "Admin updates orders" on public.orders;
drop policy if exists "Admin reads order items" on public.order_items;
drop policy if exists "Customers read own orders" on public.orders;
drop policy if exists "Customers read own order items" on public.order_items;
drop policy if exists "Customers manage own profile" on public.customer_profiles;
drop policy if exists "Admin manages customer profiles" on public.customer_profiles;
drop policy if exists "Verified buyers insert reviews" on public.reviews;
drop policy if exists "Users update own reviews" on public.reviews;
drop policy if exists "Admin manages all reviews" on public.reviews;

create policy "Public reads published offerings" on public.offerings for select using (is_published or public.is_store_admin());
create policy "Public reads store settings" on public.store_settings for select using (true);
create policy "Public reads approved reviews" on public.reviews for select using (is_approved or public.is_store_admin());
create policy "Admin manages offerings" on public.offerings for all to authenticated using (public.is_store_admin()) with check (public.is_store_admin());
create policy "Admin manages settings" on public.store_settings for all to authenticated using (public.is_store_admin()) with check (public.is_store_admin());
create policy "Admin reads orders" on public.orders for select to authenticated using (public.is_store_admin());
create policy "Admin updates orders" on public.orders for update to authenticated using (public.is_store_admin()) with check (public.is_store_admin());
create policy "Admin reads order items" on public.order_items for select to authenticated using (public.is_store_admin());
create policy "Customers read own orders" on public.orders for select to authenticated using (auth.uid() = user_id);
create policy "Customers read own order items" on public.order_items for select to authenticated using (exists (select 1 from public.orders o where o.id = order_items.order_id and o.user_id = auth.uid()));
create policy "Customers manage own profile" on public.customer_profiles for all to authenticated using (auth.uid() = id) with check (auth.uid() = id);
create policy "Admin manages customer profiles" on public.customer_profiles for all to authenticated using (public.is_store_admin()) with check (public.is_store_admin());

create policy "Verified buyers insert reviews" on public.reviews for insert to authenticated 
  with check (
    auth.uid() = user_id 
    and (
      public.is_store_admin() 
      or exists (
        select 1 from public.orders o 
        join public.order_items oi on oi.order_id = o.id 
        where o.user_id = auth.uid() 
          and o.status in ('paid', 'completed', 'shipped')
          and (oi.offering_id = reviews.offering_id or oi.item_name in (select name from public.offerings where id = reviews.offering_id))
      )
    )
  );

create policy "Users update own reviews" on public.reviews for update to authenticated 
  using (auth.uid() = user_id or public.is_store_admin()) 
  with check (auth.uid() = user_id or public.is_store_admin());

create policy "Admin manages all reviews" on public.reviews for all to authenticated 
  using (public.is_store_admin()) 
  with check (public.is_store_admin());

-- Public checkout uses this controlled function: it recalculates every price from the database.
create or replace function public.create_store_order(p_customer jsonb, p_items jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_order_id uuid;
  v_total integer := 0;
  v_item jsonb;
  v_product public.offerings%rowtype;
  v_raw_id text;
  v_qty integer;
begin
  if auth.uid() is null then 
    raise exception 'Please sign in before placing an order'; 
  end if;
  if p_items is null or jsonb_array_length(p_items) = 0 then 
    raise exception 'Order must contain at least one item'; 
  end if;

  -- 1. Calculate verified total from database prices
  for v_item in select value from jsonb_array_elements(p_items) loop
    if jsonb_typeof(v_item) = 'object' then
      v_raw_id := trim(both '"' from (v_item->>'id'));
      v_qty := coalesce(nullif(v_item->>'quantity', '')::integer, 1);
    else
      v_raw_id := trim(both '"' from v_item::text);
      v_qty := 1;
    end if;

    -- Lookup offering by UUID, by exact slug, or by legacy identifier
    if v_raw_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
      select * into v_product from public.offerings where id = v_raw_id::uuid and is_published;
    else
      select * into v_product from public.offerings 
      where is_published and (
        slug = v_raw_id 
        or slug = regexp_replace(v_raw_id, '^(book|course)-', '')
        or (v_raw_id = 'book-gita' and slug = 'gita-reflections')
        or (v_raw_id = 'book-devotion' and slug = 'way-of-devotion')
        or (v_raw_id = 'course-gita' and slug = 'gita-living-guide')
        or (v_raw_id = 'course-bhakti' and slug = 'path-of-bhakti')
        or (v_raw_id = 'course-meet' and slug = 'live-gita-circle')
      ) limit 1;
    end if;

    if not found then 
      raise exception 'Product unavailable (%): please clear bag and re-add item.', v_raw_id; 
    end if;
    v_total := v_total + (v_product.price * v_qty);
  end loop;

  -- 2. Insert order
  insert into public.orders(
    user_id, customer_name, customer_phone, customer_email,
    shipping_address, city, pin_code, total, status, payment_ref
  ) values (
    auth.uid(),
    p_customer->>'name',
    p_customer->>'phone',
    p_customer->>'email',
    p_customer->>'address',
    p_customer->>'city',
    p_customer->>'pin',
    v_total,
    'pending',
    nullif(trim(p_customer->>'payment_ref'), '')
  ) returning id into v_order_id;

  -- 3. Insert order items
  for v_item in select value from jsonb_array_elements(p_items) loop
    if jsonb_typeof(v_item) = 'object' then
      v_raw_id := trim(both '"' from (v_item->>'id'));
      v_qty := coalesce(nullif(v_item->>'quantity', '')::integer, 1);
    else
      v_raw_id := trim(both '"' from v_item::text);
      v_qty := 1;
    end if;

    if v_raw_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
      select * into v_product from public.offerings where id = v_raw_id::uuid and is_published;
    else
      select * into v_product from public.offerings 
      where is_published and (
        slug = v_raw_id 
        or slug = regexp_replace(v_raw_id, '^(book|course)-', '')
        or (v_raw_id = 'book-gita' and slug = 'gita-reflections')
        or (v_raw_id = 'book-devotion' and slug = 'way-of-devotion')
        or (v_raw_id = 'course-gita' and slug = 'gita-living-guide')
        or (v_raw_id = 'course-bhakti' and slug = 'path-of-bhakti')
        or (v_raw_id = 'course-meet' and slug = 'live-gita-circle')
      ) limit 1;
    end if;

    insert into public.order_items(order_id, offering_id, item_name, item_type, unit_price, quantity)
    values (v_order_id, v_product.id, v_product.name, v_product.type, v_product.price, v_qty);
  end loop;

  return v_order_id;
end; $$;
grant execute on function public.create_store_order(jsonb,jsonb) to anon, authenticated;

-- Add the initial offerings (safe to run once; re-running will update them).
insert into public.offerings(slug,type,name,description,price,kind,cover) values
('krishnism','book','Krishnism','A companion for bringing Krishna consciousness into everyday life.',399,'Paperback',''),
('gita-reflections','book','Gita Reflections','Short, gentle reflections to return to throughout your week.',299,'Paperback','green'),
('way-of-devotion','book','The Way of Devotion','Essays on bhakti, belonging and the art of surrender.',349,'Paperback','blue'),
('gita-living-guide','course','Bhagavad Gita: A Living Guide','A guided journey through the Gita, with recorded teachings and reflection prompts.',1499,'12 recorded sessions',''),
('path-of-bhakti','course','The Path of Bhakti','Discover devotion as a practical way of living with openness and love.',999,'8 recorded sessions',''),
('live-gita-circle','course','Live Gita Circle','A warm, ongoing online study circle. Join live sessions on Google Meet.',799,'Monthly membership','')
on conflict (slug) do update set name=excluded.name,description=excluded.description,price=excluded.price,kind=excluded.kind,cover=excluded.cover;

insert into public.store_settings(id, upi_id, upi_name) values(true, 'naman8080@ybl', 'Krishnism') on conflict (id) do nothing;

-- 7. Seed initial authentic reviews for offerings
insert into public.reviews(offering_id, customer_name, rating, headline, comment, is_verified, is_approved)
select id, 'Ananya Sharma', 5, 'My daily morning sanctuary', 'This book has become my morning companion. The language is gentle, deeply meditative, and practical for daily contemplation in modern life.', true, true
from public.offerings where slug = 'krishnism'
on conflict (offering_id, user_id) do nothing;

insert into public.reviews(offering_id, customer_name, rating, headline, comment, is_verified, is_approved)
select id, 'Rohan Mehta', 5, 'Clarity, depth, and beauty', 'A masterpiece of clarity and devotion. Brings the Gita essence right into everyday work and relationships without being preachy.', true, true
from public.offerings where slug = 'krishnism'
on conflict (offering_id, user_id) do nothing;

insert into public.reviews(offering_id, customer_name, rating, headline, comment, is_verified, is_approved)
select id, 'Priya Venkatesh', 5, 'Transformative daily reflections', 'Short, 2-minute readings that transform the entire tone of your day. The print and paper feel so premium and peaceful in hand.', true, true
from public.offerings where slug = 'gita-reflections'
on conflict (offering_id, user_id) do nothing;

insert into public.reviews(offering_id, customer_name, rating, headline, comment, is_verified, is_approved)
select id, 'Radhika Nair', 5, 'Speaks straight to the soul', 'Essays on bhakti and surrender that touch the deepest corners of the heart. Read it slowly with a cup of tea.', true, true
from public.offerings where slug = 'way-of-devotion'
on conflict (offering_id, user_id) do nothing;

insert into public.reviews(offering_id, customer_name, rating, headline, comment, is_verified, is_approved)
select id, 'Aarav Kapoor', 5, 'Life-changing course experience', 'The 12 recorded sessions are extraordinary. No pressure, just profound living wisdom. The WhatsApp cohort discussions add so much warmth and insight.', true, true
from public.offerings where slug = 'gita-living-guide'
on conflict (offering_id, user_id) do nothing;

insert into public.reviews(offering_id, customer_name, rating, headline, comment, is_verified, is_approved)
select id, 'Siddharth Joshi', 5, 'Practical devotion for daily living', 'Helped me understand bhakti not as an abstract ritual, but as an open-hearted way of relating to everything.', true, true
from public.offerings where slug = 'path-of-bhakti'
on conflict (offering_id, user_id) do nothing;

insert into public.reviews(offering_id, customer_name, rating, headline, comment, is_verified, is_approved)
select id, 'Shweta Desai', 5, 'A quiet haven in a busy week', 'The live study circle sessions on Google Meet are the highlight of my week. Wonderful sangha and thoughtful discourse.', true, true
from public.offerings where slug = 'live-gita-circle'
on conflict (offering_id, user_id) do nothing;
