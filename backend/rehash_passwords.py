"""One-off migration: hash any plaintext passwords still in the users table.

Run ONCE after deploying the bcrypt hashing change, then delete this file.

    cd C:\\Mac1
    & backend\\.venv\\Scripts\\Activate.ps1
    python -m backend.rehash_passwords

Idempotent: rows whose password already looks like a bcrypt hash ($2...) are
skipped, so running it more than once is harmless.
"""

from .database import SessionLocal
from .models import User
from .security import hash_password


def main() -> None:
    db = SessionLocal()
    try:
        users = db.query(User).all()
        fixed = 0
        skipped = 0
        for user in users:
            current = user.password or ""
            if current.startswith("$2"):
                skipped += 1  # already hashed
                continue
            if not current:
                # No password on record; nothing to migrate. Leave as-is so a
                # human can notice rather than us inventing a credential.
                print(f"  WARNING: user id={user.id} ({user.email}) has an "
                      f"empty password; skipping")
                skipped += 1
                continue
            user.password = hash_password(current)
            fixed += 1

        db.commit()
        print(f"Done. Rehashed {fixed} password(s), skipped {skipped}.")
    finally:
        db.close()


if __name__ == "__main__":
    main()
