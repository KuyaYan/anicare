-- =====================================================================
--  AniCare 6.1.0  –  Supabase schema  (run this FIRST, then seed.sql)
--  Dashboard -> SQL Editor -> New query -> paste all -> Run
-- =====================================================================
create extension if not exists pgcrypto with schema extensions;

-- ------------------------------------------------------------ tables
create table public.users (
  id         bigint generated always as identity primary key,
  auth_id    uuid unique references auth.users(id) on delete set null,
  username   text unique not null,
  full_name  text not null,
  display    text,
  phone      text,
  place      text,
  role       text not null check (role in ('raiser','vet','store','admin')),
  active     integer not null default 1,
  created    bigint
);

create table public.vets (
  id bigint generated always as identity primary key,
  user_id bigint references public.users(id) on delete cascade,
  name text, kind text, about text, photo text, license text,
  km double precision, fee double precision, rating double precision,
  services text, plan_until bigint
);

create table public.stores (
  id bigint generated always as identity primary key,
  user_id bigint references public.users(id) on delete cascade,
  name text, address text, photo text, km double precision, plan_until bigint
);

create table public.products (
  id bigint generated always as identity primary key,
  store_id bigint references public.stores(id) on delete cascade,
  name text, cat text, price double precision, stock integer, img text, expiry bigint
);

create table public.animals (
  id bigint generated always as identity primary key,
  owner_id bigint references public.users(id) on delete cascade,
  name text, breed text, species text, flock integer, heads integer, photo text
);

create table public.schedules (
  id bigint generated always as identity primary key,
  animal_id bigint references public.animals(id) on delete cascade,
  label text, due bigint, done integer
);

create table public.records (
  id bigint generated always as identity primary key,
  animal_id bigint references public.animals(id) on delete cascade,
  at bigint, title text, note text, author text
);

create table public.expenses (
  id bigint generated always as identity primary key,
  animal_id bigint references public.animals(id) on delete cascade,
  at bigint, item text, amount double precision
);

create table public.bookings (
  id bigint generated always as identity primary key,
  raiser_id bigint references public.users(id) on delete cascade,
  raiser_name text,
  vet_id bigint references public.vets(id) on delete cascade,
  animal_id bigint references public.animals(id) on delete set null,
  animal_name text, reason text, day bigint, slot text, fee double precision,
  urgent integer, status text, r_confirm integer, v_confirm integer, method text, rating integer
);

create table public.reservations (
  id bigint generated always as identity primary key,
  raiser_id bigint references public.users(id) on delete cascade,
  raiser_name text,
  store_id bigint references public.stores(id) on delete cascade,
  product_id bigint references public.products(id) on delete cascade,
  qty integer, method text, picked_up integer
);

create table public.payments (
  id bigint generated always as identity primary key,
  kind text, ref_id bigint, payer text, payee text, item text,
  amount double precision, method text, status text, at bigint
);

-- ------------------------------------------------------------ helper functions
create or replace function public.me_id() returns bigint
language sql stable security definer set search_path = public as $$
  select id from public.users where auth_id = auth.uid() limit 1
$$;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select role = 'admin' and active = 1 from public.users where auth_id = auth.uid() limit 1), false)
$$;

create or replace function public.my_vet_ids() returns setof bigint
language sql stable security definer set search_path = public as $$
  select id from public.vets where user_id = public.me_id()
$$;

create or replace function public.my_store_ids() returns setof bigint
language sql stable security definer set search_path = public as $$
  select id from public.stores where user_id = public.me_id()
$$;

-- used by the sign-up screen (before login) to see if a username is free
create or replace function public.username_taken(p_name text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.users where lower(username) = lower(p_name))
$$;

-- a farmer reserving a product lowers its stock
create or replace function public.adjust_stock(p_id bigint, p_delta integer) returns void
language sql security definer set search_path = public as $$
  update public.products set stock = greatest(stock + p_delta, 0) where id = p_id
$$;

