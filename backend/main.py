"""
Shift Swap API — FastAPI Backend
Run with: uvicorn main:app --reload --host 0.0.0.0 --port 8000
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import sqlite3
import uuid
import json
import os
from contextlib import contextmanager
from datetime import datetime, timedelta

app = FastAPI(title="Kitchen Swap API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

if os.path.exists("/data"):
    DB_PATH = "/data/shift_swap.db"
else:
    DB_PATH = "shift_swap.db"

# ─── Database Setup ────────────────────────────────────────────────────────────

def init_db():
    with sqlite3.connect(DB_PATH) as conn:
        conn.executescript("""
            CREATE TABLE IF NOT EXISTS users (
                id          TEXT PRIMARY KEY,
                name        TEXT NOT NULL,
                role        TEXT NOT NULL CHECK(role IN ('Chef', 'Cook')),
                created_at  DATETIME DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE IF NOT EXISTS swap_requests (
                id          TEXT PRIMARY KEY,
                user_id     TEXT NOT NULL REFERENCES users(id),
                user_name   TEXT NOT NULL,
                user_role   TEXT NOT NULL,
                give_day    TEXT,
                take_days   TEXT,  -- JSON array stored as string
                give_date   TEXT NOT NULL,  -- ISO date string (YYYY-MM-DD)
                take_dates  TEXT NOT NULL,  -- JSON array of ISO dates
                week_offset INTEGER DEFAULT 0,  -- For backward compatibility
                status      TEXT NOT NULL DEFAULT 'pending'
                              CHECK(status IN ('pending', 'matched', 'done')),
                created_at  DATETIME DEFAULT CURRENT_TIMESTAMP
            );

            CREATE INDEX IF NOT EXISTS idx_requests_user
                ON swap_requests(user_id);
            CREATE INDEX IF NOT EXISTS idx_requests_status
                ON swap_requests(status);
            CREATE INDEX IF NOT EXISTS idx_requests_role
                ON swap_requests(user_role);
        """)
        # Migrations: add new columns if they don't exist
        try:
            conn.execute("ALTER TABLE swap_requests ADD COLUMN give_date TEXT")
        except sqlite3.OperationalError:
            pass
        try:
            conn.execute("ALTER TABLE swap_requests ADD COLUMN take_dates TEXT")
        except sqlite3.OperationalError:
            pass
        try:
            conn.execute("ALTER TABLE swap_requests ADD COLUMN week_offset INTEGER DEFAULT 0")
        except sqlite3.OperationalError:
            pass

init_db()

@contextmanager
def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


# ─── Utility Functions ─────────────────────────────────────────────────────────

def get_day_name(date_str: str) -> str:
    """Convert date string (YYYY-MM-DD) to day name."""
    date = datetime.strptime(date_str, "%Y-%m-%d")
    days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    return days[date.weekday()]

def get_day_names(date_strs: list[str]) -> list[str]:
    """Convert list of date strings to list of day names."""
    return [get_day_name(date_str) for date_str in date_strs]

def get_week_start_date(reference_date: datetime, week_offset: int = 0) -> datetime:
    """Get the Sunday that starts the week containing the reference_date + week_offset weeks."""
    current_week_start = reference_date - timedelta(days=(reference_date.weekday() + 1) % 7)
    target_week = current_week_start + timedelta(weeks=week_offset)
    return target_week

def get_week_start_for_date(date_str: str) -> datetime:
    """Get the Sunday that starts the week containing the given date (YYYY-MM-DD)."""
    date = datetime.strptime(date_str, "%Y-%m-%d")
    week_start = date - timedelta(days=(date.weekday() + 1) % 7)
    return week_start


# ─── Schemas ───────────────────────────────────────────────────────────────────

class CreateUserRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    role: str = Field(..., pattern="^(Chef|Cook)$")

class CreateSwapRequest(BaseModel):
    user_id: str
    user_name: str
    user_role: str = Field(..., pattern="^(Chef|Cook)$")
    give_date: str  # ISO date string (YYYY-MM-DD)
    take_dates: list[str]  # List of ISO date strings

class MarkDoneRequest(BaseModel):
    my_request_id: str
    their_request_id: str

class UserResponse(BaseModel):
    id: str
    name: str
    role: str

class MatchResult(BaseModel):
    request_id: str
    user_name: str
    give_date: str
    take_dates: list[str]

class SwapRequestResponse(BaseModel):
    id: str
    user_id: str
    user_name: str
    user_role: str
    give_date: str
    take_dates: list[str]
    status: str
    matches: list[MatchResult] = []

class SubmitResponse(BaseModel):
    request_id: str
    matches: list[SwapRequestResponse]


# ─── Matching Algorithm ────────────────────────────────────────────────────────

def find_matches(
    conn: sqlite3.Connection,
    my_give_date: str,
    my_take_dates: list[str],
    my_role: str,
    exclude_user_id: str,
) -> list[dict]:
    """
    Core matching logic using absolute dates.

    A match exists when:
      - Person A gives Date X and is willing to take Date Y
      - Person B gives Date Y and is willing to take Date X
      - Both A and B share the SAME role (Chef ↔ Chef, Cook ↔ Cook)
      - Both requests are for dates in the SAME calendar week

    Returns a list of matching swap_request rows.
    """
    # Get the week start for the give_date
    my_week_start = get_week_start_for_date(my_give_date)
    my_week_end = my_week_start + timedelta(days=6)
    
    # Get day of week for matching (0=Sunday, 1=Monday, etc.)
    my_give_date_obj = datetime.strptime(my_give_date, "%Y-%m-%d")
    my_give_day_of_week = (my_give_date_obj.weekday() + 1) % 7
    
    my_take_days_of_week = []
    for date_str in my_take_dates:
        date_obj = datetime.strptime(date_str, "%Y-%m-%d")
        day_of_week = (date_obj.weekday() + 1) % 7
        my_take_days_of_week.append(day_of_week)
    
    # Query for all pending requests in the same week with the same role
    cursor = conn.execute(
        """
        SELECT id, user_id, user_name, user_role, give_date, take_dates
        FROM swap_requests
        WHERE status = 'pending'
          AND user_role = ?
          AND user_id != ?
          AND give_date >= ?
          AND give_date <= ?
        """,
        [my_role, exclude_user_id, my_week_start.strftime("%Y-%m-%d"), my_week_end.strftime("%Y-%m-%d")],
    )

    matches = []
    for row in cursor.fetchall():
        their_give_date_obj = datetime.strptime(row["give_date"], "%Y-%m-%d")
        their_give_day_of_week = (their_give_date_obj.weekday() + 1) % 7
        
        their_take_dates = json.loads(row["take_dates"])
        their_take_days_of_week = []
        for date_str in their_take_dates:
            date_obj = datetime.strptime(date_str, "%Y-%m-%d")
            day_of_week = (date_obj.weekday() + 1) % 7
            their_take_days_of_week.append(day_of_week)
        
        # Check if there's a match: they give a day I want, and they want a day I give
        if their_give_day_of_week in my_take_days_of_week and my_give_day_of_week in their_take_days_of_week:
            matches.append(dict(row))

    return matches


# ─── Routes ────────────────────────────────────────────────────────────────────

@app.post("/users", response_model=UserResponse)
def create_user(body: CreateUserRequest):
    """Create or retrieve a user profile by name and role."""
    with get_db() as conn:
        # Check if user with same name and role exists
        row = conn.execute(
            "SELECT id, name, role FROM users WHERE name = ? AND role = ?",
            [body.name.strip(), body.role],
        ).fetchone()
        
        if row:
            # Return existing user
            return UserResponse(id=row["id"], name=row["name"], role=row["role"])
        
        # Create new user
        user_id = str(uuid.uuid4())
        conn.execute(
            "INSERT INTO users (id, name, role) VALUES (?, ?, ?)",
            [user_id, body.name.strip(), body.role],
        )
        return UserResponse(id=user_id, name=body.name.strip(), role=body.role)


@app.post("/requests", response_model=SubmitResponse)
def submit_request(body: CreateSwapRequest):
    """
    Submit a new shift-swap request and immediately return any matches found.
    Requires absolute dates (YYYY-MM-DD format).
    """
    # Validate dates
    try:
        give_date_obj = datetime.strptime(body.give_date, "%Y-%m-%d")
        for date_str in body.take_dates:
            datetime.strptime(date_str, "%Y-%m-%d")
    except ValueError as e:
        raise HTTPException(400, f"Invalid date format. Use YYYY-MM-DD: {e}")

    give_date = body.give_date
    take_dates = body.take_dates

    # Compute week_offset for storage (for backward compatibility)
    try:
        now = datetime.now()
        week_start = get_week_start_date(now, 0)
        if give_date_obj >= week_start + timedelta(days=7):
            week_offset = 1
        else:
            week_offset = 0
    except:
        week_offset = 0

    request_id = str(uuid.uuid4())
    give_day = get_day_name(give_date)
    take_days = get_day_names(take_dates)

    with get_db() as conn:
        # Persist the new request
        conn.execute(
            """
            INSERT INTO swap_requests
                (id, user_id, user_name, user_role, give_day, give_date, take_days, take_dates, week_offset, status)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending')
            """,
            [
                request_id,
                body.user_id,
                body.user_name,
                body.user_role,
                give_day,
                give_date,
                json.dumps(take_days),
                json.dumps(take_dates),
                week_offset,
            ],
        )

        # Run matching algorithm
        raw_matches = find_matches(
            conn,
            my_give_date=give_date,
            my_take_dates=take_dates,
            my_role=body.user_role,
            exclude_user_id=body.user_id,
        )

        # Build response
        match_responses = [
            SwapRequestResponse(
                id=m["id"],
                user_id=m["user_id"],
                user_name=m["user_name"],
                user_role=m["user_role"],
                give_date=m["give_date"],
                take_dates=json.loads(m["take_dates"]),
                status="matched",
                matches=[
                    MatchResult(
                        request_id=request_id,
                        user_name=body.user_name,
                        give_date=give_date,
                        take_dates=take_dates,
                    )
                ],
            )
            for m in raw_matches
        ]

    return SubmitResponse(request_id=request_id, matches=match_responses)


@app.get("/requests/{user_id}", response_model=list[SwapRequestResponse])
def get_my_requests(user_id: str):
    """Return all active (non-done) requests for a user, with their matches."""
    with get_db() as conn:
        rows = conn.execute(
            """
            SELECT id, user_id, user_name, user_role, give_date, take_dates, status
            FROM swap_requests
            WHERE user_id = ? AND status != 'done'
            ORDER BY created_at DESC
            """,
            [user_id],
        ).fetchall()

        results = []
        for row in rows:
            # Guard against NULL take_dates from rows inserted before migration
            if not row["take_dates"] or not row["give_date"]:
                continue
            take_dates = json.loads(row["take_dates"])
            # Find matches for this request
            raw_matches = find_matches(
                conn,
                my_give_date=row["give_date"],
                my_take_dates=take_dates,
                my_role=row["user_role"],
                exclude_user_id=user_id,
            )
            match_list = [
                MatchResult(
                    request_id=m["id"],
                    user_name=m["user_name"],
                    give_date=m["give_date"],
                    take_dates=json.loads(m["take_dates"]),
                )
                for m in raw_matches
            ]
            results.append(
                SwapRequestResponse(
                    id=row["id"],
                    user_id=row["user_id"],
                    user_name=row["user_name"],
                    user_role=row["user_role"],
                    give_date=row["give_date"],
                    take_dates=take_dates,
                    status=row["status"],
                    matches=match_list,
                )
            )

    return results


@app.get("/requests/all/{user_role}", response_model=list[SwapRequestResponse])
def get_all_requests(user_role: str):
    """Return all requests from users with the same role (for debugging)."""
    if user_role not in ["Chef", "Cook"]:
        raise HTTPException(400, "Invalid role")
    
    with get_db() as conn:
        rows = conn.execute(
            """
            SELECT id, user_id, user_name, user_role, give_date, take_dates, status
            FROM swap_requests
            WHERE user_role = ?
            ORDER BY created_at DESC
            """,
            [user_role],
        ).fetchall()

        results = []
        for row in rows:
            # Guard against NULL take_dates from rows inserted before migration
            take_dates = json.loads(row["take_dates"] or "[]")
            # Skip rows with no give_date (also pre-migration orphans)
            if not row["give_date"]:
                continue
            results.append(
                SwapRequestResponse(
                    id=row["id"],
                    user_id=row["user_id"],
                    user_name=row["user_name"],
                    user_role=row["user_role"],
                    give_date=row["give_date"],
                    take_dates=take_dates,
                    status=row["status"],
                    matches=[],
                )
            )

    return results


@app.delete("/requests/{request_id}")
def delete_request(request_id: str):
    """Delete a request by ID."""
    with get_db() as conn:
        # Check if request exists and get its user_id
        row = conn.execute(
            "SELECT user_id FROM swap_requests WHERE id = ?",
            [request_id],
        ).fetchone()
        
        if not row:
            raise HTTPException(404, "Request not found")
        
        # Delete the request
        conn.execute(
            "DELETE FROM swap_requests WHERE id = ?",
            [request_id],
        )
        conn.commit()
    
    return {"message": "Request deleted successfully"}


@app.post("/requests/mark-done")
def mark_done_request(body: MarkDoneRequest):
    """Mark two requests as matched (or done) in database."""
    with get_db() as conn:
        row_my = conn.execute(
            "SELECT id FROM swap_requests WHERE id = ?",
            [body.my_request_id],
        ).fetchone()
        row_their = conn.execute(
            "SELECT id FROM swap_requests WHERE id = ?",
            [body.their_request_id],
        ).fetchone()

        if not row_my or not row_their:
            raise HTTPException(404, "One or both requests not found")

        # Set both requests to matched status (explicit user match action)
        conn.execute(
            "UPDATE swap_requests SET status = 'matched' WHERE id IN (?, ?)",
            [body.my_request_id, body.their_request_id],
        )

    return {"message": "Requests marked as matched"}


@app.get("/health")
def health():
    return {"status": "ok"}
