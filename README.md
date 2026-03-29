# Kitchen Swap — Shift Swap App

A full-stack mobile app for kitchen teams to swap shifts.  
Flutter frontend · FastAPI backend · SQLite (MVP) / Firestore (production)

---

## Project Structure

```
shift_swap/
├── flutter_app/
│   ├── lib/
│   │   ├── main.dart                  # App entry point & theme
│   │   ├── models/
│   │   │   ├── user_model.dart
│   │   │   └── swap_request_model.dart
│   │   ├── screens/
│   │   │   ├── onboarding_screen.dart
│   │   │   ├── home_screen.dart
│   │   │   ├── submit_request_screen.dart
│   │   │   ├── matches_screen.dart
│   │   │   └── my_requests_screen.dart
│   │   └── services/
│   │       └── api_service.dart
│   └── pubspec.yaml
└── backend/
    ├── main.py                        # FastAPI app + matching algorithm
    └── requirements.txt
```

---

## Running the Backend

```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

API docs available at: http://localhost:8000/docs

---

## Running the Flutter App

```bash
cd flutter_app
flutter pub get
flutter run
```

> **Emulator note**: Android emulator uses `10.0.2.2` to reach the host machine.
> Real device: replace `10.0.2.2` in `api_service.dart` with your LAN IP (e.g. `192.168.1.x`).

---

## Database Schema

### `users` table
| Column     | Type | Notes                          |
|------------|------|--------------------------------|
| id         | TEXT | UUID primary key               |
| name       | TEXT | Full name                      |
| role       | TEXT | `'Chef'` or `'Cook'`           |
| created_at | DATETIME | Auto                       |

### `swap_requests` table
| Column     | Type | Notes                                          |
|------------|------|------------------------------------------------|
| id         | TEXT | UUID primary key                               |
| user_id    | TEXT | FK → users.id                                  |
| user_name  | TEXT | Denormalized for fast reads                    |
| user_role  | TEXT | `'Chef'` or `'Cook'`                           |
| give_day   | TEXT | Day being offered (`'Monday'` … `'Sunday'`)    |
| take_days  | TEXT | JSON array — days accepted in return           |
| status     | TEXT | `'pending'` → `'matched'` → `'done'`          |
| created_at | DATETIME | Auto                                       |

---

## Matching Algorithm

The core logic lives in `find_matches()` in `backend/main.py`.

**A match occurs when:**
- Person A gives Day X and is willing to take Day Y
- Person B gives Day Y and is willing to take Day X
- **Both A and B have the same `role`** (Chef ↔ Chef only, Cook ↔ Cook only)

```
POST /requests  →  persists request  →  runs find_matches()  →  returns matches instantly
```

Status lifecycle: `pending → matched → done`

---

## API Endpoints

| Method | Path                  | Description                          |
|--------|-----------------------|--------------------------------------|
| POST   | `/users`              | Create user profile                  |
| POST   | `/requests`           | Submit swap request + find matches   |
| GET    | `/requests/{user_id}` | Get all active requests with matches |
| POST   | `/requests/mark-done` | Resolve swap (marks both as done)    |
| GET    | `/health`             | Health check                         |

---

## Upgrading to Firestore (Production)

Replace the SQLite calls in `main.py` with Firestore equivalents:

**Collections:**
- `users/{userId}` — user documents
- `swap_requests/{requestId}` — request documents

**Firestore index needed:**
```
Collection: swap_requests
Fields: status ASC, user_role ASC, give_day ASC
```

The matching query translates directly:
```python
db.collection("swap_requests")
  .where("status", "==", "pending")
  .where("user_role", "==", my_role)
  .where("give_day", "in", my_take_days)
  .get()
# then filter: my_give_day in doc.take_days
```

---

## MVP Checklist

- [x] Onboarding (name + role)
- [x] Submit request — Give day (single select)
- [x] Submit request — Take days (multi-select)
- [x] Matching algorithm (role-aware, bidirectional)
- [x] Matches screen with person names + days
- [x] My Requests screen with match status
- [x] Mark as Done (resolves both requests)
