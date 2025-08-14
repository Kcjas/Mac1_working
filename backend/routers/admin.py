from fastapi import APIRouter, HTTPException
from typing import List, Dict, Optional
from sqlalchemy import func
from datetime import datetime

from ..database import SessionLocal
from ..models import User, Worker, Booking, Rating

router = APIRouter(prefix="/admin", tags=["Admin"])

# ---------- USERS ----------
@router.get("/users")
def get_all_users(
    search: str = "",
    role: str = "",
    page: int = 1,
    limit: int = 20,
):
    db = SessionLocal()
    try:
        q = db.query(User)

        if search:
            term = f"%{search.lower()}%"
            q = q.filter(
                func.lower(User.name).like(term) |
                func.lower(User.email).like(term)
            )

        if role:
            q = q.filter(User.role == role)

        total = q.count()
        rows = (
            q.order_by(User.id.desc())
             .offset((page - 1) * limit)
             .limit(limit)
             .all()
        )

        items = [{
            "id": u.id,
            "name": u.name,
            "email": u.email,
            "role": u.role,
        } for u in rows]

        return {
            "items": items,
            "page": page,
            "limit": limit,
            "total": total,
            "has_next": page * limit < total,
        }
    finally:
        db.close()


# ---------- WORKERS (with rating sort) ----------
@router.get("/workers")
def get_all_workers(
    search: str = "",
    skill: str = "",
    page: int = 1,
    limit: int = 20,
    sort_by: str = "rating",     # rating | name
    sort_dir: str = "desc",      # asc | desc
):
    db = SessionLocal()
    try:
        # Subquery: average rating per worker
        rating_subq = (
            db.query(
                Rating.worker_id.label("wid"),
                func.avg(Rating.rating).label("avg_rating")
            )
            .group_by(Rating.worker_id)
            .subquery()
        )

        q = (
            db.query(
                Worker,
                User,
                func.coalesce(rating_subq.c.avg_rating, 0.0).label("rating")
            )
            .join(User, Worker.user_id == User.id)
            .outerjoin(rating_subq, rating_subq.c.wid == Worker.user_id)
        )

        if search:
            term = f"%{search.lower()}%"
            q = q.filter(func.lower(User.name).like(term))

        if skill:
            q = q.filter(Worker.skill == skill.lower())

        total = q.count()

        # Sorting
        sort_by = (sort_by or "rating").lower()
        sort_dir = (sort_dir or "desc").lower()
        asc = sort_dir == "asc"

        if sort_by == "name":
            order_col = func.lower(User.name)
        else:
            order_col = func.coalesce(rating_subq.c.avg_rating, 0.0)

        q = q.order_by(order_col.asc() if asc else order_col.desc())

        rows = (
            q.offset((page - 1) * limit)
             .limit(limit)
             .all()
        )

        items = []
        for w, u, r in rows:
            items.append({
                "id": w.user_id,
                "name": u.name,
                "skill": w.skill,
                "experience": w.experience,
                "hourly_rate": w.hourly_rate,
                "rating": round(float(r or 0.0), 2),
            })

        return {
            "items": items,
            "page": page,
            "limit": limit,
            "total": total,
            "has_next": page * limit < total,
        }
    finally:
        db.close()


# ---------- BOOKINGS (with date/status/title sort) ----------
@router.get("/bookings")
def get_all_bookings(
    search: str = "",
    status: str = "",
    page: int = 1,
    limit: int = 20,
    sort_by: str = "date",       # date | status | title
    sort_dir: str = "desc",      # asc | desc
):
    db = SessionLocal()
    try:
        q = db.query(Booking)

        if search:
            term = f"%{search.lower()}%"
            q = q.filter(func.lower(Booking.job_title).like(term))

        if status:
            q = q.filter(Booking.status == status)

        total = q.count()

        # Sorting
        sort_by = (sort_by or "date").lower()
        sort_dir = (sort_dir or "desc").lower()
        asc = sort_dir == "asc"

        if sort_by == "status":
            order_cols = [func.lower(Booking.status)]
        elif sort_by in ("title", "job_title"):
            order_cols = [func.lower(Booking.job_title)]
        else:
            # date + time combined sort
            order_cols = [Booking.date, Booking.time]

        for col in order_cols:
            q = q.order_by(col.asc() if asc else col.desc())

        rows = (
            q.offset((page - 1) * limit)
             .limit(limit)
             .all()
        )

        items = [{
            "id": b.id,
            "job_title": b.job_title,
            "status": b.status,
            "customer_id": b.customer_id,
            "worker_id": b.worker_id,
            "date": b.date.strftime("%Y-%m-%d") if b.date else None,
            "time": b.time.strftime("%H:%M") if b.time else None,
        } for b in rows]

        return {
            "items": items,
            "page": page,
            "limit": limit,
            "total": total,
            "has_next": page * limit < total,
        }
    finally:
        db.close()


# ---------- REVENUE ----------
@router.get("/revenue")
def get_total_revenue():
    """
    Commission revenue = 10% of (hourly_rate * time_taken) for each completed booking,
    plus any safe adjustments you might later add.
    """
    db = SessionLocal()
    try:
        completed = db.query(Booking).filter(Booking.status == "completed").all()
        revenue = 0.0
        for b in completed:
            # Defensive: some schemas may not have time_taken; default to 0
            time_taken = getattr(b, "time_taken", 0.0) or 0.0
            rate = db.query(Worker.hourly_rate).filter(Worker.user_id == b.worker_id).scalar() or 0.0
            revenue += rate * time_taken * 0.10
        return {"total_revenue": round(float(revenue), 2)}
    finally:
        db.close()
