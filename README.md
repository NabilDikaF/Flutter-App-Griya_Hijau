# Griya Hijau — PT Rindang Alam

Android-only Flutter and Supabase monorepo for **Griya Hijau** (**PT Rindang Alam**), consisting of a Customer application for property discovery and booking requests, an Admin application for catalog, CRM, and analytics management, and a shared Dart/Flutter package.

---

## Table of Contents

- [Project Overview](#project-overview)
- [Key Features](#key-features)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Requirements](#requirements)
- [Installation and Setup](#installation-and-setup)
- [Environment Configuration](#environment-configuration)
- [Supabase Setup](#supabase-setup)
- [Running the Application](#running-the-application)
- [Testing and Code Analysis](#testing-and-code-analysis)
- [Build Application](#build-application)
- [Security Notes](#security-notes)
- [License](#license)

---

## Project Overview

Griya Hijau digitizes property marketing and lead handling for residential housing and shophouses (*ruko*):

- **Prospective buyers** browse published properties, filter by category, location, price range, and availability, simulate KPR monthly installments, request property surveys or unit bookings without creating an account, and track booking status.
- **Internal admins** manage property listings, photos, master categories and locations, track customer leads through a 6-stage booking funnel, and monitor view and search demand analytics.

---

## Key Features

### Customer Application (`apps/app_customer`)

- **Home**: Hero search bar, category quick filters, location selector (`AppDropdown`), and featured published properties.
- **Property Catalog**: Debounced keyword search, category chips, bottom sheet filters (location, price range presets, availability status), sorting (`Terbaru`, `Harga Termurah`, `Harga Termahal`), and paginated loading via `search_properties` RPC.
- **Property Detail**: Zoomable photo gallery (`photo_view`), 8 unit specifications, read-only view count with automatic deduplicated tracking (`record_property_view`), embedded Google Maps with external directions launch, and interactive KPR simulator with official disclaimer.
- **Booking & Confirmation**: Submit survey schedules (`survey_location`) or unit reservations (`book_unit`) via `create_booking` RPC with `628xxx` WhatsApp validation, generated booking code (`BK-YYYYMMDD-...`), and WhatsApp handoff.
- **Check Booking Status**: Dual-factor booking lookup requiring both booking code and WhatsApp number (`check_booking_status` RPC).
- **About Company**: Brand story, vision, mission, highlights, and office contact via WhatsApp.

### Admin Application (`apps/app_admin`)

- **Authentication & Role Guard**: Supabase email/password sign-in restricted to accounts with `app_metadata.role = 'admin'`, encrypted session persistence via Android Keystore (`flutter_secure_storage`), auth state listener, startup server verification, and `FLAG_SECURE` enabled on non-debuggable Android builds.
- **Market Research Dashboard**: 7/30/90-day period filter, KPI cards via server-side admin RPCs (`admin_dashboard_summary`, `admin_upcoming_surveys`), view trend line chart (`fl_chart`), top properties, most-searched districts/categories/keywords, and upcoming confirmed surveys.
- **Property Management**: Create/edit properties with auto-slug generation, read-only `views_count` display, publish/draft toggle, availability updates (`available`, `booked`, `sold`), interactive map coordinate picker, client-side JPEG compression in an isolate (`<= 1600px`, `< 1 MB`) uploaded with random UUID object names, primary photo selection, and safe delete (hard delete + Storage cleanup when unbooked, automatic draft deactivation when bookings exist).
- **Booking Leads CRM**: Server-side filtered and paginated leads (`admin_list_bookings` RPC), debounced search, 6-stage funnel status updates (`new`, `contacted`, `survey_scheduled`, `office_visit`, `closed_won`, `closed_lost`), survey confirmation timestamp, admin notes (`maxLength: 2000`), and WhatsApp customer contact.
- **Master Data**: CRUD for property categories (including `is_active` catalog visibility toggle) and districts/cities (`locations`).

### Shared Package (`packages/shared`)

- **Schema-Aligned Models & Enums**: `Property`, `PropertyInput` (intentionally omits `views_count`), `PropertyImage`, `PropertyCategory`, `Location`, `Booking`, `PropertyViewLog`, `SearchLog`, and enum mappers (`AvailabilityStatus`, `IntentType`, `PaymentPlan`, `FunnelStatus`).
- **UI & Design System**: Material 3 light theme (`AppTheme`, `AppColors`, `AppSpacing`, `AppTypography`) and reusable widgets (`AppDropdown`, `PropertyCard`, `KprCalculatorCard`, `AsyncStateView`, status/spec badges).
- **Utilities & Offline Seed Data**: Annuity KPR calculator (`KprCalculator`), number/currency/date formatters, `CompanyConfig` constants, and unmodifiable `SeedData` for offline debug/widget testing.

---

## Tech Stack

| Layer | Technology |
| --- | --- |
| Framework & Target | Flutter (Android) |
| Language | Dart (`^3.14.0` apps, `^3.13.5` `packages/shared`) |
| UI & Visualization | `material_ui`, `fl_chart`, `photo_view` |
| State Management | `flutter_riverpod` |
| Navigation | `go_router` |
| Backend & Database | `supabase_flutter`, PostgreSQL (RLS, RPC functions, Storage) |
| Secure Storage | `flutter_secure_storage` (`apps/app_admin` Android Keystore) |
| Maps & Media | `google_maps_flutter`, `image_picker`, `image`, `url_launcher` |
| Formatting | `intl` |
| Android Build | Gradle Kotlin DSL, Java 17, R8/ProGuard |

---

## Project Structure

```text
.
├── apps/
│   ├── app_customer/        # Customer-facing Android application (id.rindangalam.customer)
│   └── app_admin/           # Admin Android application (id.rindangalam.admin)
├── packages/
│   └── shared/              # Shared models, theme, KPR calculator, and UI widgets
└── supabase/
    ├── migrations/          # Ordered PostgreSQL schema, RLS, Storage, RPC, and hardening SQL migrations
    ├── seed.sql             # Idempotent development seed data
    └── tests/               # Transactional rollback SQL test suite (rls_and_acceptance_test.sql)
```

---

## Requirements

- **Flutter SDK**: `stable` channel compatible with Dart `^3.14.0` *(exact pinned Flutter SDK version: needs confirmation — no `.fvmrc` or version pin file exists in the repository)*.
- **Dart SDK**: `^3.14.0` (required by `apps/app_customer` and `apps/app_admin`; `packages/shared` requires `^3.13.5`).
- **Android Studio / Android SDK** and **Java JDK 17** (`JavaVersion.VERSION_17` configured in `android/app/build.gradle.kts`).
- **Git**.
- **Supabase Cloud Project** (PostgreSQL + Auth + Storage).
- **Google Cloud Project with Maps SDK for Android** (optional if `DISABLE_GOOGLE_MAPS=true` is used; external Google Maps links and coordinate pickers remain functional).

---

## Installation and Setup

This repository does **not** use Melos or Dart pub workspaces; dependencies are resolved per package.

1. **Clone the repository**

   ```powershell
   git clone <repository-url>
   ```

2. **Navigate into the project directory**

   ```powershell
   cd <repository-folder>
   ```

3. **Install dependencies for each package**

   ```powershell
   cd packages\shared
   flutter pub get

   cd ..\..\apps\app_customer
   flutter pub get

   cd ..\app_admin
   flutter pub get
   ```

4. **Configure local environment variables** (see [Environment Configuration](#environment-configuration)).
5. **Provision Supabase schema, Storage, and admin account** (see [Supabase Setup](#supabase-setup)).
6. **Run Customer App** from `apps/app_customer` (see [Running the Application](#running-the-application)).
7. **Run Admin App** from `apps/app_admin` (see [Running the Application](#running-the-application)).

---

## Environment Configuration

Both Flutter apps read runtime configuration via **compile-time `--dart-define`** (or `--dart-define-from-file`) in `lib/core/env_config.dart` — they do **not** load `.env` files at runtime. In addition, the Android Google Maps SDK reads `MAPS_API_KEY` from each app's `android/local.properties`.

1. Copy the template file to a local `.env` file (ignored by Git):

   ```powershell
   Copy-Item .env.example .env
   ```

2. Replace the values in `.env` with your own Supabase project values.

> **Note:** Check `.env.example` before sharing or committing changes; make sure you use your own Supabase project URL and publishable/anon key locally. `MAPS_API_KEY` and `DISABLE_GOOGLE_MAPS` are supported by `EnvConfig`, though they are not yet listed in `.env.example`.

| Variable | Required | Mechanism | Description |
| --- | --- | --- | --- |
| `SUPABASE_URL` | Required in release (must be `https://...`) | `--dart-define` / `.env` | Base HTTPS URL of your Supabase project |
| `SUPABASE_ANON_KEY` | Required in release | `--dart-define` / `.env` | Public anon/publishable key of your Supabase project |
| `MAPS_API_KEY` | Optional | `--dart-define` & `android/local.properties` | Google Maps SDK for Android API key |
| `DISABLE_GOOGLE_MAPS` | Optional (`false` by default) | `--dart-define` | Set to `true` to disable embedded Google Maps widgets |

> **Company defaults (`packages/shared/lib/config/company_config.dart`):** Placeholder office contact values (`officeAddress`, `officeWhatsapp`, `officePhoneDisplay`) are still present in source and **need confirmation** before production release.

---

## Supabase Setup

`supabase/config.toml` is **not** present in this repository, so a local Docker Supabase CLI runtime (`supabase start`) is not pre-configured here. Setup targets **Supabase Cloud** using your own project credentials from the Supabase Dashboard.

1. **Apply SQL migrations in order**
   Run all migration files in `supabase/migrations/` in ascending timestamp order via your Supabase Dashboard **SQL Editor** (or link your own project with the Supabase CLI and run `supabase db push`):
   - `20261114000001_init_schema.sql` through `20261122000010_security_remediation_stage1.sql`.
2. **Load development seed data (optional)**
   `20261114000005_seed_data.sql` seeds initial data during migration, and `supabase/seed.sql` provides an idempotent SQL script for local/development re-seeding.
3. **Create the first Admin account**
   - Keep **public signups disabled** in Supabase Auth settings.
   - Create an admin user manually in **Supabase Dashboard → Authentication → Users**.
   - Grant the admin role claim in `auth.users` via the Supabase SQL Editor (replace `<admin-email>` with your admin user's email):

     ```sql
     update auth.users
        set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || '{"role": "admin"}'::jsonb
      where email = '<admin-email>';
     ```

4. **Verify Storage bucket**
   Ensure the `property-images` bucket and admin/public policies created by the migrations are active in **Storage**.

---

## Running the Application

> **Debug vs Release behavior:** In debug mode without `--dart-define`, both apps run offline using local `SeedData`. In release builds, both apps are **fail-closed** and require valid `SUPABASE_URL` (`https://...`) and `SUPABASE_ANON_KEY`.

### Run Customer App (`apps/app_customer`)

```powershell
cd apps\app_customer
flutter run `
  --dart-define=SUPABASE_URL=https://<your-project-ref>.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=<your-supabase-anon-key> `
  --dart-define=MAPS_API_KEY=<your-google-maps-api-key>
```

Or pass values from the root `.env` file:

```powershell
cd apps\app_customer
flutter run --dart-define-from-file=..\..\.env --dart-define=MAPS_API_KEY=<your-google-maps-api-key>
```

### Run Admin App (`apps/app_admin`)

```powershell
cd apps\app_admin
flutter run `
  --dart-define=SUPABASE_URL=https://<your-project-ref>.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=<your-supabase-anon-key> `
  --dart-define=MAPS_API_KEY=<your-google-maps-api-key>
```

If running without a Google Maps key, append `--dart-define=DISABLE_GOOGLE_MAPS=true`.

---

## Testing and Code Analysis

### Static Analysis (`dart analyze`)

From the repository root (or inside each package directory):

```powershell
dart analyze packages\shared apps\app_customer apps\app_admin
```

### Flutter Unit & Widget Tests (`flutter test`)

Run tests per package:

```powershell
cd packages\shared
flutter test

cd ..\..\apps\app_customer
flutter test

cd ..\app_admin
flutter test
```

### Supabase SQL Security & Acceptance Tests

Execute `supabase/tests/rls_and_acceptance_test.sql` in your Supabase Dashboard **SQL Editor**. The script wraps assertions inside `BEGIN; ... ROLLBACK;` so test rows do not persist.

---

## Build Application

Release builds enforce lockfiles (`--enforce-lockfile`), R8 minification/resource shrinking, and Android release signing via each app's gitignored `android/key.properties` file (see `apps/app_customer/android/key.properties.example` and `apps/app_admin/android/key.properties.example` for the expected property keys, without committing real passwords or keystores).

If Android embedded Google Maps is enabled, also set `MAPS_API_KEY=<your-google-maps-api-key>` in `apps/<app>/android/local.properties`.

### Build Customer App

```powershell
cd apps\app_customer
flutter pub get --enforce-lockfile
flutter build apk --release `
  --dart-define=SUPABASE_URL=https://<your-project-ref>.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=<your-supabase-anon-key> `
  --dart-define=MAPS_API_KEY=<your-google-maps-api-key>
```

For Android App Bundle (`.aab`), replace `flutter build apk --release` with `flutter build appbundle --release`.

### Build Admin App

```powershell
cd apps\app_admin
flutter pub get --enforce-lockfile
flutter build apk --release `
  --dart-define=SUPABASE_URL=https://<your-project-ref>.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=<your-supabase-anon-key> `
  --dart-define=MAPS_API_KEY=<your-google-maps-api-key>
```

For Android App Bundle (`.aab`), replace `flutter build apk --release` with `flutter build appbundle --release`.

> **Local test build without a release keystore (do not distribute):** Gradle blocks unsigned/debug-signed release builds by default. For local-only testing without `key.properties`, pass `ORG_GRADLE_PROJECT_ALLOW_DEBUG_SIGNING=true` (or `-PALLOW_DEBUG_SIGNING=true` with Gradle).

---

## Security Notes

- Never commit `.env` or any file containing live environment secrets.
- Never share or embed the Supabase `service_role` key in client applications or version control.
- Never commit release keystores (`*.jks`, `*.keystore`) or signing files (`android/key.properties`, `android/local.properties`).
- Keep Row Level Security (RLS), column-level privileges (`views_count`), and `app_metadata.role = 'admin'` checks enabled on all Supabase tables and RPCs.
- Use `.env.example` and `key.properties.example` strictly as templates.
- Both Android manifests disable cloud/device backups (`android:allowBackup="false"`, `fullBackupContent`, `dataExtractionRules`) and cleartext HTTP (`android:usesCleartextTraffic="false"`). The Admin app additionally enables `FLAG_SECURE` on release/non-debuggable builds and stores Supabase sessions in encrypted Android Keystore storage.

---

## License

No license file (`LICENSE`) exists in this repository yet, and license terms have not been defined *(needs confirmation from the project owner)*.
