from fastapi import FastAPI, Depends
from slowapi.errors import RateLimitExceeded
from slowapi import _rate_limit_exceeded_handler

from backend.database import Base, engine
from backend.routers import auth, workers, customers, jobs, admin, convai, chat
from backend.limiter import limiter
from backend.auth_deps import get_current_user, require_admin, require_customer

# Create all tables
Base.metadata.create_all(bind=engine)

# Init app
app = FastAPI(title="MAC1 Backend API")

# Rate limiting: register the shared limiter and slowapi's built-in 429 handler.
# Do NOT add a catch-all/Exception handler that would intercept
# RateLimitExceeded before this one runs, or 429s will be swallowed.
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# Register routers.
#  - auth: open (issues tokens; login/signup are rate-limited internally)
#  - customers / admin: single-audience -> router-level role guard
#  - convai: any authenticated user
#  - workers / jobs: mixed-audience -> per-route guards live in those modules
app.include_router(auth.router)
app.include_router(workers.router)
app.include_router(customers.router, dependencies=[Depends(require_customer)])
app.include_router(jobs.router)
app.include_router(admin.router, dependencies=[Depends(require_admin)])
app.include_router(convai.router, dependencies=[Depends(get_current_user)])
app.include_router(chat.router, dependencies=[Depends(get_current_user)])

@app.get("/")
def root():
    return {"message": "MAC1 Backend API is running"}
