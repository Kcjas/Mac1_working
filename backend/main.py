from fastapi import FastAPI
from .database import Base, engine
from .routers import auth, workers, customers, jobs, admin, convai

# Create all tables
Base.metadata.create_all(bind=engine)

# Init app
app = FastAPI(title="MAC1 Backend API")

# Register routers
app.include_router(auth.router)
app.include_router(workers.router)
app.include_router(customers.router)
app.include_router(jobs.router)
app.include_router(admin.router)
app.include_router(convai.router)

@app.get("/")
def root():
    return {"message": "MAC1 Backend API is running"}
