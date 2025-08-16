# backend/routers/customer.py
from fastapi import APIRouter, HTTPException
from sqlalchemy import func
from datetime import datetime

from ..database import SessionLocal
from ..models import User, Worker, Booking, Rating, JobRequest
from ..utils import calc_distance

router = APIRouter(prefix="/customer", tags=["Customer"])


@router.get("/profile/{user_id}")
def get_customer_profile(user_id: int):
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
def get_upcoming_jobs(user_id: int):
    db = SessionLocal()
    jobs = db.query(Booking).filter(
        Booking.customer_id == user_id,
        Booking.status == "pending"
    ).order_by(Booking.date, Booking.time).all()
    db.close()

    return [{
        "job-title": job.job_title,
        "address": job.address,
        "date": job.date.strftime("%Y-%m-%d"),
        "time": job.time.strftime("%H:%M"),
    } for job in jobs]


@router.get("/{user_id}/accepted-workers")
def get_accepted_workers(user_id: int):
    db = SessionLocal()
    try:
        offers = (
            db.query(JobRequest, Worker, User)
            .join(Worker, JobRequest.worker_id == Worker.user_id)
            .join(User, Worker.user_id == User.id)
            .filter(JobRequest.customer_id == user_id, JobRequest.status == "accepted")
            .all()
        )

        result = []
        for offer, worker, user in offers:
            if not offers:
                if offer.prefered_datetime is None:
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
                "customer_lat": offer.customer_lat,
                "customer_lon": offer.customer_lon,
                "date": offer.preferred_datetime.date().isoformat(),
                "time": offer.preferred_datetime.time().strftime("%H:%M")
            })

        return result

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()


@router.get("/{user_id}/completed-jobs")
def get_completed_jobs(user_id: int):
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
