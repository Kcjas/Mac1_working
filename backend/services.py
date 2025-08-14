from sqlalchemy import func
from .database import SessionLocal
from .models import User, Worker, Booking, Rating, JobRequest
from .utils import calc_distance

ALLOWED_SKILLS = {"plumber", "electrician", "cleaning", "hvac"}

def get_workers_by_skill(skill: str, customer_lat: float, customer_lon: float):
    db = SessionLocal()
    try:
        rows = (
            db.query(Worker, User)
              .join(User, Worker.user_id == User.id)
              .filter(Worker.skill == skill.lower())
              .all()
        )
        result = []
        for w, u in rows:
            distance = calc_distance(customer_lat, customer_lon, w.latitude, w.longitude)
            avg = db.query(func.avg(Rating.rating)).filter(Rating.worker_id == w.user_id).scalar() or 0.0
            result.append({
                "worker_id": w.user_id,
                "name": u.name,
                "hourly_rate": w.hourly_rate,
                "rating": round(float(avg), 2),
                "distance": round(float(distance), 2),
            })
        result.sort(key=lambda x: x["distance"])
        return result
    finally:
        db.close()

def create_job_request(customer_id: int, worker_id: int, description: str, preferred_dt, lat: float, lon: float):
    db = SessionLocal()
    try:
        jr = JobRequest(
            customer_id=customer_id,
            worker_id=worker_id,
            description=description,
            preferred_datetime=preferred_dt,
            customer_lat=lat,
            customer_lon=lon,
            status="pending"
        )
        db.add(jr)
        db.commit()
        db.refresh(jr)
        return {"message": "Job request submitted", "job_id": jr.id}
    except:
        db.rollback()
        raise
    finally:
        db.close()
