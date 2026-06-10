# CLAUDE.md — MAC1 Project Context

## Project Overview

MAC1 is a gig-economy home-services marketplace app. Customers book tradespeople (plumbers, electricians, cleaners, HVAC techs) nearby. Workers receive job requests, accept/reject them, and complete bookings. An admin panel provides oversight and basic analytics. A rule-based conversational AI chatbot helps customers find workers.

Three user roles: **customer**, **worker**, **admin**.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Backend | Python 3.11, FastAPI, SQLAlchemy ORM, Uvicorn |
| Database | SQL (URL from `.env` via `DB_URL`) |
| Push notifications | Firebase Admin SDK (FCM) |
| Frontend | Flutter / Dart (SDK ^3.8.1) |
| Firebase (Flutter) | `firebase_core`, `firebase_messaging` |
| Charts | `fl_chart` |
| Location | `geolocator`, `geocoding` |
| HTTP | `http` package |
| Local storage | `shared_preferences` |
| Local notifications | `flutter_local_notifications` |

---

## Directory Structure

```
C:\Mac1\
├── backend/
│   ├── main.py               # FastAPI app entry point; registers all routers
│   ├── database.py           # SQLAlchemy engine + session (DB_URL from .env)
│   ├── models.py             # ORM models: User, Worker, Booking, Rating, JobRequest
│   ├── services.py           # Haversine distance calc; get_workers_by_skill()
│   ├── notifications.py      # Firebase Admin push helpers (send_to_token, multicast, topic)
│   ├── utils.py              # calc_distance utility
│   ├── firebase_admin.json   # Firebase service account key (NOT in git)
│   ├── .venv/                # Python virtual environment
│   └── routers/
│       ├── auth.py           # /auth/signup, /auth/login, /auth/update_token
│       ├── workers.py        # Worker CRUD, ratings, leaderboard, wallet, pending/completed jobs
│       ├── customers.py      # Customer profile, upcoming jobs, accepted workers
│       ├── jobs.py           # Job requests, booking creation, booking completion, payslip summary
│       ├── admin.py          # Admin CRUD for users/workers/bookings, revenue, stats, warn worker
│       └── convai.py         # Rule-based chatbot state machine (/convai/message, /convai/reset)
├── frontend/
│   └── mac1_app/
│       ├── lib/
│       │   ├── main.dart              # App entry point; ThemeData; all named routes via onGenerateRoute
│       │   ├── config/api_config.dart # Backend URL management (SharedPreferences; default hardcoded)
│       │   ├── firebase_options.dart  # Generated Firebase config
│       │   ├── models/                # WorkerProfile, CustomerProfile, AcceptedWorker
│       │   ├── services/              # ApiService (REST calls), location_service, notification, etc.
│       │   └── Pages/                 # All UI screens (see list below)
│       ├── pubspec.yaml
│       └── assets/icons/app_icon.png
├── tasks/
│   ├── todo.md        # Active redesign task list
│   ├── memory.md      # Project memory snapshot (redesign progress)
│   └── lessons.md     # Lessons learned log
└── .env               # DB_URL and secrets (not committed)
```

### Pages (`lib/Pages/`)

| File | Role |
|---|---|
| `Loginpage.dart` | Login screen |
| `Signuppage.dart` | Signup with role selection |
| `customerhomepage.dart` | Customer home: service categories, booking actions |
| `CustomerUpcomingBookingsPage.dart` | Customer's pending bookings |
| `customercompletedjobs.dart` | Customer's completed jobs list |
| `accepted_workers_full.dart` | Workers who accepted customer's job requests |
| `service_workers.dart` | Browse workers by skill near customer |
| `booking.dart` | Confirm and create a booking |
| `jobrequest.dart` | Send a job request to a specific worker |
| `incoming_request.dart` | Worker sees incoming job requests (accept/reject) |
| `WorkersHP.dart` | Worker home page |
| `WorkerInfoPage.dart` | Worker profile setup/view |
| `pendingJobs.dart` | Worker's pending bookings |
| `WorkerCompletedBookingsPage.dart` | Worker's completed bookings |
| `Completed_jobs_page.dart` | Mark a booking as complete (enter time/extras) |
| `finalPaySlip.dart` | Booking payslip breakdown |
| `Rating.dart` | Rate a worker after job completion |
| `wallet.dart` | Worker earnings and transaction history |
| `admin_dashboard.dart` | Admin panel: users, workers, bookings, stats |
| `chatbot.dart` | Conversational AI chatbot UI |
| `settings_page.dart` | App settings including backend URL override |

