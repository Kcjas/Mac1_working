
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from datetime import datetime
from typing import Optional

from ..database import SessionLocal
from ..models import User, Worker, Booking, Rating, JobRequest
from ..notifications import send_to_token
from ..auth_deps import get_current_user, require_worker, require_customer

router = APIRouter(tags=["Jobs"])  

class JobRequestData(BaseModel):
    customer_id: int
    worker_id: int
    description: str
    preferred_datetime: datetime
    customer_lat: float
    customer_lon: float
    customer_address: Optional[str] = None


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



@router.post("/request_job/")
def request_job(data: JobRequestData, current: User = Depends(require_customer)):
    # The request must be sent as the authenticated customer, not a spoofed id.
    if data.customer_id != current.id:
        raise HTTPException(status_code=403, detail="You can only send job requests as yourself")
    db = SessionLocal()
    try:
        job = JobRequest(
            customer_id=data.customer_id,
            worker_id=data.worker_id,
            description=data.description,
            preferred_datetime=data.preferred_datetime,
            customer_lat=data.customer_lat,
            customer_lon=data.customer_lon,
            customer_address=data.customer_address,
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
def respond_to_job(job_id: int, decision: str, current: User = Depends(require_worker)):
    db = SessionLocal()
    try:
        job = db.query(JobRequest).filter(JobRequest.id == job_id).first()
        if not job:
            raise HTTPException(status_code=404, detail="Job not found")

        # Only the worker the request was sent to may accept/reject it.
        if job.worker_id != current.id:
            raise HTTPException(status_code=403, detail="This job request is not yours")

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
def create_booking(data: BookingCreate, current: User = Depends(require_customer)):
    # The booking must be created as the authenticated customer, not a spoofed id.
    if data.customer_id != current.id:
        raise HTTPException(status_code=403, detail="You can only create bookings as yourself")

    # Validate date/time BEFORE the db try-block so a bad value returns 400,
    # not a 500 swallowed by the generic exception handler below.
    try:
        booking_date = datetime.strptime(data.date, "%Y-%m-%d").date()
        booking_time = datetime.strptime(data.time, "%H:%M").time()
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid date or time format (expected YYYY-MM-DD and HH:MM)")

    db = SessionLocal()
    try:
        booking = Booking(
            customer_id=data.customer_id,
            worker_id=data.worker_id,
            job_title=data.job_title,
            address=data.address,
            date=booking_date,
            time=booking_time,
            status="pending",
        )
        db.add(booking)
        db.commit()
        db.refresh(booking)

        # Remove ALL matching accepted requests, not just the first, so stale
        # offers for this customer+worker can't be re-used to book again.
        stale_requests = (
            db.query(JobRequest)
            .filter(
                JobRequest.customer_id == data.customer_id,
                JobRequest.worker_id == data.worker_id,
                JobRequest.status == "accepted",
            )
            .all()
        )
        for jr in stale_requests:
            db.delete(jr)
        if stale_requests:
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
                    "route": "/completedJobList"  
                }
            )

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
def complete_booking(data: JobCompleteData, current: User = Depends(require_worker)):
    db = SessionLocal()
    try:
        booking = db.query(Booking).filter(Booking.id == data.booking_id).first()
        if not booking:
            raise HTTPException(status_code=404, detail="Booking not found")

        # Only the worker assigned to this booking may complete it and be paid for it.
        if booking.worker_id != current.id:
            raise HTTPException(status_code=403, detail="This booking is not yours")

        worker = db.query(Worker).filter(Worker.user_id == booking.worker_id).first()
        if not worker:
            raise HTTPException(status_code=404, detail="Worker not found")

        # Sanity-bound the worker-supplied figures so hours/extras can't be
        # inflated to absurd values (full customer-confirmed flow is roadmap).
        if data.duration_hours <= 0 or data.duration_hours > 24:
            raise HTTPException(status_code=400, detail="duration_hours must be between 0 and 24")
        if data.additional_cost < 0:
            raise HTTPException(status_code=400, detail="additional_cost cannot be negative")

        booking.status = "completed"
        booking.completed_at = datetime.utcnow()  # anchors the 7-day chat auto-close window
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
                    "workerId": str(booking.worker_id),
                    "bookingId": str(booking.id)
                }
            )

        return {"message": "Booking marked as completed successfully"}
    except HTTPException:
        # Let intended 4xx (404 not found, 403 not yours, 400 bad input) through
        # instead of the generic handler below masking them as 500.
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()


@router.get("/booking/{booking_id}/summary")
def get_booking_summary(booking_id: int, current: User = Depends(get_current_user)):
    db = SessionLocal()
    try:
        booking = db.query(Booking).filter(Booking.id == booking_id).first()
        if not booking:
            raise HTTPException(status_code=404, detail="Booking not found")

        # Only the two parties on the booking may view its payslip.
        if current.id not in (booking.customer_id, booking.worker_id):
            raise HTTPException(status_code=403, detail="This booking is not yours")

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
