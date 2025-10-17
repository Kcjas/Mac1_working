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


# ---------------- REVENUE ----------------
@router.get("/revenue")
def get_revenue():
    db = SessionLocal()
    try:
        completed = db.query(Booking).filter(Booking.status == "completed").all()
        total = 0.0
        for b in completed:
            rate = (
                db.query(Worker.hourly_rate)
                .filter(Worker.user_id == b.worker_id)
                .scalar()
                or 0.0
            )
            hours = b.time_taken or 0.0
            total += rate * hours * 0.10  # 10% commission
        return {"total_revenue": round(total, 2)}
    finally:
        db.close()
