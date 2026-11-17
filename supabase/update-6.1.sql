-- =====================================================================
--  AniCare 6.1.0  –  UPDATE for a project that already ran the 6.0.0 scripts
--  Run once in SQL Editor. It adds the new columns/tables/functions/triggers
--  and deletes the OLD DUMMY purchase history (the admin now sees real
--  Maya sandbox transactions only). Your accounts and other data stay.
-- =====================================================================

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

-- remove the sample purchase rows that seed.sql (6.0.0) created
delete from public.payments where ref is null and ref_id = 0;
-- clear any notifications created while seeding
delete from public.notifications;
