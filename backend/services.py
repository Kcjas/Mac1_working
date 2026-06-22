from __future__ import annotations
import math
from datetime import datetime
from typing import List, Dict, Any

from sqlalchemy import func

from .database import SessionLocal
from .models import Worker, User, JobRequest, Rating


def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6371.0
    p1 = math.radians(lat1)
    p2 = math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlmb = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlmb / 2) ** 2
    return 2 * R * math.asin(math.sqrt(a))

def get_workers_by_skill(*, skill: str, user_lat: float, user_lon: float, limit: int = 5) -> List[Dict[str, Any]]:
    db = SessionLocal()
    try:
        rows = (
            db.query(Worker, User)
            .join(User, Worker.user_id == User.id)
            .filter(Worker.skill == skill.lower())
            .filter(Worker.status != "banned")  # banned workers are never suggested
            .all()
        )

        out: List[Dict[str, Any]] = []
        for w, u in rows:
            if w.latitude is None or w.longitude is None:
                continue
            dist = _haversine_km(user_lat, user_lon, float(w.latitude), float(w.longitude))

            # Ratings live in the Rating table, not on Worker — aggregate the real
            # average (same as workers.py) instead of the always-0.0 placeholder.
            avg_rating = (
                db.query(func.avg(Rating.rating))
                .filter(Rating.worker_id == w.user_id)
                .scalar()
            ) or 0.0

            out.append({

                "user_id": int(w.user_id),
                "profile_id": int(w.id),
                "id": int(w.user_id),

                "name": (getattr(u, "full_name", None) or getattr(u, "name", None)
                         or getattr(u, "username", None) or f"Worker {w.user_id}"),
                "rating": round(float(avg_rating), 2),
                "hourly_rate": float(getattr(w, "hourly_rate", 0.0) or 0.0),
                "distance_km": float(dist),
                "is_verified": bool(getattr(w, "is_verified", False)),
            })

        out.sort(key=lambda x: x["distance_km"])
        return out[:limit]
    finally:
        db.close()


