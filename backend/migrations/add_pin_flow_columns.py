"""One-off migration: add PIN-verified completion columns to `bookings`.

SQLAlchemy's create_all() does not ALTER existing tables, so the columns added
to the Booking model for the PIN/timer completion flow must be applied here.
Idempotent (ADD COLUMN IF NOT EXISTS) — safe to run more than once.

Run from the project root:
    python -m backend.migrations.add_pin_flow_columns
"""

from sqlalchemy import text

from backend.database import engine

# Postgres supports ADD COLUMN IF NOT EXISTS, so each statement is a no-op if the
# column already exists.
STATEMENTS = [
    "ALTER TABLE bookings ADD COLUMN IF NOT EXISTS started_at TIMESTAMP",
    "ALTER TABLE bookings ADD COLUMN IF NOT EXISTS start_pin VARCHAR",
    "ALTER TABLE bookings ADD COLUMN IF NOT EXISTS complete_pin VARCHAR",
    "ALTER TABLE bookings ADD COLUMN IF NOT EXISTS extras VARCHAR",
    "ALTER TABLE bookings ADD COLUMN IF NOT EXISTS pin_attempts INTEGER DEFAULT 0",
]


def run() -> None:
    with engine.begin() as conn:
        for stmt in STATEMENTS:
            conn.execute(text(stmt))
            print(f"OK  {stmt}")
    print("Migration complete.")


if __name__ == "__main__":
    run()
