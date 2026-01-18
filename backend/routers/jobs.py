
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from datetime import datetime

from ..database import SessionLocal
from ..models import User, Worker, Booking, Rating, JobRequest
from ..notifications import send_to_token

router = APIRouter(tags=["Jobs"])  

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


# -------------------- Routes --------------------

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

        worker_user = db.query(User).filter(User.id == job.worker_id).first()
        if worker_user and worker_user.fcm_token:
            send_to_token(
                worker_user.fcm_token,
                "New Job Request",
                f"You received a request from customer #{job.customer_id}",
                data={
                    "route": "/incomingRequests",
                    "workerId": str(job.worker_id)
                }
            )

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

        if decision == "accepted":
            customer_user = db.query(User).filter(User.id == job.customer_id).first()
            if customer_user and customer_user.fcm_token:
                send_to_token(
                    customer_user.fcm_token,
                    "Request Accepted ",
                    f"Your request was accepted by worker #{job.worker_id}",
                    data={
                        "route": "/acceptedWorkerList"
                    }
                )

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

        # Remove accepted job_request between same customer & worker
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

        # Notify both parties about booking creation
        customer_user = db.query(User).filter(User.id == booking.customer_id).first()
        worker_user = db.query(User).filter(User.id == booking.worker_id).first()

        # Customer: booking created
        if customer_user and customer_user.fcm_token:
            send_to_token(
                customer_user.fcm_token,
                "Booking Created ",
                f"{booking.job_title} on {booking.date.isoformat()} at {booking.time.strftime('%H:%M')}",
                data={
                    # Adjust to your desired landing page after booking
                    "route": "/completedJobList"  # or "/customerHome"
                }
            )

        # Worker: you’re booked
        if worker_user and worker_user.fcm_token:
            send_to_token(
                worker_user.fcm_token,
                "New Booking Confirmed ",
                f"{booking.job_title} on {booking.date.isoformat()} at {booking.time.strftime('%H:%M')}",
                data={
                    "route": "/pendingJobs",
                    "workerId": str(booking.worker_id)
                }
            )

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
        worker = db.query(Worker).filter(Worker.user_id == booking.worker_id).first()
        if not worker:
            raise HTTPException(status_code=404, detail="Worker not found")

        booking.status = "completed"
        booking.time_taken = data.duration_hours
        booking.extra_cost = data.additional_cost
        booking.extra_reason = data.reason

        service_cost = worker.hourly_rate * data.duration_hours
        commission = 0.10 * service_cost
        worker_earning = service_cost - commission + data.additional_cost
        worker.money_earned += worker_earning
        db.commit()
        db.refresh(booking)

        customer_user = db.query(User).filter(User.id == booking.customer_id).first()
        if customer_user and customer_user.fcm_token:
            send_to_token(
                customer_user.fcm_token,
                "Job Completed ",
                f"View payslip for {booking.job_title}",
                data={
                    "route": "/payslip",
                    "bookingId": str(booking.id)
                }
            )
            send_to_token(
                customer_user.fcm_token,
                "Rate Your Worker",
                "Share feedback to help improve service quality",
                data={
                    "route": "/rate",
                    "customerId": str(booking.customer_id),
                    "workerId": str(booking.worker_id)
                }
            )

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
