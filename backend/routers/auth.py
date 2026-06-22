
from fastapi import APIRouter, HTTPException, Request, Depends
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session

from ..database import SessionLocal
from ..models import User
from ..security import hash_password, verify_password, create_access_token
from ..auth_deps import get_current_user
from ..limiter import limiter

router = APIRouter(prefix="/auth", tags=["Auth"])

class SignupData(BaseModel):
    name: str
    age: int
    gender: str
    email: EmailStr
    password: str
    role: str  

class LoginData(BaseModel):
    email: EmailStr
    password: str

class AuthResponse(BaseModel):
    message: str
    user_id: int
    role: str
    access_token: str
    token_type: str = "bearer"

class UpdateTokenPayload(BaseModel):
    user_id: int
    fcm_token: str


def _get_db() -> Session:
    return SessionLocal()


@router.post("/signup", response_model=AuthResponse)
@limiter.limit("3/minute")
def signup(request: Request, data: SignupData):
    db = _get_db()
    try:
        # Public signup may only create customers or workers. Admin accounts are
        # provisioned manually in the DB — never grantable via this open endpoint.
        if data.role not in ("customer", "worker"):
            raise HTTPException(status_code=400, detail="Invalid role")

        existing = db.query(User).filter(User.email == data.email).first()
        if existing:
            raise HTTPException(status_code=409, detail="Email already registered")

        try:
            hashed = hash_password(data.password)
        except ValueError as exc:
            raise HTTPException(status_code=400, detail=str(exc))

        user = User(
            name=data.name,
            age=data.age,
            gender=data.gender,
            email=data.email,
            password=hashed,
            role=data.role,
        )
        db.add(user)
        db.commit()
        db.refresh(user)

        token = create_access_token(user.id, user.role)
        return AuthResponse(
            message="Signup successful",
            user_id=user.id,
            role=user.role,
            access_token=token,
        )
    finally:
        db.close()


@router.post("/login", response_model=AuthResponse)
@limiter.limit("5/minute")
def login(request: Request, data: LoginData):
    db = _get_db()
    try:
        user = db.query(User).filter(User.email == data.email).first()
        if not user or not verify_password(data.password, user.password):
            # Same error for unknown email and wrong password to avoid leaking
            # which accounts exist.
            raise HTTPException(status_code=401, detail="Invalid email or password")

        token = create_access_token(user.id, user.role)
        return AuthResponse(
            message="Login successful",
            user_id=user.id,
            role=user.role,
            access_token=token,
        )
    finally:
        db.close()


@router.get("/me")
def me(current_user: User = Depends(get_current_user)):
    """Return the authenticated user's basic profile (used by the client to
    validate a stored token on startup)."""
    return {
        "user_id": current_user.id,
        "name": current_user.name,
        "email": current_user.email,
        "role": current_user.role,
    }

@router.post("/update_token")
def update_token(payload: UpdateTokenPayload):
    db = _get_db()
    try:
        user = db.query(User).get(payload.user_id)
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        user.fcm_token = payload.fcm_token
        db.commit()
        return {"ok": True}
    finally:
        db.close()

