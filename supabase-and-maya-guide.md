# AniCare 6.1.0 – Supabase + Maya sandbox guide

This guide covers: (A) turning on Supabase syncing, (B) the Maya sandbox payment test, (C) testing the notifications.

> ⚠️ The app code, the SQL and the server functions were written **without being able to connect to a real Supabase or Maya account**, so they are **untested live**. Follow the steps; if a step fails, copy the exact error text and send it to me.

## What 6.1.0 adds

- **Maya sandbox payments** for **vet bookings** and the **store plan (₱39)**. The Maya key sits in Supabase server functions, never in the app. Reservations still use the demo checkout.
- **Notifications** (phone + bell list): subscription bought, subscription ending in 7 days (with an *Extend plan* button), new product (all farmers), booking paid (vet), reservation (store), payment failed (payer), 5% fee recorded (admin).
- **Hidden Debug tab** for the admin (tap the AniCare logo 5 times).
- **Settings cog** next to the name of the farmer, vet and store owner (profile, username, password – old password is asked first).
- **Admin purchases show only real transactions** – the dummy purchase history is gone.
- Fixes: INTERNET permission in the release APK, the "wrong password" message when there is no internet, the logo corner, the white flash at logout.

## How money is handled (sandbox)

1. The farmer pays the **full amount** (visit fee + 2.5%) in Maya Checkout. Nothing real moves; it is the Maya sandbox.
2. The app records it in the **ledger** (`payments` table). When both sides confirm the visit, the ledger adds the **AniCare 5% fee** (the admin's) and the **vet's share** (marked *owed*).
3. **There are no real payouts.** The vet share is only a record.
4. Payments need internet. Without Supabase keys (offline mode) the old demo checkout is used instead.

---

# Part A – Supabase

## A1. Create the project (skip if you already have one)
1. <https://supabase.com> → **New project** → name `anicare`, region **Southeast Asia (Singapore)**, save the database password.
2. **Authentication → Sign In / Providers → Email** → turn **OFF** "Confirm email". Save.

## A2. Tables, security, starting data
**New project:** SQL Editor → run `supabase/schema.sql`, then `supabase/seed.sql` (once).
**Already ran the 6.0.0 scripts?** Run only `supabase/update-6.1.sql`. It adds the new tables/functions and **deletes the old dummy purchases**. Do not run `seed.sql` again.

Test logins (password for all `AniCare2987!`): `ruben.farmer`, `maria.vet`, `bunawan.store`, `admin`. If `seed.sql` fails on the login part, create the 4 users by hand (Authentication → Users → Add user → email `username@anicare.app`, **Auto Confirm User**), see the older notes at the end.

## A3. Put the URL and key in the app
`lib/config.dart`:
```dart
const String kSupabaseUrl = 'https://YOUR-PROJECT.supabase.co';
const String kSupabaseAnonKey = 'YOUR-ANON-OR-PUBLISHABLE-KEY';
```
Project Settings → API (or the **Connect** button). Use the anon / publishable key, **never** the service_role / secret key. The URL must be exactly `https://xxxx.supabase.co` (no `/rest/v1`, no spaces).

---

# Part B – Maya sandbox payments

## B1. Get the sandbox keys
Open <https://developers.maya.ph/reference/sandbox-credentials-and-cards>. It lists **public sandbox keys** (public key `pk-…` and secret key `sk-…`) and the **test wallet login and test cards**. They are shared with other developers, so never type real personal data in the test.

## B2. Deploy the 3 server functions
Dashboard → **Edge Functions** → **Deploy a new function** → **Via Editor**. Do this three times; the code is in the project folder:

| Function name (exact) | File to paste | Verify JWT |
|---|---|---|
| `maya-checkout` | `supabase/functions/maya-checkout/index.ts` | ON (default) |
| `maya-verify` | `supabase/functions/maya-verify/index.ts` | ON (default) |
| `maya-webhook` *(optional)* | `supabase/functions/maya-webhook/index.ts` | **OFF** (Maya has no login) |

Click **Deploy** for each.

## B3. Add the secrets
Edge Functions → **Secrets** (or *Manage secrets*) → add:

| Name | Value |
|---|---|
| `MAYA_PUBLIC_KEY` | the sandbox public key (`pk-…`) |
| `MAYA_SECRET_KEY` | the sandbox secret key (`sk-…`) |
| `MAYA_BASE_URL` *(optional)* | `https://pg-sandbox.paymaya.com` (this is the default) |

`SUPABASE_URL`, `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY` are provided to the functions automatically.

(Command-line alternative: `supabase functions deploy maya-checkout` … and `supabase secrets set MAYA_PUBLIC_KEY=… MAYA_SECRET_KEY=…`.)

## B4. Optional: webhook
Not needed for the basic test (the app asks the server after the Maya page closes). It only helps when the app was closed before the payment finished. Register the callback with Maya using the secret key – see Maya's "Configuring Your Webhook for Maya Checkout" page for the exact call; the callback URL is `https://YOUR-PROJECT.supabase.co/functions/v1/maya-webhook`.

## B5. How a payment works (for reference)
1. The app saves the booking as **unpaid** and calls `maya-checkout`. The server works out the amount, asks Maya for a checkout and writes a **pending** ledger line.
2. The app opens Maya's page inside the app. The farmer logs in with the **Maya test wallet** (or enters a test card) from the Maya page.
3. When Maya sends the browser back, the page closes by itself and the app calls `maya-verify`.
4. The server asks Maya for the status. **Paid** → ledger line becomes *held*, booking becomes *pending* (the vet now sees it) or the store plan gets **+30 days**. **Not paid** → ledger line *failed*, booking *cancelled*.

---

# Part C – Build and test

## C1. Build
```bash
cd anicare
./setup_and_build.sh      # makes AniCare-6.1.0.apk
```
The script now also runs `tool/patch_android.py`, which adds the INTERNET and notification permissions and the setting that notifications need. Install the APK on 2–3 phones (allow notifications when asked).

## C2. Tests
| Test | Steps | You should see |
|---|---|---|
| Maya booking | Farmer → Find → vet → Book → Continue | Maya page opens in the app; after paying it closes; "Paid with Maya…" |
| Vet gets it | Vet phone → pull down on Bookings | The paid booking, plus a "New paid booking" notification (within ~20 s while the app is open) |
| Failed payment | Pay with the Maya test wallet that fails | Booking cancelled, "Payment failed" notification |
| Store plan | Store owner → Plan → Renew early | Maya page; plan date +30 days; "Subscription active" notification; admin gets "Store subscription bought" |
| New product | Store → Add product | Every farmer gets "New product available" |
| 5% fee | Raiser and vet both press *Confirm completed* | Admin gets "AniCare fee recorded"; Purchases shows a *fee* line and a *Vet share (owed)* line |
| Plan ending | Run in SQL Editor: `update stores set plan_until = (extract(epoch from now() + interval '5 days')*1000)::bigint where id = 1;` then open the store account | "Subscription ending soon" notification and an "Extend plan" question |
| Debug tab | Log in as `admin`, tap the AniCare logo (top left) 5 times | A counter beside the logo (4, 3, 2, 1 taps), then a **Debug** tab with one button per notification type. It hides again at logout/restart |
| Settings | Tap the cog beside your name | Change name, phone, location (farmer), type/fee/license (vet), store name/address (store), username, password (old one first) |
| Admin data | Admin → Purchases | Only real transactions (the dummy history was removed) |

## C3. Notes on notifications
- Phone notifications appear when the app is **running** (foreground or background). Other phones' alerts arrive within about 20 seconds. When the app is fully closed nothing arrives (no push server in this version).
- The bell list always has everything; pull down to refresh.

---

## Where things are in the code

| What | File |
|---|---|
| **URL + key** | `lib/config.dart` |
| Supabase calls, server-function calls, password change | `lib/repo.dart` |
| Notifications, ledger, settings, debug taps | `lib/data.dart` (`AppState`) |
| Phone notifications | `lib/notify.dart` |
| Maya page + `payMaya()` | `lib/auth.dart` |
| Bell list / Settings screens | `lib/notifications.dart`, `lib/settings.dart` |
| Debug tab, admin screens | `lib/admin.dart` |
| Server functions | `supabase/functions/*/index.ts` |
| Tables, security, triggers | `supabase/schema.sql` (new) / `supabase/update-6.1.sql` (existing project) |
| Android permissions + gradle fix | `tool/patch_android.py` |

## Start over (wipe and seed again)
```sql
truncate public.notifications, public.payments, public.reservations, public.bookings, public.expenses,
         public.records, public.schedules, public.animals, public.products,
         public.stores, public.vets, public.users restart identity cascade;
delete from auth.users where email like '%@anicare.app';
```
Then run `seed.sql` again.

## Troubleshooting
| Message / problem | Fix |
|---|---|
| *Could not start the Maya checkout: MAYA_PUBLIC_KEY is not set* | Add the secrets (B3). |
| *Maya refused the checkout* | The key is wrong, or Maya changed the request. Send me the message. |
| *Could not start the Maya checkout: Requested function was not found* | The function name is not exactly `maya-checkout`. |
| Payment done but app says not completed | The status call may differ from what I assumed. In Edge Functions → `maya-verify` → Logs, look at the response; send it to me. |
| *No internet connection* at login | The phone cannot reach Supabase. Check the URL in `config.dart`; rebuild after changing it. |
| Build error mentioning *desugaring* | The patch script could not edit `android/app/build.gradle(.kts)`. Add `isCoreLibraryDesugaringEnabled = true` under `compileOptions` and `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")` under `dependencies`. |
| No phone notifications | Allow notifications for AniCare in the phone settings (Android 13+ asks once). |
| `new row violates row-level security policy` | Run the SQL again (`update-6.1.sql`), or the "Start over" block then `schema.sql` and `seed.sql`. |
| Free project paused | Open the Supabase dashboard and press **Restore**. |

## Not included
Real payouts, refunds, push notifications while the app is closed, photo upload, and Maya for product reservations.
