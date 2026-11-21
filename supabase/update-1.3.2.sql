-- =====================================================================
--  AniCare 1.3.2  –  run ONCE in the Supabase SQL Editor (online mode only).
--  Already applied in this project's Supabase instance. Kept here for reference.
--  Lets a farmer edit notes on his own animals (needed for the new "Edit note" button).
--  Animals, expenses and products already had the permissions they need.
-- =====================================================================

drop policy if exists records_update on public.records;
create policy records_update on public.records for update to authenticated
  using (exists (select 1 from public.animals a where a.id = records.animal_id and a.owner_id = public.me_id()))
  with check (exists (select 1 from public.animals a where a.id = records.animal_id and a.owner_id = public.me_id()));

grant update on public.records to authenticated;
