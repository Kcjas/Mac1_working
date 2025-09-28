# backend/routers/jobs.py
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from datetime import datetime

from ..database import SessionLocal
from ..models import User, Worker, Booking, Rating, JobRequest

router = APIRouter(tags=["Jobs"])  # keep original paths (no prefix change)


# --------- Pydantic payloads (same as your main.py) ---------
class JobRequestData(BaseModel):
    customer_id: int
    worker_id: int
    description: str
    preferred_datetime: datetime
    customer_lat: float
    customer_lon: float


class BookingCreate(BaseModel):
    customer_id: int
    worker_id: int
    job_title: str
    address: str
    date: str  # 'YYYY-MM-DD'
    time: str  # 'HH:MM'


class JobCompleteData(BaseModel):
    booking_id: int
    duration_hours: float
    additional_cost: float
    reason: str


# -------------------- Routes (unchanged behavior) --------------------

@router.post("/request_job/")
def request_job(data: JobRequestData):
    db = SessionLocal()
    try:
        job = JobRequest(
            customer_id=data.customer_id,
            worker_id=data.worker_id,
            description=data.description,
            preferred_datetime=data.preferred_datetime,
            customer_lat=data.customer_lat,
            customer_lon=data.customer_lon,
        )
        db.add(job)
        db.commit()
        db.refresh(job)

    

        return {"message": "Job request submitted", "job_id": job.id}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()


@router.post("/job-request/{job_id}/respond")
def respond_to_job(job_id: int, decision: str):
    db = SessionLocal()
    try:
        job = db.query(JobRequest).filter(JobRequest.id == job_id).first()
        if not job:
            raise HTTPException(status_code=404, detail="Job not found")

        if decision not in ["accepted", "rejected"]:
            raise HTTPException(status_code=400, detail="Invalid decision")

        job.status = decision
        db.commit()

        # (your original code fetched customer; side-effects omitted)
        # customer = db.query(User).filter(User.id == job.customer_id).first()

        return {"message": f"Job {decision} successfully"}
    finally:
        db.close()


@router.post("/book")
def create_booking(data: BookingCreate):
    db = SessionLocal()
    try:
        booking = Booking(
            customer_id=data.customer_id,
            worker_id=data.worker_id,
            job_title=data.job_title,
            address=data.address,
            date=datetime.strptime(data.date, "%Y-%m-%d").date(),
            time=datetime.strptime(data.time, "%H:%M").time(),
            status="pending",
        )
        db.add(booking)
        db.commit()
        db.refresh(booking)

        # Remove accepted job_request between same customer & worker (same as your code)
        job_request = (
            db.query(JobRequest)
            .filter(
                JobRequest.customer_id == data.customer_id,
                JobRequest.worker_id == data.worker_id,
                JobRequest.status == "accepted",
            )
            .first()
        )
        if job_request:
            db.delete(job_request)
            db.commit()

        # (your original code fetched worker user; side-effects omitted)
        # worker = db.query(User).filter(User.id == data.worker_id).first()

        return {"message": "Booking created successfully", "booking_id": booking.id}

    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()


@router.post("/booking/complete")
def complete_booking(data: JobCompleteData):
    db = SessionLocal()
    try:
        booking = db.query(Booking).filter(Booking.id == data.booking_id).first()
        if not booking:
            raise HTTPException(status_code=404, detail="Booking not found")

        booking.status = "completed"
        booking.time_taken = data.duration_hours
        booking.extra_cost = data.additional_cost
        booking.extra_reason = data.reason
        db.commit()
        db.refresh(booking)

        # (your original code fetched customer; side-effects omitted)
        # customer = db.query(User).filter(User.id == booking.customer_id).first()

        return {"message": "Booking marked as completed successfully"}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()


@router.get("/booking/{booking_id}/summary")
def get_booking_summary(booking_id: int):
    db = SessionLocal()
    try:
        booking = db.query(Booking).filter(Booking.id == booking_id).first()
        if not booking:
            raise HTTPException(status_code=404, detail="Booking not found")

        worker = db.query(User).filter(User.id == booking.worker_id).first()
        hourly_rate = (
            db.query(Worker.hourly_rate)
            .filter(Worker.user_id == booking.worker_id)
            .scalar()
        )

        hourly_rate = hourly_rate or 0.0
        time_taken = getattr(booking, "time_taken", 0.0) or 0.0
        extra_cost = getattr(booking, "extra_cost", 0.0) or 0.0
        extra_reason = getattr(booking, "extra_reason", "") or ""

        service_cost = round(hourly_rate * time_taken, 2)
        commission = round(0.10 * hourly_rate * time_taken, 2)
        total_cost = round((hourly_rate * time_taken * 1.10) + extra_cost, 2)

        return {
            "worker_name": worker.name if worker else "Unknown",
            "job_title": booking.job_title,
            "time_taken": time_taken,
            "extra_cost": extra_cost,
            "extra_reason": extra_reason,
            "service_cost": service_cost,
            "commission": commission,
            "total_cost": total_cost,
        }
    finally:
        db.close()
