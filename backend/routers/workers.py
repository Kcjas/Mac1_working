from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy import func, desc
from datetime import datetime
from pydantic import BaseModel

from ..database import SessionLocal
from ..models import User, Worker, Booking, Rating, JobRequest, Message
from ..utils import calc_distance
from ..notifications import send_to_token
from ..auth_deps import get_current_user, require_worker, require_customer
from .chat import unread_counts as _unread_counts


router = APIRouter(tags=["Workers"]) 

class WorkerInfo(BaseModel):
    user_id: int
    skill: str
    experience: int
    hourly_rate: float
    latitude: float
    longitude: float


class RatingData:
    customer_id: int
    worker_id: int
    rating: int
    review: str = ""


def _require_self_worker(worker_id: int, current: User) -> None:
    """Block a worker from reading another worker's jobs/wallet.

    Role is already enforced by ``require_worker``; this asserts the caller owns
    the worker id in the path, using the identity from the verified JWT.
    """
    if worker_id != current.id:
        raise HTTPException(status_code=403, detail="You can only access your own data")


@router.post("/worker_info")
def add_worker_info(data: dict, current: User = Depends(require_worker)):
    # A worker may only create their own profile, not claim one for another id.
    if data.get("user_id") != current.id:
        raise HTTPException(status_code=403, detail="You can only create your own worker profile")

    db = SessionLocal()

    ALLOWED_SKILLS = {"plumber", "electrician", "cleaning", "hvac"}
    if data["skill"].lower() not in ALLOWED_SKILLS:
        db.close()
        raise HTTPException(
            status_code=400,
            detail=f"Invalid skill. Must be one of: {', '.join(ALLOWED_SKILLS)}"
        )

    existing_worker = db.query(Worker).filter(Worker.user_id == data["user_id"]).first()
    if existing_worker:
        db.close()
        raise HTTPException(status_code=400, detail="Worker info already exists")

    worker = Worker(
        user_id=data["user_id"],
        skill=data["skill"],
        experience=data["experience"],
        hourly_rate=data["hourly_rate"],
        latitude=data["latitude"],         
        longitude=data["longitude"],
    )
    db.add(worker)
    db.commit()
    db.refresh(worker)
    db.close()
    return {"message": "Worker Profile created successfully"}


@router.get("/worker_profile/{user_id}", dependencies=[Depends(get_current_user)])
def get_worker_profile(user_id: int):
    db = SessionLocal()
    worker = db.query(Worker).filter(Worker.user_id == user_id).first()

    if not worker:
        db.close()
        raise HTTPException(status_code=404, detail="Worker not found")

    user = db.query(User).filter(User.id == user_id).first()
    db.close()

    if not user:
        raise HTTPException(status_code=404, detail="Worker not found")

    return {
        "name": user.name,
        "age": user.age,
        "gender": user.gender,
        "skill": worker.skill,
        "experience": worker.experience,
        "hourly_rate": worker.hourly_rate
    }


@router.get("/worker/{worker_id}/pending-jobs")
def get_pending_jobs(worker_id: int, current: User = Depends(require_worker)):
    _require_self_worker(worker_id, current)
    db = SessionLocal()
    jobs = db.query(Booking).filter(
        Booking.worker_id == worker_id,
        Booking.status == "pending"
    ).order_by(Booking.date, Booking.time).all()

    unread = _unread_counts(db, [j.id for j in jobs], viewer_id=worker_id)

    result = []
    for job in jobs:
        customer = db.query(User).filter(User.id == job.customer_id).first()
        result.append({
            "job_title": job.job_title,
            "address": job.address,
            "date": job.date.strftime("%Y-%m-%d"),
            "time": job.time.strftime("%H:%M"),
            "customer_name": customer.name if customer else "Unknown",
            "booking_id": job.id,
            "unread_count": unread.get(job.id, 0),
        })

    db.close()
    return result


@router.get("/worker/{worker_id}/completed-jobs")
def get_completed_jobs(worker_id: int, current: User = Depends(require_worker)):
    _require_self_worker(worker_id, current)
    db = SessionLocal()
    jobs = db.query(Booking).filter(
        Booking.worker_id == worker_id,
        Booking.status == "completed"
    ).all()
    db.close()

    return [{
        "booking_id": job.id,
        "job-title": job.job_title,
        "address": job.address,
        "date": job.date.strftime("%Y-%m-%d"),
        "time": job.time.strftime("%H:%M"),
    } for job in jobs]