-- admin only: switch an account on / off (also blocks the login itself)
create or replace function public.admin_set_active(p_user bigint, p_active integer) returns void
language plpgsql security definer set search_path = public, auth as $$
declare a uuid;
begin
  if not public.is_admin() then raise exception 'admin only'; end if;
  update public.users set active = p_active where id = p_user returning auth_id into a;
  if a is not null then
    update auth.users
       set banned_until = case when p_active = 0 then 'infinity'::timestamptz else null end
     where id = a;
  end if;
end $$;

-- admin only: set a new password for an account
create or replace function public.admin_reset_password(p_user bigint, p_password text) returns void
language plpgsql security definer set search_path = public, auth, extensions as $$
declare a uuid;
begin
  if not public.is_admin() then raise exception 'admin only'; end if;
  select auth_id into a from public.users where id = p_user;
  if a is null then raise exception 'this account has no login'; end if;
  update auth.users
     set encrypted_password = extensions.crypt(p_password, extensions.gen_salt('bf')), updated_at = now()
   where id = a;
end $$;

revoke execute on function public.admin_set_active(bigint, integer) from public, anon;
revoke execute on function public.admin_reset_password(bigint, text) from public, anon;
revoke execute on function public.adjust_stock(bigint, integer) from public, anon;
grant execute on function public.username_taken(text) to anon, authenticated;
grant execute on function public.adjust_stock(bigint, integer) to authenticated;
grant execute on function public.admin_set_active(bigint, integer) to authenticated;
grant execute on function public.admin_reset_password(bigint, text) to authenticated;
grant execute on function public.me_id(), public.is_admin(), public.my_vet_ids(), public.my_store_ids() to authenticated;

-- ------------------------------------------------------------ row level security
alter table public.users        enable row level security;
alter table public.vets         enable row level security;
alter table public.stores       enable row level security;
alter table public.products     enable row level security;
alter table public.animals      enable row level security;
alter table public.schedules    enable row level security;
alter table public.records      enable row level security;
alter table public.expenses     enable row level security;
alter table public.bookings     enable row level security;
alter table public.reservations enable row level security;
alter table public.payments     enable row level security;

-- users: you see yourself; the admin sees (and edits) everyone
create policy users_select on public.users for select to authenticated
  using (auth_id = auth.uid() or public.is_admin());
create policy users_insert on public.users for insert to authenticated
  with check (auth_id = auth.uid() and role in ('raiser','vet','store'));
create policy users_admin_update on public.users for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- vets + stores: everyone signed in can see them; owners edit their own
create policy vets_select on public.vets for select to authenticated using (true);
create policy vets_insert on public.vets for insert to authenticated with check (user_id = public.me_id());
create policy vets_update on public.vets for update to authenticated
  using (user_id = public.me_id() or public.is_admin());

create policy stores_select on public.stores for select to authenticated using (true);
create policy stores_insert on public.stores for insert to authenticated with check (user_id = public.me_id());
create policy stores_update on public.stores for update to authenticated
  using (user_id = public.me_id() or public.is_admin());

create policy products_select on public.products for select to authenticated using (true);
create policy products_insert on public.products for insert to authenticated
  with check (store_id in (select public.my_store_ids()) or public.is_admin());
create policy products_update on public.products for update to authenticated
  using (store_id in (select public.my_store_ids()) or public.is_admin());

-- animals: owner + admin, and a vet who has a booking for that animal
create policy animals_select on public.animals for select to authenticated
  using (owner_id = public.me_id() or public.is_admin()
         or exists (select 1 from public.bookings b
                     where b.animal_id = animals.id and b.vet_id in (select public.my_vet_ids())));
create policy animals_insert on public.animals for insert to authenticated with check (owner_id = public.me_id());
create policy animals_update on public.animals for update to authenticated
  using (owner_id = public.me_id() or public.is_admin());
create policy animals_delete on public.animals for delete to authenticated
  using (owner_id = public.me_id() or public.is_admin());

