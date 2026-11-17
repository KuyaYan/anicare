# AniCare v6.1.0 (Flutter, Android)

Connecting Farmers to Animal Care. School pitch prototype - works offline, payments are mocked.

## Build the APK (Linux Mint / any PC with Flutter + Android SDK)
```bash
unzip anicare_flutter.zip && cd anicare
./setup_and_build.sh
```
Creates the android/ folder, sets the app name + launcher icon, enables phone back-button handling,
then runs `flutter build apk --release` and copies the result to `AniCare-<version>.apk` (version from pubspec.yaml, e.g. `AniCare-5.0.0.apk`).
When you change the version, also update `kVersion` in `lib/ui.dart` (shown on the About page).
To test on a phone first: `flutter pub get && flutter run`.

## Database
- **Offline mode (default):** everything is stored on the phone in SQLite (`anicare.db`).
- **Supabase mode:** put your project URL + anon key in `lib/config.dart` -> phones sync (pull down to refresh).
  Full steps: `supabase-and-maya-guide.md` (SQL scripts and server functions in `supabase/`).
- Passwords: local mode = salted SHA-256 hash; Supabase mode = Supabase Auth.

## Test accounts (password for all: AniCare2987!)
ruben.farmer (farmer) | maria.vet (vet) | bunawan.store (store) | admin (admin). Tap the username box on the login screen to autofill one.

## Flow
Splash -> Welcome (Get started / About) -> Login (or Create Account) -> the user's menu.
- Farmer: Home, Animals, Find, Bookings. Vet: Dashboard, Bookings. Store: Inventory, Reservations, Plan (39/month).
- Create Account: 3 roles with extra fields (farm location / license + fee + type / store name + address).
- The About page (with database + version info) opens from the Welcome and Login screens. The LGU stats pages were removed.
- Golden-hour background on Welcome, Login, Create Account and About (light mode); menus keep the rice-field photos.

## Files
lib/db.dart, data.dart (database + state) | auth.dart (splash, welcome, login, create account, stats/about, payment)
raiser.dart (farmer) | vet.dart (vet + store) | ui.dart (theme + shared widgets)

## New in 6.1.0
- Maya sandbox payments (bookings + store plan) through Supabase server functions; ledger records the 5% admin fee and the vet's owed share (no real payouts).
- Notifications (phone + bell list), hidden admin Debug tab (tap the logo 5 times), settings cog, 7-day plan reminder.
- Admin purchases show only real transactions (dummy data removed).
- Fixes: INTERNET permission, misleading login error, logo corner, logout flash.

## New in 6.0.0
- Password rule on Create Account (8-32 chars, letter + number + symbol, no spaces) with a live checklist.
- Admin account: LGU animals-tracked data, purchases (4 kinds, 30-day totals/chart/table, CSV export),
  vaccine stock (low-stock + expiry warnings), accounts (masked names/phones, edit, deactivate, reset password).
- Supabase sync (optional), pull-to-refresh on every list.