@router.post("/rate")
def rate_worker(data: dict, current: User = Depends(require_customer)):
    db = SessionLocal()
    try:
        rating_value = data.get("rating")
        if not isinstance(rating_value, int) or rating_value < 1 or rating_value > 5:
            raise HTTPException(status_code=400, detail="Rating must be an integer between 1 and 5")

        booking_id = data.get("booking_id")
        if booking_id is None:
            raise HTTPException(status_code=400, detail="booking_id is required")

        # The rating must hang off a real completed booking that belongs to the
        # caller. Every field below is derived from that booking, never trusted
        # from the request body — this closes self-rating / rate-off-someone-
        # else's-booking / fake-review holes.
        booking = db.query(Booking).filter(Booking.id == booking_id).first()
        if not booking:
            raise HTTPException(status_code=404, detail="Booking not found")
        if booking.customer_id != current.id:
            raise HTTPException(status_code=403, detail="You can only rate your own bookings")
        if booking.worker_id == current.id:
            raise HTTPException(status_code=403, detail="You cannot rate yourself")
        if data.get("worker_id") is not None and booking.worker_id != data.get("worker_id"):
            raise HTTPException(status_code=400, detail="Worker does not match this booking")
        if booking.status != "completed":
            raise HTTPException(status_code=400, detail="You can only rate a completed booking")

        # One review per job.
        if db.query(Rating).filter(Rating.booking_id == booking_id).first():
            raise HTTPException(status_code=409, detail="This booking has already been rated")

        new_rating = Rating(
            customer_id=current.id,          # from the token, never the body
            worker_id=booking.worker_id,     # authoritative, from the booking
            booking_id=booking_id,
            rating=rating_value,
            review=data.get("review", "")
        )
        db.add(new_rating)
        db.commit()
        db.refresh(new_rating)
        worker_user = db.query(User).filter(User.id == booking.worker_id).first()
        if worker_user and worker_user.fcm_token:
            send_to_token(
                worker_user.fcm_token,
                "New Rating Received",
                f"You received {rating_value}★" + (f" — \"{data.get('review','')}\"" if data.get('review') else ""),
                data={
                    "route": "/workerHome",
                    "workerId": str(booking.worker_id)
                }
            )

        return {"message": "rating Succesfully Submitted"}
    finally:
        db.close()

@router.get("/worker_rating/{worker_id}", dependencies=[Depends(get_current_user)])
def get_worker_rating(worker_id: int):
    db = SessionLocal()
    avg_rating = (
        db.query(func.avg(Rating.rating)).filter(Rating.worker_id == worker_id).scalar()
    )
    db.close()
    if avg_rating is None:
        return {"average_rating": 0}
    return {"average_rating": round(avg_rating, 2)}


@router.get("/worker/leaderboard", dependencies=[Depends(get_current_user)])
def get_leaderboard():
    db = SessionLocal()
    results = (
        db.query(User.name, func.avg(Rating.rating).label("avg_rating"))
        .join(Rating, Rating.worker_id == User.id)
        .group_by(User.id)
        .order_by(func.avg(Rating.rating).desc())
        .limit(5)
        .all()
    )
    db.close()
    return [{"name": name, "avg_rating": round(avg_rating, 2)} for name, avg_rating in results]


@router.get("/workers/skill/{skill}", dependencies=[Depends(require_customer)])
def get_workers_by_skill(skill: str, customer_lat: float, customer_lon: float):
    db = SessionLocal()
    try:
        workers = (
            db.query(Worker, User)
            .join(User, Worker.user_id == User.id)
            .filter(Worker.skill == skill.lower())
            .filter(Worker.status != "banned")  # banned workers are never shown
            .all()
        )

        result = []
        for worker, user in workers:
            distance = calc_distance(customer_lat, customer_lon, worker.latitude, worker.longitude)
            avg_rating = (
                db.query(func.avg(Rating.rating))
                .filter(Rating.worker_id == worker.user_id)
                .scalar()
            ) or 0.0

            result.append({
                "worker_id": worker.user_id,
                "name": user.name,
                "hourly_rate": worker.hourly_rate,
                "rating": round(avg_rating, 2),
                "distance": round(distance, 2),
                "is_verified": bool(worker.is_verified),
            })
        result.sort(key=lambda x: x["distance"])
        return result
    finally:
        db.close()


@router.get("/worker/{worker_id}/incoming-requests")
def get_incoming_requests(worker_id: int, current: User = Depends(require_worker)):
    _require_self_worker(worker_id, current)
    db = SessionLocal()
    try:
        worker = db.query(Worker).filter(Worker.user_id == worker_id).first()
        if not worker:
            raise HTTPException(status_code=404, detail="Worker not found")
        
        requests = (
            db.query(JobRequest, User)
            .join(User, JobRequest.customer_id == User.id)
            .filter(JobRequest.worker_id == worker_id, JobRequest.status == "pending")
            .order_by(JobRequest.created_at.desc())
            .all()
        )

        result = []
        for job, customer in requests:
            distance_km = calc_distance(
                worker.latitude,
                worker.longitude,
                job.customer_lat,
                job.customer_lon
            )

            result.append({
                "job_id": job.id,
                "description": job.description,
                "preferred_datetime": job.preferred_datetime.strftime("%Y-%m-%d %H:%M"),
                "customer_name": customer.name,
                "customer_lat": job.customer_lat,
                "customer_lon": job.customer_lon,
                "distance": round(distance_km, 1),
            })
        return result
    finally:
        db.close()


@router.get("/worker/{worker_id}/wallet")
def get_wallet(worker_id: int, current: User = Depends(require_worker), limit: int = 10):
    _require_self_worker(worker_id, current)
    db = SessionLocal()
    try:
        worker = db.query(Worker).filter(Worker.user_id == worker_id).first()
        if not worker:
            return {"money_earned": 0.0, "transactions": []}

        bookings = (
            db.query(Booking)
            .filter(Booking.worker_id == worker_id, Booking.status == "completed")
            .order_by(desc(Booking.created_at))
            .limit(limit)
            .all()
        )

        tx = []
        for b in bookings:
            time_taken = float(b.time_taken or 0.0)
            extra_cost = float(b.extra_cost or 0.0)
            amount = (time_taken * float(worker.hourly_rate or 0.0)) + extra_cost

            tx.append({
                "booking_id": b.id,
                "job_title": b.job_title,
                "date": b.date.isoformat() if b.date else None,
                "time": b.time.strftime("%H:%M") if b.time else None,
                "amount": round(amount, 2),
                "extra_reason": b.extra_reason,
            })

        return {
            "money_earned": float(worker.money_earned or 0.0),
            "transactions": tx
        }
    finally:
        db.close()