create policy schedules_all on public.schedules for all to authenticated
  using (exists (select 1 from public.animals a where a.id = schedules.animal_id and (a.owner_id = public.me_id() or public.is_admin())))
  with check (exists (select 1 from public.animals a where a.id = schedules.animal_id and a.owner_id = public.me_id()));

create policy expenses_all on public.expenses for all to authenticated
  using (exists (select 1 from public.animals a where a.id = expenses.animal_id and (a.owner_id = public.me_id() or public.is_admin())))
  with check (exists (select 1 from public.animals a where a.id = expenses.animal_id and a.owner_id = public.me_id()));

-- records: anyone who can see the animal (owner, admin, vet with a booking)
create policy records_select on public.records for select to authenticated
  using (exists (select 1 from public.animals a where a.id = records.animal_id));
create policy records_insert on public.records for insert to authenticated
  with check (exists (select 1 from public.animals a where a.id = records.animal_id)
              and not public.is_admin());

create policy bookings_select on public.bookings for select to authenticated
  using (raiser_id = public.me_id() or vet_id in (select public.my_vet_ids()) or public.is_admin());
create policy bookings_insert on public.bookings for insert to authenticated with check (raiser_id = public.me_id());
create policy bookings_update on public.bookings for update to authenticated
  using (raiser_id = public.me_id() or vet_id in (select public.my_vet_ids()) or public.is_admin());

create policy reservations_select on public.reservations for select to authenticated
  using (raiser_id = public.me_id() or store_id in (select public.my_store_ids()) or public.is_admin());
create policy reservations_insert on public.reservations for insert to authenticated with check (raiser_id = public.me_id());
create policy reservations_update on public.reservations for update to authenticated
  using (store_id in (select public.my_store_ids()) or public.is_admin());

-- payments: anyone signed in can add a line, only the admin can read them
create policy payments_select on public.payments for select to authenticated using (public.is_admin());
create policy payments_insert on public.payments for insert to authenticated with check (auth.uid() is not null);

-- ------------------------------------------------------------ permissions
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;

-- ---------------------------------------------------------------------
--  6.1.0 additions: payment links, notifications, profile/username functions, triggers
-- ---------------------------------------------------------------------
alter table public.payments add column if not exists payer_id bigint;
alter table public.payments add column if not exists payee_id bigint;
alter table public.payments add column if not exists ref text;      -- Maya checkout id

create table if not exists public.notifications (
  id bigint generated always as identity primary key,
  user_id bigint references public.users(id) on delete cascade,
  kind text, title text, body text, created bigint,
  read integer not null default 0, payload text
);
alter table public.notifications enable row level security;
drop policy if exists notif_select on public.notifications;
drop policy if exists notif_insert on public.notifications;
drop policy if exists notif_update on public.notifications;
create policy notif_select on public.notifications for select to authenticated using (user_id = public.me_id());
create policy notif_insert on public.notifications for insert to authenticated with check (user_id = public.me_id());
create policy notif_update on public.notifications for update to authenticated using (user_id = public.me_id());
grant select, insert, update, delete on public.notifications to authenticated;
grant usage, select on all sequences in schema public to authenticated;

-- a signed-in user edits their own profile (the table itself only allows the admin to update users)
create or replace function public.update_my_profile(p_full_name text, p_phone text, p_place text, p_display text) returns void
language sql security definer set search_path = public as $$
  update public.users set full_name = p_full_name, phone = p_phone, place = p_place, display = p_display
   where auth_id = auth.uid()
$$;

-- change the username = change the hidden login email (username@anicare.app)
create or replace function public.change_username(p_new text) returns void
language plpgsql security definer set search_path = public, auth as $$
declare uid uuid := auth.uid();
        newmail text := lower(p_new) || '@anicare.app';
begin
  if uid is null then raise exception 'not signed in'; end if;
  if p_new !~ '^[a-z0-9._]{4,20}$' then raise exception 'bad username'; end if;
  if exists (select 1 from public.users where lower(username) = lower(p_new) and auth_id <> uid) then
    raise exception 'username taken';
  end if;
  update public.users set username = lower(p_new) where auth_id = uid;
  update auth.users set email = newmail, updated_at = now() where id = uid;
  update auth.identities
     set identity_data = jsonb_set(identity_data, '{email}', to_jsonb(newmail)), updated_at = now()
   where user_id = uid and provider = 'email';
