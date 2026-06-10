# backend/limiter.py
"""Shared slowapi rate limiter.

A single Limiter instance lives here so both main.py (which registers it on the
app + exception handler) and the routers (which apply @limiter.limit decorators)
import the same object.
"""

from slowapi import Limiter
from slowapi.util import get_remote_address

# Keys requests by client IP. NOTE: behind a reverse proxy every request shares
# the proxy's IP unless forwarded-for handling is configured; fine for direct
# uvicorn (each client is its own peer, and local tests all share 127.0.0.1).
limiter = Limiter(key_func=get_remote_address)
