"""
Shift Swap API — FastAPI Backend
Run with: uvicorn main:app --reload --host 0.0.0.0 --port 8000
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import Optional
import sqlite3
import uuid
import json
import os
from contextlib import contextmanager

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
                give_day    TEXT NOT NULL,
                take_days   TEXT NOT NULL,  -- JSON array stored as string
                week_offset INTEGER DEFAULT 0,  -- 0 for current week, 1 for next week
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
        # Migration: add week_offset column if not exists
        try:
            conn.execute("ALTER TABLE swap_requests ADD COLUMN week_offset INTEGER DEFAULT 0")
        except sqlite3.OperationalError:
            pass  # Column already exists

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


# ─── Schemas ───────────────────────────────────────────────────────────────────

class CreateUserRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    role: str = Field(..., pattern="^(Chef|Cook)$")

class CreateSwapRequest(BaseModel):
    user_id: str
    user_name: str
    user_role: str = Field(..., pattern="^(Chef|Cook)$")
    give_day: str
    take_days: list[str] = Field(..., min_length=1)
    week_offset: int = Field(default=0, ge=0, le=1)

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
    give_day: str
    take_days: list[str]

class SwapRequestResponse(BaseModel):
    id: str
    user_id: str
    user_name: str
    user_role: str
    give_day: str
    take_days: list[str]
    week_offset: int
    status: str
    matches: list[MatchResult] = []

class SubmitResponse(BaseModel):
    request_id: str
    matches: list[SwapRequestResponse]


# ─── Matching Algorithm ────────────────────────────────────────────────────────

def find_matches(
    conn: sqlite3.Connection,
    my_give: str,
    my_takes: list[str],
    my_role: str,
    my_week_offset: int,
    exclude_user_id: str,
) -> list[dict]:
    """
    Core matching logic.

    A match exists when:
      - Person A gives Day X and is willing to take Day Y
      - Person B gives Day Y and is willing to take Day X
      - Both A and B share the SAME role (Chef ↔ Chef, Cook ↔ Cook)
      - Both requests are for the SAME week (week_offset matches)

    Returns a list of matching swap_request rows.
    """
    cursor = conn.execute(
        """
        SELECT id, user_id, user_name, user_role, give_day, take_days, week_offset
        FROM swap_requests
        WHERE status = 'pending'
          AND user_role = ?
          AND week_offset = ?
          AND user_id != ?
          AND give_day IN ({})
        """.format(",".join("?" * len(my_takes))),
        [my_role, my_week_offset, exclude_user_id] + my_takes,
    )

    matches = []
    for row in cursor.fetchall():
        their_take_days: list[str] = json.loads(row["take_days"])
        # They give one of my wanted days AND they want what I'm giving
        if my_give in their_take_days:
            matches.append(dict(row))

    return matches


# ─── Routes ────────────────────────────────────────────────────────────────────

@app.post("/users", response_model=UserResponse)
def create_user(body: CreateUserRequest):
    """Create or retrieve a user profile."""
    user_id = str(uuid.uuid4())
    with get_db() as conn:
        conn.execute(
            "INSERT INTO users (id, name, role) VALUES (?, ?, ?)",
            [user_id, body.name.strip(), body.role],
        )
    return UserResponse(id=user_id, name=body.name.strip(), role=body.role)


@app.post("/requests", response_model=SubmitResponse)
def submit_request(body: CreateSwapRequest):
    """
    Submit a new shift-swap request and immediately return any matches found.
    """
    VALID_DAYS = {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"}
    if body.give_day not in VALID_DAYS:
        raise HTTPException(400, "Invalid give_day")
    invalid = [d for d in body.take_days if d not in VALID_DAYS]
    if invalid:
        raise HTTPException(400, f"Invalid take_days: {invalid}")
    if body.give_day in body.take_days:
        raise HTTPException(400, "give_day cannot also be in take_days")

    request_id = str(uuid.uuid4())

    with get_db() as conn:
        # Persist the new request
        conn.execute(
            """
            INSERT INTO swap_requests
                (id, user_id, user_name, user_role, give_day, take_days, week_offset, status)
            VALUES (?, ?, ?, ?, ?, ?, ?, 'pending')
            """,
            [
                request_id,
                body.user_id,
                body.user_name,
                body.user_role,
                body.give_day,
                json.dumps(body.take_days),
                body.week_offset,
            ],
        )

        # Run matching algorithm
        raw_matches = find_matches(
            conn,
            my_give=body.give_day,
            my_takes=body.take_days,
            my_role=body.user_role,
            my_week_offset=body.week_offset,
            exclude_user_id=body.user_id,
        )

        # Mark matched requests (both sides)
        if raw_matches:
            match_ids = [m["id"] for m in raw_matches]
            conn.execute(
                "UPDATE swap_requests SET status = 'matched' WHERE id IN ({})".format(
                    ",".join("?" * len(match_ids))
                ),
                match_ids,
            )
            conn.execute(
                "UPDATE swap_requests SET status = 'matched' WHERE id = ?",
                [request_id],
            )

        # Build response
        match_responses = [
            SwapRequestResponse(
                id=m["id"],
                user_id=m["user_id"],
                user_name=m["user_name"],
                user_role=m["user_role"],
                give_day=m["give_day"],
                take_days=json.loads(m["take_days"]),
                week_offset=m["week_offset"],
                status="matched",
                matches=[
                    MatchResult(
                        request_id=request_id,
                        user_name=body.user_name,
                        give_day=body.give_day,
                        take_days=body.take_days,
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
            SELECT id, user_id, user_name, user_role, give_day, take_days, week_offset, status
            FROM swap_requests
            WHERE user_id = ? AND status != 'done'
            ORDER BY created_at DESC
            """,
            [user_id],
        ).fetchall()

        results = []
        for row in rows:
            take_days = json.loads(row["take_days"])
            # Find matches for this request
            raw_matches = find_matches(
                conn,
                my_give=row["give_day"],
                my_takes=take_days,
                my_role=row["user_role"],
                my_week_offset=row["week_offset"],
                exclude_user_id=user_id,
            )
            match_list = [
                MatchResult(
                    request_id=m["id"],
                    user_name=m["user_name"],
                    give_day=m["give_day"],
                    take_days=json.loads(m["take_days"]),
                )
                for m in raw_matches
            ]
            results.append(
                SwapRequestResponse(
                    id=row["id"],
                    user_id=row["user_id"],
                    user_name=row["user_name"],
                    user_role=row["user_role"],
                    give_day=row["give_day"],
                    take_days=take_days,
                    week_offset=row["week_offset"],
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
            SELECT id, user_id, user_name, user_role, give_day, take_days, week_offset, status
            FROM swap_requests
            WHERE user_role = ?
            ORDER BY created_at DESC
            """,
            [user_role],
        ).fetchall()

        results = []
        for row in rows:
            take_days = json.loads(row["take_days"])
            results.append(
                SwapRequestResponse(
                    id=row["id"],
                    user_id=row["user_id"],
                    user_name=row["user_name"],
                    user_role=row["user_role"],
                    give_day=row["give_day"],
                    take_days=take_days,
                    week_offset=row["week_offset"],
                    status=row["status"],
                    matches=[],  # No matches needed for board view
                )
            )

    return results


@app.get("/health")
def health():
    return {"status": "ok"}
