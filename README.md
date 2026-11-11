# AniCare v5.0.0 (Flutter, Android)

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

## Database (new)
All data is stored on the phone in **SQLite** (package `sqflite`), file `anicare.db`:
users, vets, stores, products, animals, schedules, records, expenses, bookings, reservations, settings.
- Passwords are stored as salted SHA-256 hashes, never as text.
- The light/dark choice and the logged-in session are saved too (the app stays logged in).
- First launch creates the database and the 3 test accounts + sample data.
- To start over: uninstall the app (or Settings > Apps > AniCare > Storage > Clear data).
Code: `lib/db.dart` (schema + seed + hashing), `lib/data.dart` (models + app state, saves every change).

## Test accounts (password for all: AniCare2987!)
ruben.farmer (farmer) | maria.vet (vet) | bunawan.store (store). Tap the username box on the login screen to autofill one.

## Flow
Splash -> Welcome (Get started / About) -> Login (or Create Account) -> the user's menu.
- Farmer: Home, Animals, Find, Bookings. Vet: Dashboard, Bookings. Store: Inventory, Reservations, Plan (39/month).
- Create Account: 3 roles with extra fields (farm location / license + fee + type / store name + address).
- The About page (with database + version info) opens from the Welcome and Login screens. The LGU stats pages were removed.
- Golden-hour background on Welcome, Login, Create Account and About (light mode); menus keep the rice-field photos.

## Files
lib/db.dart, data.dart (database + state) | auth.dart (splash, welcome, login, create account, stats/about, payment)
raiser.dart (farmer) | vet.dart (vet + store) | ui.dart (theme + shared widgets)
