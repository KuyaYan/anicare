-- =====================================================================
--  AniCare 1.3.0  –  UPDATE for a project that already ran the 6.x scripts
--  Run once in the Supabase SQL Editor. Safe to run more than once.
--  (Offline mode does not need this file.)
--
--  Adds: the "available" flag of products (trash = hide, keep history),
--  GCash wording, delete permissions for the notification "Clear" button
--  and the schedule "Undo" button, the gcash_receiver() function used by
--  the GCash QR sheet, and GCash payment alerts for the payer + admin.
-- =====================================================================

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
