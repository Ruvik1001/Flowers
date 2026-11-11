# Flowers Frontend (Android)

Staff client for the Flowers shop management system. Talks to the backend gateway at `/api/v1`.

## Stack

- Flutter 3.32+ / Dart ^3.8.1
- BLoC (`flutter_bloc`)
- Dio + secure token storage
- go_router
- Localization: `ru` (default), `en` optional

## Setup

```bash
cd frontend
flutter pub get
```

## Run (Android emulator)

Backend must be up on the host (`backend/` docker local → port `8080`).

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

Physical device on the same LAN:

```bash
flutter run --dart-define=API_BASE_URL=http://<host-lan-ip>:8080
```

Default bootstrap admin (from backend): `admin@flowers.local` / `admin12345`

## Structure

```
lib/
  app/           # DI, theme, router, shell
  core/          # network, auth storage, errors
  features/      # auth, catalog, procurement, inventory, sales,
                 # cashier, assembly, files, analytics, audit, admin
  l10n/
```

## Branching

Work on the `frontend` integration line. Feature branches: `feat/...` (Git cannot nest `frontend/feat-*` under an existing `frontend` branch ref).
