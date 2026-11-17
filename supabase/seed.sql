-- =====================================================================
--  AniCare 6.1.0  –  Supabase starting data  (run AFTER schema.sql)
--  Creates the 4 test logins + sample vets, stores, animals, bookings,
--  and vaccine stock (with expiry dates). NO dummy purchases: the admin's
--  purchase data comes only from real Maya sandbox transactions.
--  All test accounts use the password:  AniCare2987!
--  Run it ONCE. (To start over see "Start over" in supabase-and-maya-guide.md)
-- =====================================================================

-- helper: create a login in Supabase Auth (email = username@anicare.app)
create or replace function public._seed_auth(p_email text, p_pw text) returns uuid
language plpgsql security definer set search_path = public, auth, extensions as $$
declare uid uuid;
begin
  select id into uid from auth.users where email = p_email;
  if uid is null then
    uid := gen_random_uuid();
    insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                            raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                            confirmation_token, email_change, email_change_token_new, recovery_token)
    values ('00000000-0000-0000-0000-000000000000', uid, 'authenticated', 'authenticated', p_email,
            extensions.crypt(p_pw, extensions.gen_salt('bf')), now(),
            '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', '');
    insert into auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
    values (gen_random_uuid(), uid,
            jsonb_build_object('sub', uid::text, 'email', p_email, 'email_verified', true),
            'email', uid::text, now(), now(), now());
  end if;
  return uid;
end $$;

-- helper: start of the day, d days from today, in milliseconds
create or replace function public._ms(d integer) returns bigint
language sql stable as $$ select (extract(epoch from (current_date + d)) * 1000)::bigint $$;

do $$
declare
  pw text := 'AniCare2987!';
  ruben bigint; maria bigint; shop bigint; adm bigint; fa bigint;
  v1 bigint; v2 bigint; v3 bigint;
  s1 bigint; s2 bigint; s3 bigint;
  a1 bigint; a2 bigint; a3 bigint; aid bigint;
  fm record; an record;
  i int; r double precision; k int; q int; dd int; m text;
  methods text[] := array['GCash','Maya','PayPal'];
  people text[] := array['Ruben Alvarez','Maria Cruz','Jose Reyes','Ana Lopez'];
  store_names text[] := array['Bunawan AgriVet Supply','Green Valley Agri-Vet','Farm & Vet Mart'];
  vet_names text[] := array['Dr. Maria Santos, DVM','Tech. Carlo Reyes','Dr. Paolo Lim, DVM'];
  vet_fees double precision[] := array[350,200,400];
  item_names text[] := array['Ivermectin (dewormer)','Newcastle vaccine','Iron dextran','Hog cholera vaccine','Vitamin B-complex'];
  item_prices double precision[] := array[180,260,150,320,95];
