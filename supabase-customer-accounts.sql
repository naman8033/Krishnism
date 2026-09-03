-- Run this in Supabase Dashboard → SQL Editor to upgrade database with customer accounts, order quantities & UPI features.
alter table public.orders add column if not exists user_id uuid references auth.users(id);
alter table public.orders add column if not exists payment_ref text;
alter table public.orders add column if not exists order_number text default ('KRI-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)));
alter table public.order_items add column if not exists quantity integer not null default 1;
alter table public.store_settings add column if not exists upi_id text default 'naman8080@ybl';
alter table public.store_settings add column if not exists upi_name text default 'Krishnism';

-- Admin authorization function
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

alter table public.reviews enable row level security;
revoke all on public.reviews from anon, authenticated;
grant select on public.reviews to anon, authenticated;
grant insert, update, delete on public.reviews to authenticated;

drop policy if exists "Public reads approved reviews" on public.reviews;
drop policy if exists "Verified buyers insert reviews" on public.reviews;
drop policy if exists "Users update own reviews" on public.reviews;
drop policy if exists "Admin manages all reviews" on public.reviews;

create policy "Public reads approved reviews" on public.reviews for select using (is_approved or public.is_store_admin());
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
  )
  values(
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
    values(v_order_id, v_product.id, v_product.name, v_product.type, v_product.price, v_qty);
  end loop;

  return v_order_id;
end; $$;
grant execute on function public.create_store_order(jsonb,jsonb) to anon, authenticated;