end $$;

revoke execute on function public.update_my_profile(text, text, text, text) from public, anon;
revoke execute on function public.change_username(text) from public, anon;
grant execute on function public.update_my_profile(text, text, text, text) to authenticated;
grant execute on function public.change_username(text) to authenticated;

-- ---------------- notifications created on the server (so OTHER phones get them)
create or replace function public.notify_users(p_ids bigint[], p_kind text, p_title text, p_body text, p_payload text) returns void
language sql security definer set search_path = public as $$
  insert into public.notifications (user_id, kind, title, body, created, read, payload)
  select u, p_kind, p_title, p_body, (extract(epoch from now()) * 1000)::bigint, 0, p_payload
    from unnest(p_ids) as u where u is not null
$$;

-- a store adds a product -> every farmer is told
create or replace function public.trg_new_product() returns trigger
language plpgsql security definer set search_path = public as $$
declare sname text;
begin
  select name into sname from public.stores where id = new.store_id;
  perform public.notify_users(array(select id from public.users where role = 'raiser' and active = 1),
    'new_product', 'New product available', new.name || ' at ' || coalesce(sname, 'a store') || '.', 'bell');
  return new;
end $$;
drop trigger if exists new_product_notify on public.products;
create trigger new_product_notify after insert on public.products
  for each row execute function public.trg_new_product();

-- reservations and the 5% fee are written by the app as paid lines
create or replace function public.trg_payment_insert() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.kind = 'reservation' and new.payee_id is not null then
    perform public.notify_users(array[new.payee_id], 'reservation', 'New reservation',
      new.payer || ' reserved ' || new.item || '.', 'bell');
  elsif new.kind = 'fee' then
    perform public.notify_users(array(select id from public.users where role = 'admin' and active = 1),
      'fee', 'AniCare fee recorded', '₱' || to_char(new.amount, 'FM999990.00') || ' (5%) from a completed booking.', 'bell');
  end if;
  return new;
end $$;
drop trigger if exists payment_insert_notify on public.payments;
create trigger payment_insert_notify after insert on public.payments
  for each row execute function public.trg_payment_insert();

-- Maya payments: the server function flips status pending -> held / paid / failed
create or replace function public.trg_payment_update() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if old.status = 'pending' and new.status in ('held', 'paid') then
    if new.kind = 'subscription' then
      if new.payer_id is not null then
        perform public.notify_users(array[new.payer_id], 'sub_bought', 'Subscription active',
          'Your AniCare Store plan was extended by 30 days.', 'plan');
      end if;
      perform public.notify_users(array(select id from public.users where role = 'admin' and active = 1),
        'sub_bought', 'Store subscription bought', new.payer || ' paid ₱39 for the store plan.', 'bell');
    elsif new.kind = 'booking' and new.payee_id is not null then
      perform public.notify_users(array[new.payee_id], 'booking_paid', 'New paid booking',
        new.payer || ' paid ₱' || to_char(new.amount, 'FM999990.00') || ' with Maya for ' || new.item || '.', 'bell');
    end if;
  elsif old.status = 'pending' and new.status = 'failed' and new.payer_id is not null then
    perform public.notify_users(array[new.payer_id], 'pay_failed', 'Payment failed',
      'Your Maya payment for ' || new.item || ' was not completed.', 'bell');
  end if;
  return new;
end $$;
drop trigger if exists payment_update_notify on public.payments;
create trigger payment_update_notify after update on public.payments
  for each row execute function public.trg_payment_update();

-- emergency (free) bookings have no payment, so tell the vet directly
create or replace function public.trg_booking_insert() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.urgent = 1 then
    perform public.notify_users(array(select user_id from public.vets where id = new.vet_id),
      'booking_paid', 'Emergency request', new.raiser_name || ' sent an emergency request: ' || new.reason, 'bell');
  end if;
  return new;
