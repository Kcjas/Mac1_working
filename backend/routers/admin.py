from fastapi import APIRouter, HTTPException
from sqlalchemy import func, asc, desc
from typing import Optional
from datetime import datetime
from ..database import SessionLocal
from ..models import User, Worker, Booking, Rating

router = APIRouter(prefix="/admin", tags=["Admin"])


def _paginate(query, page: int, limit: int):
    total = query.count()
    items = query.offset((page - 1) * limit).limit(limit).all()
    has_next = page * limit < total
    return items, has_next


@router.get("/users")
def get_users(
    search: Optional[str] = None,
    role: Optional[str] = None,
    page: int = 1,
    limit: int = 5,
):
    db = SessionLocal()
    try:
        q = db.query(User)
        if role:
            q = q.filter(User.role == role)
        if search:
            like = f"%{search}%"
            q = q.filter((User.name.ilike(like)) | (User.email.ilike(like)))
        q = q.order_by(User.id.desc())
        items, has_next = _paginate(q, page, limit)
        data = [{"id": u.id, "name": u.name, "email": u.email, "role": u.role} for u in items]
        return {"items": data, "has_next": has_next}
    finally:
        db.close()


@router.patch("/users/{user_id}")
def update_user(user_id: int, payload: dict):
    db = SessionLocal()
    try:
        u = db.query(User).get(user_id)
        if not u:
            raise HTTPException(status_code=404, detail="User not found")
        for field in ("name", "email", "role"):
            if field in payload and payload[field] is not None:
                setattr(u, field, payload[field])
        db.commit()
        return {"ok": True}
    finally:
        db.close()


@router.delete("/users/{user_id}")
def delete_user(user_id: int):
    db = SessionLocal()
    try:
        u = db.query(User).get(user_id)
        if not u:
            raise HTTPException(status_code=404, detail="User not found")
        db.delete(u)
        db.commit()
        return {"ok": True}
    finally:
        db.close()

@router.get("/workers")
def get_workers(
    search: Optional[str] = None,
    skill: Optional[str] = None,
    page: int = 1,
    limit: int = 5,
    sort_by: str = "rating",  
    sort_dir: str = "desc",
):
    db = SessionLocal()
    try:
        rating_avg = func.coalesce(func.avg(Rating.rating), 0.0).label("rating")
        q = (
            db.query(
                Worker.id.label("id"),
                User.name.label("name"),
                Worker.skill.label("skill"),
                Worker.hourly_rate.label("hourly_rate"),
                rating_avg,
            )
            .join(User, Worker.user_id == User.id)
            .outerjoin(Rating, Rating.worker_id == Worker.user_id)
            .group_by(Worker.id, User.name, Worker.skill, Worker.hourly_rate)
        )

        if skill:
            q = q.filter(Worker.skill == skill)
        if search:
            like = f"%{search}%"
            q = q.filter(User.name.ilike(like))

        order_col = User.name if sort_by == "name" else rating_avg
        order = desc(order_col) if sort_dir.lower() == "desc" else asc(order_col)
        q = q.order_by(order)

        items, has_next = _paginate(q, page, limit)
        data = [
            {
                "id": w.id,
                "name": w.name,
                "skill": w.skill,
                "hourly_rate": float(w.hourly_rate or 0.0),
                "rating": round(float(w.rating or 0.0), 2),
            }
            for w in items
        ]
        return {"items": data, "has_next": has_next}
    finally:
        db.close()

@router.patch("/workers/{worker_id}")
def update_worker(worker_id: int, payload: dict):
    db = SessionLocal()
    try:
        w = db.query(Worker).get(worker_id)
        if not w:
            raise HTTPException(status_code=404, detail="Worker not found")
        if "skill" in payload and payload["skill"]:
            w.skill = payload["skill"]
        if "hourly_rate" in payload and payload["hourly_rate"] is not None:
            w.hourly_rate = float(payload["hourly_rate"])
        if "experience" in payload and payload["experience"] is not None:
            w.experience = int(payload["experience"])
        db.commit()
        return {"ok": True}
    finally:
        db.close()



