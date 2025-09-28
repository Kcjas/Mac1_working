from fastapi import APIRouter
from sqlalchemy import func

from backend.database import SessionLocal
from backend.models import User, Worker, Booking, Rating

router = APIRouter(prefix="/admin", tags=["Admin"])


@router.get("/users")
def get_all_users():
    db = SessionLocal()
    users = db.query(User).all()
    db.close()
    return [{"id": u.id, "name": u.name, "email": u.email, "role": u.role} for u in users]


@router.get("/workers")
def get_all_workers():
    db = SessionLocal()
    workers = (
        db.query(Worker, User)
        .join(User, Worker.user_id == User.id)
        .all()
    )
    result = []
    for worker, user in workers:
        avg_rating = db.query(func.avg(Rating.rating)).filter(Rating.worker_id == worker.user_id).scalar() or 0.0
        result.append({
            "name": user.name,
            "skill": worker.skill,
            "experience": worker.experience,
            "hourly_rate": worker.hourly_rate,
            "rating": round(avg_rating, 2)
        })
    db.close()
    return result


@router.get("/bookings")
def get_all_bookings():
    db = SessionLocal()
    bookings = db.query(Booking).all()
    result = []
    for b in bookings:
        result.append({
            "id": b.id,
            "job_title": b.job_title,
            "status": b.status,
            "customer_id": b.customer_id,
            "worker_id": b.worker_id,
            "date": b.date.strftime("%Y-%m-%d"),
            "time": b.time.strftime("%H:%M"),
        })
    db.close()
    return result


@router.get("/revenue")
def get_total_revenue():
    db = SessionLocal()
    completed_bookings = db.query(Booking).filter(Booking.status == "completed").all()
    revenue = 0.0
    for b in completed_bookings:
        rate = db.query(Worker.hourly_rate).filter(Worker.user_id == b.worker_id).scalar() or 0.0
        time_taken = getattr(b, "time_taken", 0.0) or 0.0
        revenue += (rate * time_taken * 0.10)
    db.close()
    return {"total_revenue": round(revenue, 2)}
