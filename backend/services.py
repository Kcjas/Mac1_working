from __future__ import annotations
import math
from datetime import datetime
from typing import List, Dict, Any

from .database import SessionLocal
from .models import Worker, User, JobRequest  # adjust names if yours differ

# ------------- distance -------------
def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6371.0
    p1 = math.radians(lat1)
    p2 = math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlmb = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlmb / 2) ** 2
    return 2 * R * math.asin(math.sqrt(a))

# ------------- search nearby workers -------------
def get_workers_by_skill(*, skill: str, user_lat: float, user_lon: float, limit: int = 5) -> List[Dict[str, Any]]:
    """Return workers with given skill sorted by distance, skipping missing coords."""
    db = SessionLocal()
    try:
        rows = (
            db.query(Worker, User)
            .join(User, Worker.user_id == User.id)
            .filter(Worker.skill == skill.lower())
            .all()
        )

        out: List[Dict[str, Any]] = []
        for w, u in rows:
            if w.latitude is None or w.longitude is None:
                continue
            dist = _haversine_km(user_lat, user_lon, float(w.latitude), float(w.longitude))

            out.append({
                # IMPORTANT: the id you expose must be the user's id (users.id)
                "user_id": int(w.user_id),             # <-- use this for requests / bookings
                # keep the Worker row id around if you still need it elsewhere
                "profile_id": int(w.id),               # (workers.id) optional
                # keep "id" as an alias to user_id so older code still works
                "id": int(w.user_id),

                "name": (getattr(u, "full_name", None) or getattr(u, "name", None)
                         or getattr(u, "username", None) or f"Worker {w.user_id}"),
                "rating": float(getattr(w, "rating", 0.0) or 0.0),
                "hourly_rate": float(getattr(w, "hourly_rate", 0.0) or 0.0),
                "distance_km": float(dist),
            })

        out.sort(key=lambda x: x["distance_km"])
        return out[:limit]
    finally:
        db.close()


# ------------- create job request -------------
def create_job_request(*, customer_id: int, worker_id: int, description: str, when_dt: datetime, lat: float, lon: float) -> int:
    """Minimal job-request creation. Adjust field names to your JobRequest model."""
    db = SessionLocal()
    try:
        jr = JobRequest(
            customer_id=customer_id,
            worker_id=worker_id,
            description=description,
            preferred_datetime=when_dt,
            customer_lat=lat,
            customer_lon=lon,
            status="pending",
        )
        db.add(jr)
        db.commit()
        db.refresh(jr)
        return jr.id
    finally:
        db.close()