---

## Key Files and What They Do

- **`backend/main.py`** — Creates DB tables on startup, registers all 6 routers.
- **`backend/models.py`** — Core schema. `Booking.status` cycles: `"pending"` → `"completed"`. 10% commission deducted from worker earnings in `jobs.py`.
- **`backend/routers/convai.py`** — Stateful chatbot (in-memory dict `SESSIONS`, 4h TTL). State machine stages: `start → identify_skill → show_workers → choose_worker → done`. On choice, returns a `redirect` payload that the Flutter client uses for navigation.
- **`backend/notifications.py`** — Firebase Admin init is lazy and gracefully degrades if `firebase_admin.json` is missing. FCM push sent at: new job request, accepted/rejected, booking created, job completed, rating received.
- **`frontend/.../config/api_config.dart`** — Backend base URL stored in SharedPreferences. Default is a hardcoded LAN IP. Change via Settings page at runtime. **Must be updated when the dev machine's IP changes.**
- **`frontend/.../main.dart`** — All routes defined in `onGenerateRoute`. Each route validates `args` type and falls back to an error screen. `ThemeData` sets the global design tokens.

---

## Current State / Known Issues

### Active Work
- **App redesign in progress** — orange `#FF4D00` brand color, white scaffold, dark cards, 24px border radii, no gradients/shadows.
- Completed: auth pages, customer flow, `WorkerInfoPage`.
- Remaining: `WorkersHP`, `WorkerCompletedBookingsPage`, `pendingJobs`, `incoming_request`, `admin_dashboard`, `chatbot`, `wallet`, `settings_page`, `finalPaySlip`, `jobrequest`, `service_workers`.

### Security Issues (known, not yet fixed)
- **Passwords stored and compared in plaintext** — `auth.py` does no hashing.
- **No session/JWT authentication** — all API endpoints are open; auth state lives only in the Flutter client (stored userId).

### Other Known Issues
- `monthly_users` in `admin.py:/admin/stats` returns **hardcoded mock data**.
- Backend URL default IP (`192.168.100.203`) is a dev machine LAN address — must be updated via Settings whenever the IP changes.
- `backend/services.py` worker rating always returns `0.0` (reads from `Worker.rating` column which doesn't exist — ratings live in the `ratings` table and must be aggregated separately as done in `workers.py`).

---

## Conventions and Patterns

### Backend
- Each router opens its own `SessionLocal()` DB session and closes in a `finally` block (no dependency injection).
- Pydantic models are defined inline in each router file.
- `ALLOWED_SKILLS = {"plumber", "electrician", "cleaning", "hvac"}` is the canonical service category list — defined in multiple places.
- All skill strings are stored and matched **lowercase**.
- Commission rate is hardcoded at **10%** in `jobs.py` and `admin.py`.
- Run with: `uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000` from the project root (not from inside `backend/`).
- Environment: `.env` at project root with `DB_URL=<connection_string>`.

### Flutter
- Navigation uses **named routes** exclusively via `onGenerateRoute` in `main.dart`.
- Route args are either a plain `int` (userId) or a `Map<String, dynamic>` — checked with `is` before use.
- All HTTP calls go through `ApiService` (static methods) or direct `http.get/post` in page widgets, always awaiting `ApiConfig.getBaseUrl()` first.
- Theme tokens: primary `#FF4D00`, secondary/dark `#1A1A1A`, white scaffold, 0-elevation app bars, 20–24px border radii on inputs/buttons/cards.
- `CardThemeData` (not `CardTheme`) must be used in `ThemeData`; `InkWell` is not a `Container` — wrap with `Container`/`Padding` for decoration.

### Flutter ThemeData pitfall (from lessons)
```dart
// CORRECT
cardTheme: CardThemeData(...)
// WRONG (compile error)
cardTheme: CardTheme(...)
```