@router.get("/bookings")
def get_bookings(
    search: Optional[str] = None,
    status: Optional[str] = None,
    page: int = 1,
    limit: int = 5,           
    sort_by: str = "date",    
    sort_dir: str = "desc",
):
    db = SessionLocal()
    try:
        q = db.query(Booking)
        if status:
            q = q.filter(Booking.status == status)
        if search:
            like = f"%{search}%"
            q = q.filter(Booking.job_title.ilike(like))

        if sort_by == "title":
            order_col = Booking.job_title
        elif sort_by == "status":
            order_col = Booking.status
        else:
            order_col = Booking.date
        order = desc(order_col) if sort_dir.lower() == "desc" else asc(order_col)
        q = q.order_by(order)

        items, has_next = _paginate(q, page, limit)

        data = []
        for b in items:
            date_str = b.date.strftime("%Y-%m-%d") if b.date else ""
            time_str = b.time.strftime("%H:%M") if b.time else ""
            data.append(
                {
                    "id": b.id,
                    "job_title": b.job_title,
                    "date": date_str,
                    "time": time_str,
                    "status": b.status,
                }
            )
        return {"items": data, "has_next": has_next}
    finally:
        db.close()


@router.patch("/bookings/{booking_id}")
def update_booking(booking_id: int, payload: dict):
    db = SessionLocal()
    try:
        b = db.query(Booking).get(booking_id)
        if not b:
            raise HTTPException(status_code=404, detail="Booking not found")

        if "job_title" in payload and payload["job_title"]:
            b.job_title = payload["job_title"]

        if "status" in payload and payload["status"]:
            b.status = payload["status"]

        if "date" in payload and payload["date"]:
            try:
                b.date = datetime.strptime(payload["date"], "%Y-%m-%d").date()
            except ValueError:
                raise HTTPException(status_code=400, detail="Invalid date format (YYYY-MM-DD)")

        if "time" in payload and payload["time"]:
            try:
                b.time = datetime.strptime(payload["time"], "%H:%M").time()
            except ValueError:
                raise HTTPException(status_code=400, detail="Invalid time format (HH:MM)")

        db.commit()
        return {"ok": True}
    finally:
        db.close()

@router.get("/revenue")
def get_revenue():
    db = SessionLocal()
    try:
        completed = db.query(Booking).filter(Booking.status == "completed").all()
        total_commission = 0.0
        for b in completed:
            rate = db.query(Worker.hourly_rate).filter(Worker.user_id == b.worker_id).scalar() or 0.0
            hours = b.time_taken or 0.0
            total_commission += rate * hours * 0.10
        return {"total_revenue": round(total_commission, 2)}
    finally:
        db.close()

@router.get("/stats")
def get_stats():
    db = SessionLocal()
    try:
        pending_count = db.query(func.count(Booking.id)).filter(Booking.status == "pending").scalar()
        completed_count = db.query(func.count(Booking.id)).filter(Booking.status == "completed").scalar()

        popularity = (
            db.query(Worker.skill, func.count(Booking.id))
            .select_from(Booking)
            .join(Worker, Booking.worker_id == Worker.user_id)
            .group_by(Worker.skill)
            .all()
        )
        popularity_data = {skill: count for skill, count in popularity}


        worker_dist = (
            db.query(Worker.skill, func.count(Worker.id))
            .group_by(Worker.skill)
            .all()
        )
        worker_dist_data = {skill: count for skill, count in worker_dist}

        monthly_users = [
            {"month": "Jan", "count": 10},
            {"month": "Feb", "count": 15},
            {"month": "Mar", "count": 12},
            {"month": "Apr", "count": 20},
            {"month": "May", "count": 25},
            {"month": "Jun", "count": 35},
        ]

        return {
            "pending_count": pending_count,
            "completed_count": completed_count,
            "job_popularity": popularity_data,
            "worker_distribution": worker_dist_data,
            "monthly_users": monthly_users,
        }
    finally:
        db.close()


@router.post("/warn/{worker_id}")
def warn_worker(worker_id: int):
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.id == worker_id).first()
        if not user:
            raise HTTPException(status_code=404, detail="Worker not found")
        
        # Send Notification (Mock or Real)
        if user.fcm_token:
            from ..notifications import send_to_token
            send_to_token(
                user.fcm_token,
                "Performance Warning",
                "Your average rating has dropped. Please improve your service quality to avoid penalties.",
                data={"route": "/workerHome"}
            )
        
        return {"message": "Warning sent successfully"}
    except Exception as e:
        print(f"Warning failed: {e}")
        return {"message": "Warning simulated (or failed to send)"}
    finally:
        db.close()


@router.post("/booking/{booking_id}/reopen-chat")
def reopen_chat(booking_id: int):
    """Re-enable messaging on a booking whose chat auto-closed (7 days after
    completion). Sets the override flag so _chat_open() returns True again."""
    db = SessionLocal()
    try:
        booking = db.query(Booking).filter(Booking.id == booking_id).first()
        if not booking:
            raise HTTPException(status_code=404, detail="Booking not found")
        booking.chat_force_open = True
        db.commit()
        return {"message": "Chat reopened", "booking_id": booking_id}
    except HTTPException:
        db.rollback()
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()