end $$;
drop trigger if exists booking_insert_notify on public.bookings;
create trigger booking_insert_notify after insert on public.bookings
  for each row execute function public.trg_booking_insert();

-- ---------------------------------------------------------------------
--  1.3.0 additions: soft-deleted products, GCash wording + alerts, delete policies
-- ---------------------------------------------------------------------
-- 1) products: the trash button only hides a product (old reservations keep their history)
alter table public.products add column if not exists available integer not null default 1;

-- 2) old Maya wording becomes GCash
update public.bookings     set method = 'GCash' where method = 'Maya';
update public.payments     set method = 'GCash' where method = 'Maya';
update public.reservations set method = 'GCash' where method = 'Maya';

-- 3) bell list: the "Clear" button deletes this account's notifications
drop policy if exists notif_delete on public.notifications;
create policy notif_delete on public.notifications for delete to authenticated
  using (user_id = public.me_id());

-- 4) schedule "Undo": deletes the "Marked done by raiser." record again
drop policy if exists records_delete on public.records;
create policy records_delete on public.records for delete to authenticated
  using (exists (select 1 from public.animals a
                  where a.id = records.animal_id
                    and (a.owner_id = public.me_id() or public.is_admin())));

-- 5) the GCash QR code is made from the admin's mobile number
create or replace function public.gcash_receiver() returns text
language sql stable security definer set search_path = public as $$
  select phone from public.users where role = 'admin' and active = 1 limit 1
$$;
revoke execute on function public.gcash_receiver() from public, anon;
grant execute on function public.gcash_receiver() to authenticated;

-- 6) GCash payment alerts (the app inserts payments with status 'paid' / 'held',
--    so the old pending -> paid trigger never fires for the GCash flow)
create or replace function public.trg_payment_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  amt text := '₱' || to_char(new.amount, 'FM999990.00');
  who text := coalesce(new.payer, 'A user');
  rf  text := coalesce(new.ref, '-');
begin
  if new.kind = 'booking' and new.payee_id is not null then
    perform public.notify_users(array[new.payee_id], 'booking_paid', 'New paid booking',
      who || ' booked you • ' || new.item, 'bell');
  elsif new.kind = 'reservation' and new.payee_id is not null then
    perform public.notify_users(array[new.payee_id], 'reservation', 'New reservation',
      who || ' reserved ' || new.item || '.', 'bell');
  elsif new.kind = 'subscription' then
    if new.payer_id is not null then
      perform public.notify_users(array[new.payer_id], 'sub_bought', 'Subscription active',
        'Your AniCare Store plan is active (paid with GCash, ref. ' || rf || ').', 'plan');
    end if;
    perform public.notify_users(array(select id from public.users where role = 'admin' and active = 1),
      'sub_bought', 'Store subscription bought', who || ' paid ₱39 for the store plan (GCash ref. ' || rf || ').', 'bell');
  elsif new.kind = 'fee' then
    perform public.notify_users(array(select id from public.users where role = 'admin' and active = 1),
      'fee', 'AniCare fee recorded', amt || ' (5%) from a completed booking.', 'bell');
  end if;

  -- GCash receipt: the payer and every admin
  if new.kind in ('booking', 'reservation', 'subscription') then
    if new.payer_id is not null then
      perform public.notify_users(array[new.payer_id], 'pay_ok', 'Payment successful',
        'Your GCash payment of ' || amt || ' for ' || new.item || ' was received (ref. ' || rf || ').', 'bell');
    end if;
    perform public.notify_users(array(select id from public.users where role = 'admin' and active = 1),
      'pay_in', 'GCash payment received',
      who || ' paid ' || amt || ' for ' || new.item || ' (ref. ' || rf || ').', 'bell');
  end if;
  return new;
end $$;
drop trigger if exists payment_insert_notify on public.payments;
create trigger payment_insert_notify after insert on public.payments
  for each row execute function public.trg_payment_insert();
