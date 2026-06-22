from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy import func
from datetime import datetime

from ..database import SessionLocal
from ..models import User, Worker, Booking, Rating, JobRequest
from ..utils import calc_distance
from ..auth_deps import get_current_user
from .chat import unread_counts as _unread_counts

router = APIRouter(prefix="/customer", tags=["Customer"])


def _require_self(user_id: int, current: User) -> None:
    """Block one customer from reading another customer's data.

    The router-level guard only checks the *role* is customer; this asserts the
    authenticated caller actually owns the id in the path. Identity comes from
    the verified JWT (``current``), never from the path/body.
    """
    if user_id != current.id:
        raise HTTPException(status_code=403, detail="You can only access your own data")


@router.get("/profile/{user_id}")
def get_customer_profile(user_id: int, current: User = Depends(get_current_user)):
    _require_self(user_id, current)
    db = SessionLocal()
    user = db.query(User).filter(User.id == user_id).first()
    db.close()

    if not user:
        raise HTTPException(status_code=404, detail="User not Found")

    return {
        "name": user.name,
        "age": user.age,
        "gender": user.gender,
    }


@router.get("/{user_id}/upcoming-jobs")
def get_upcoming_jobs(user_id: int, current: User = Depends(get_current_user)):
    _require_self(user_id, current)
    db = SessionLocal()
    try:
        jobs = db.query(Booking).filter(
            Booking.customer_id == user_id,
            Booking.status == "pending"
        ).order_by(Booking.date, Booking.time).all()

        unread = _unread_counts(db, [j.id for j in jobs], viewer_id=user_id)

        result = []
        for job in jobs:
            worker = db.query(User).filter(User.id == job.worker_id).first()
            result.append({
                "booking_id": job.id,
                "worker_id": job.worker_id,
                "worker_name": worker.name if worker else "Worker",
                "job-title": job.job_title,
                "address": job.address,
                "date": job.date.strftime("%Y-%m-%d"),
                "time": job.time.strftime("%H:%M"),
                "unread_count": unread.get(job.id, 0),
            })
        return result
    finally:
        db.close()


@router.get("/{user_id}/accepted-workers")
def get_accepted_workers(user_id: int, current: User = Depends(get_current_user)):
    _require_self(user_id, current)
    db = SessionLocal()
    try:
        offers = (
            db.query(JobRequest, Worker, User)
            .join(Worker, JobRequest.worker_id == Worker.user_id)
            .join(User, Worker.user_id == User.id)
            .filter(JobRequest.customer_id == user_id, JobRequest.status == "accepted")
            .filter(Worker.status != "banned")  # a banned worker drops out of offers
            .all()
        )

        result = []
        for offer, worker, user in offers:
            # Skip offers with no scheduled datetime — the response formats
            # offer.preferred_datetime below and would otherwise crash on None.
            if offer.preferred_datetime is None:
                continue

            avg_rating = (
                db.query(func.avg(Rating.rating))
                .filter(Rating.worker_id == worker.user_id)
                .scalar()
            ) or 0.0

            distance = calc_distance(
                offer.customer_lat, offer.customer_lon,
                worker.latitude, worker.longitude
            )

            result.append({
                "worker_id": worker.user_id,
                "name": user.name,
                "skill": worker.skill,
                "hourly_rate": worker.hourly_rate,
                "rating": round(avg_rating, 2),
                "distance": round(distance, 2),
                "is_verified": bool(worker.is_verified),
                "customer_lat": offer.customer_lat,
                "customer_lon": offer.customer_lon,
                "customer_address": offer.customer_address,
                "date": offer.preferred_datetime.date().isoformat(),
                "time": offer.preferred_datetime.time().strftime("%H:%M")
            })

        return result

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()


@router.get("/{user_id}/completed-jobs")
def get_completed_jobs(user_id: int, current: User = Depends(get_current_user)):
    _require_self(user_id, current)
    db = SessionLocal()
    jobs = db.query(Booking).filter(
        Booking.customer_id == user_id,
        Booking.status == "completed"
    ).order_by(Booking.date.desc()).all()

    return [{
        "booking_id": job.id,
        "job-title": job.job_title,
        "worker_id": job.worker_id,
        "address": job.address,
        "date": job.date.strftime("%Y-%m-%d"),
        "time": job.time.strftime("%H:%M"),
    } for job in jobs]