begin
  if exists (select 1 from public.users) then
    raise exception 'Already seeded. Run the "Start over" steps in supabase-and-maya-guide.md first.';
  end if;
  perform setseed(0.7);

  -- ---- the 4 test accounts (login = username@anicare.app)
  insert into public.users (auth_id, username, full_name, display, phone, place, role, active, created)
  values (public._seed_auth('ruben.farmer@anicare.app', pw), 'ruben.farmer', 'Ruben Alvarez', 'Mang Ruben', '9171234567', 'Poblacion, Bunawan', 'raiser', 1, public._ms(0)) returning id into ruben;
  insert into public.users (auth_id, username, full_name, display, phone, place, role, active, created)
  values (public._seed_auth('maria.vet@anicare.app', pw), 'maria.vet', 'Maria Santos', 'Dr. Maria Santos', '9181234567', 'Poblacion, Bunawan', 'vet', 1, public._ms(0)) returning id into maria;
  insert into public.users (auth_id, username, full_name, display, phone, place, role, active, created)
  values (public._seed_auth('bunawan.store@anicare.app', pw), 'bunawan.store', 'Bunawan AgriVet Supply', 'Bunawan AgriVet Supply', '9191234567', 'Poblacion, Bunawan', 'store', 1, public._ms(0)) returning id into shop;
  insert into public.users (auth_id, username, full_name, display, phone, place, role, active, created)
  values (public._seed_auth('admin@anicare.app', pw), 'admin', 'AniCare Admin', 'AniCare Admin', '9170000000', 'Poblacion, Bunawan', 'admin', 1, public._ms(0)) returning id into adm;

  -- ---- vets
  insert into public.vets (user_id, name, kind, about, photo, license, km, fee, rating, services, plan_until)
  values (maria, 'Dr. Maria Santos, DVM', 'Veterinarian', 'Swine and poultry health. Farm visits within Bunawan.', 'assets/img/doctor.jpg', '', 1.2, 350, 4.9, 'Farm visit,Vaccination,Pregnancy check', public._ms(30)) returning id into v1;
  insert into public.vets (user_id, name, kind, about, photo, license, km, fee, rating, services, plan_until)
  values (null, 'Tech. Carlo Reyes', 'Animal Technician', 'Vaccination, deworming and basic care for goats and hogs.', 'assets/img/doctor_3.jpg', '', 2.8, 200, 4.7, 'Vaccination,Deworming,Hoof care', public._ms(30)) returning id into v2;
  insert into public.vets (user_id, name, kind, about, photo, license, km, fee, rating, services, plan_until)
  values (null, 'Dr. Paolo Lim, DVM', 'Veterinarian', 'Large animal and flock health programs.', 'assets/img/doctor_2.jpg', '', 4.5, 400, 4.8, 'Farm visit,Flock program,Emergency', public._ms(30)) returning id into v3;

  -- ---- stores + products (with expiry dates)
  insert into public.stores (user_id, name, address, photo, km, plan_until)
  values (shop, 'Bunawan AgriVet Supply', 'Poblacion, Bunawan', 'assets/img/store1.jpg', 0.9, public._ms(30)) returning id into s1;
  insert into public.stores (user_id, name, address, photo, km, plan_until)
  values (null, 'Green Valley Agri-Vet', 'Consuelo, Bunawan', 'assets/img/store2.jpg', 3.1, public._ms(30)) returning id into s2;
  insert into public.stores (user_id, name, address, photo, km, plan_until)
  values (null, 'Farm & Vet Mart', 'Imelda, Bunawan', 'assets/img/store1.jpg', 5.4, public._ms(30)) returning id into s3;

  insert into public.products (store_id, name, cat, price, stock, img, expiry) values
   (s1, 'Ivermectin (dewormer)', 'Dewormer', 180, 24, 'assets/img/worm1.jpg', public._ms(300)),
   (s1, 'Newcastle vaccine (100 doses)', 'Vaccine', 260, 12, 'assets/img/vaccine.jpg', public._ms(18)),
   (s1, 'Iron dextran injection', 'Supplement', 150, 18, 'assets/img/vaccine2.jpg', public._ms(300)),
   (s2, 'Hog cholera vaccine', 'Vaccine', 320, 8, 'assets/img/vaccine2.jpg', public._ms(150)),
   (s2, 'Vitamin B-complex', 'Supplement', 95, 30, null, public._ms(300)),
   (s2, 'Electrolytes (poultry)', 'Supplement', 70, 40, null, public._ms(300)),
   (s2, 'Gumboro vaccine (100 doses)', 'Vaccine', 280, 25, 'assets/img/vaccine.jpg', public._ms(90)),
   (s3, 'Albendazole (dewormer)', 'Dewormer', 120, 0, 'assets/img/worm2.jpg', public._ms(300)),
   (s3, 'Oxytetracycline', 'Antibiotic', 210, 15, null, public._ms(300)),
   (s3, 'Ivermectin (dewormer)', 'Dewormer', 175, 10, 'assets/img/worm3.jpg', public._ms(300)),
   (s3, 'Newcastle vaccine (100 doses)', 'Vaccine', 255, 3, 'assets/img/vaccine.jpg', public._ms(-5));

  -- ---- Ruben's animals
  insert into public.animals (owner_id, name, breed, species, flock, heads, photo)
  values (ruben, 'Native Chickens – Batch 3', 'Native', 'poultry', 1, 120, 'assets/img/chickens.jpg') returning id into a1;
  insert into public.schedules (animal_id, label, due, done) values
    (a1, 'Newcastle disease vaccine', public._ms(2), 0), (a1, 'Gumboro vaccine', public._ms(15), 0), (a1, 'Deworming', public._ms(40), 1);
  insert into public.records (animal_id, at, title, note, author)
  values (a1, public._ms(-20), 'Vaccination', 'Newcastle booster given. Flock healthy.', 'Tech. Carlo Reyes');
  insert into public.expenses (animal_id, at, item, amount) values
    (a1, public._ms(-25), 'Starter feed (5 sacks)', 4250), (a1, public._ms(-20), 'Vaccine', 260);

  insert into public.animals (owner_id, name, breed, species, flock, heads, photo)
  values (ruben, 'Bella', 'Boer cross', 'goat', 0, 1, 'assets/img/goat.jpg') returning id into a2;
  insert into public.schedules (animal_id, label, due, done) values
    (a2, 'Deworming', public._ms(5), 1), (a2, 'CD&T vaccine', public._ms(21), 0);
  insert into public.records (animal_id, at, title, note, author)
  values (a2, public._ms(-45), 'Check-up', 'Good body condition. Hooves trimmed.', 'Dr. Maria Santos, DVM');
  insert into public.expenses (animal_id, at, item, amount) values (a2, public._ms(-10), 'Dewormer', 180);

  insert into public.animals (owner_id, name, breed, species, flock, heads, photo)
  values (ruben, 'Sow “Rosa”', 'Landrace', 'hog', 0, 1, 'assets/img/pig.jpg') returning id into a3;
  insert into public.schedules (animal_id, label, due, done) values
    (a3, 'Hog cholera vaccine', public._ms(1), 0), (a3, 'Deworming', public._ms(30), 0);
  insert into public.expenses (animal_id, at, item, amount) values (a3, public._ms(-5), 'Feed (2 sacks)', 2400);

  -- ---- sample farmers in other barangays (no login, the admin can manage them)
  i := 0;
  for fm in select * from (values
      ('maria.cruz','Maria Cruz','Consuelo, Bunawan','9175550101'),
      ('jose.reyes','Jose Reyes','Imelda, Bunawan','9185550202'),
      ('ana.lopez','Ana Lopez','Libertad, Bunawan','9195550303')) as t(u, n, p, ph)
  loop
    insert into public.users (auth_id, username, full_name, display, phone, place, role, active, created)
    values (null, fm.u, fm.n, null, fm.ph, fm.p, 'raiser', 1, public._ms(0)) returning id into fa;
    for an in
      select * from (values
        ('maria.cruz','Native Hens','poultry','Native',1,60),('maria.cruz','Biik','hog','Duroc',0,1),
        ('jose.reyes','Boer Goats','goat','Boer',1,8),
        ('ana.lopez','Sow “Nene”','hog','Landrace',0,1),('ana.lopez','Broilers','poultry','Cobb',1,200)
      ) as x(u, n, sp, br, fl, hd) where x.u = fm.u
    loop
      insert into public.animals (owner_id, name, breed, species, flock, heads, photo)
      values (fa, an.n, an.br, an.sp, an.fl, an.hd, null) returning id into aid;
      if an.sp = 'hog' then
        insert into public.schedules (animal_id, label, due, done) values
          (aid,'Iron injection',public._ms(-10),(i+0)%2),(aid,'Hog cholera vaccine',public._ms(2),(i+1)%2),(aid,'Deworming',public._ms(14),(i+2)%2);
      elsif an.sp = 'poultry' then
        insert into public.schedules (animal_id, label, due, done) values
          (aid,'Newcastle disease vaccine',public._ms(-10),(i+0)%2),(aid,'Gumboro vaccine',public._ms(2),(i+1)%2),(aid,'Deworming',public._ms(14),(i+2)%2);
      else
        insert into public.schedules (animal_id, label, due, done) values
          (aid,'Deworming',public._ms(-10),(i+0)%2),(aid,'CD&T vaccine',public._ms(2),(i+1)%2),(aid,'Hoof check',public._ms(14),(i+2)%2);
      end if;
      insert into public.expenses (animal_id, at, item, amount) values (aid, public._ms(-8), 'Feed', 1500 + i * 400);
      i := i + 1;
    end loop;
  end loop;

  -- ---- Ruben's bookings
  insert into public.bookings (raiser_id, raiser_name, vet_id, animal_id, animal_name, reason, day, slot, fee, urgent, status, r_confirm, v_confirm, method, rating) values
   (ruben, 'Ruben Alvarez', v1, a3, 'Sow “Rosa”', 'Hog cholera vaccination', public._ms(1), '9:00 AM', 350, 0, 'pending', 0, 0, 'GCash', null),
   (ruben, 'Ruben Alvarez', v1, a2, 'Bella', 'Goat check-up', public._ms(3), '2:00 PM', 350, 0, 'accepted', 0, 0, 'Maya', null),
   (ruben, 'Ruben Alvarez', v2, a1, 'Native Chickens – Batch 3', 'Flock vaccination', public._ms(-20), '10:00 AM', 200, 0, 'completed', 1, 1, 'GCash', 5);

  -- the triggers announced every seeded product: start with an empty notification list
  delete from public.notifications;
end $$;

drop function public._seed_auth(text, text);
drop function public._ms(integer);
