# backend/routers/auth.py
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session

from ..database import SessionLocal
from ..models import User

router = APIRouter(prefix="/auth", tags=["Auth"])

# ---------- Schemas ----------
class SignupData(BaseModel):
    name: str
    age: int
    gender: str
    email: EmailStr
    password: str
    role: str  # e.g., "customer" or "worker" (keep as-is to match your app)

class LoginData(BaseModel):
    email: EmailStr
    password: str

class AuthResponse(BaseModel):
    message: str
    user_id: int
    role: str


# ---------- Helpers ----------
def _get_db() -> Session:
    return SessionLocal()


# ---------- Routes ----------
@router.post("/signup", response_model=AuthResponse)
def signup(data: SignupData):
    db = _get_db()
    try:
        # Check existing email
        existing = db.query(User).filter(User.email == data.email).first()
        if existing:
            # NOTE: your old code had a typo "statuscode"; fix to status_code
            raise HTTPException(status_code=409, detail="Email already registered")

        # Create user (keeping plaintext password to match your current code)
        # If you want hashing later, we can add passlib.
        user = User(
            name=data.name,
            age=data.age,
            gender=data.gender,
            email=data.email,
            password=data.password,
            role=data.role,
        )
        db.add(user)
        db.commit()
        db.refresh(user)

        return AuthResponse(message="Signup successful", user_id=user.id, role=user.role)
    finally:
        db.close()


@router.post("/login", response_model=AuthResponse)
def login(data: LoginData):
    db = _get_db()
    try:
        user = db.query(User).filter(User.email == data.email).first()
        if not user:
            raise HTTPException(status_code=401, detail="User not found")

        if user.password != data.password:
            raise HTTPException(status_code=401, detail="Incorrect password")

        return AuthResponse(message="Login successful", user_id=user.id, role=user.role)
    finally:
        db.close()
