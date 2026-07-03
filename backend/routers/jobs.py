
import json
import secrets

from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from datetime import datetime
from typing import Optional

from ..database import SessionLocal
from ..models import User, Worker, Booking, Rating, JobRequest
from ..notifications import send_to_token
from ..auth_deps import get_current_user, require_worker, require_customer

router = APIRouter(tags=["Jobs"])


def _generate_pin() -> str:
    """A zero-padded 6-digit PIN drawn from a cryptographically secure source."""
    return f"{secrets.randbelow(1_000_000):06d}"

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


class PinData(BaseModel):
    pin: str


class ExtraItem(BaseModel):
    reason: str
    cost: float


class FinalizeData(BaseModel):
    extras: list[ExtraItem] = []


# Max number of wrong PIN entries before a booking's gate locks. Without the
# customer's PIN the worker can't advance the booking, so this caps brute force.
MAX_PIN_ATTEMPTS = 5



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
        # Two distinct PINs gate the start and completion of the job. The customer
        # sees these (and reads them out on-site); the worker must enter them to
        # advance the booking, proving the customer was present at both ends.
        start_pin = _generate_pin()
        complete_pin = _generate_pin()
        while complete_pin == start_pin:
            complete_pin = _generate_pin()

        booking = Booking(
            customer_id=data.customer_id,
            worker_id=data.worker_id,
            job_title=data.job_title,
            address=data.address,
            date=booking_date,
            time=booking_time,
            status="pending",
            start_pin=start_pin,
            complete_pin=complete_pin,
            pin_attempts=0,
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


def _load_own_booking(db, booking_id: int, worker_id: int) -> Booking:
    """Fetch a booking and assert the caller is the worker assigned to it."""
    booking = db.query(Booking).filter(Booking.id == booking_id).first()
    if not booking:
        raise HTTPException(status_code=404, detail="Booking not found")
    if booking.worker_id != worker_id:
        raise HTTPException(status_code=403, detail="This booking is not yours")
    return booking


def _check_pin(db, booking: Booking, submitted: str, expected: str, label: str) -> None:
    """Compare a submitted PIN against the expected one with an attempt-limit lock.

    On mismatch the attempt counter is bumped and persisted, then a 400 is raised;
    once the limit is hit the gate is locked (423) until an admin intervenes. The
    caller resets pin_attempts to 0 after a successful transition.
    """
    if (booking.pin_attempts or 0) >= MAX_PIN_ATTEMPTS:
        raise HTTPException(
            status_code=423,
            detail="Too many incorrect PIN attempts. Contact support to unlock this booking.",
        )
    if not submitted or not secrets.compare_digest(str(submitted), str(expected or "")):
        booking.pin_attempts = (booking.pin_attempts or 0) + 1
        db.commit()
        raise HTTPException(status_code=400, detail=f"Incorrect {label} code")


@router.post("/booking/{booking_id}/start")
def start_booking(booking_id: int, data: PinData, current: User = Depends(require_worker)):
    db = SessionLocal()
    try:
        booking = _load_own_booking(db, booking_id, current.id)

        # Only a not-yet-started booking can be started. Rejecting any other status
        # stops a job being (re)started out of order.
        if booking.status != "pending":
            raise HTTPException(
                status_code=409,
                detail=f"Cannot start a booking with status '{booking.status}'",
            )

        _check_pin(db, booking, data.pin, booking.start_pin, "start")

        booking.status = "in_progress"
        booking.started_at = datetime.utcnow()  # timer anchor; clients tick up from here
        booking.pin_attempts = 0
        db.commit()
        db.refresh(booking)

        customer_user = db.query(User).filter(User.id == booking.customer_id).first()
        if customer_user and customer_user.fcm_token:
            send_to_token(
                customer_user.fcm_token,
                "Job Started",
                f"Work has started on {booking.job_title}",
                data={"route": "/jobInProgress", "bookingId": str(booking.id)},
            )

        return {
            "message": "Job started",
            "status": booking.status,
            "started_at": booking.started_at.isoformat(),
        }
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()


@router.post("/booking/{booking_id}/complete")
def complete_booking_pin(booking_id: int, data: PinData, current: User = Depends(require_worker)):
    """Stop the timer once the customer's completion PIN is verified.

    The duration is measured from the server-recorded started_at, so it can't be
    inflated by the worker. No costs and no payment happen here — that's /finalize
    and the customer's /confirm.
    """
    db = SessionLocal()
    try:
        booking = _load_own_booking(db, booking_id, current.id)

        if booking.status != "in_progress":
            raise HTTPException(
                status_code=409,
                detail=f"Cannot complete a booking with status '{booking.status}'",
            )

        _check_pin(db, booking, data.pin, booking.complete_pin, "completion")

        if not booking.started_at:
            raise HTTPException(status_code=409, detail="Booking has no recorded start time")

        elapsed_hours = (datetime.utcnow() - booking.started_at).total_seconds() / 3600
        if elapsed_hours <= 0:
            raise HTTPException(status_code=400, detail="Measured duration must be greater than zero")
        # Guard against a forgotten stop running the meter for days.
        elapsed_hours = min(elapsed_hours, 24.0)

        booking.time_taken = round(elapsed_hours, 2)
        booking.status = "awaiting_costs"
        booking.pin_attempts = 0
        db.commit()
        db.refresh(booking)

        return {
            "message": "Timer stopped",
            "status": booking.status,
            "time_taken": booking.time_taken,
        }
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()


@router.post("/booking/{booking_id}/finalize")
def finalize_booking(booking_id: int, data: FinalizeData, current: User = Depends(require_worker)):
    """Record the itemized additional costs and hand the bill to the customer.

    Stores the line items and their total, then moves the booking to
    awaiting_confirmation. No earnings are credited here — that happens only when
    the customer approves the bill via /booking/{id}/confirm.
    """
    db = SessionLocal()
    try:
        booking = _load_own_booking(db, booking_id, current.id)

        if booking.status != "awaiting_costs":
            raise HTTPException(
                status_code=409,
                detail=f"Cannot finalize a booking with status '{booking.status}'",
            )

        # Each extra line needs a reason and a non-negative amount (no cap in v1).
        total_extras = 0.0
        items = []
        for item in data.extras:
            reason = (item.reason or "").strip()
            if not reason:
                raise HTTPException(status_code=400, detail="Each additional cost needs a reason")
            if item.cost < 0:
                raise HTTPException(status_code=400, detail="Additional cost cannot be negative")
            items.append({"reason": reason, "cost": round(item.cost, 2)})
            total_extras += item.cost

        booking.extras = json.dumps(items)
        booking.extra_cost = round(total_extras, 2)
        booking.status = "awaiting_confirmation"
        db.commit()
        db.refresh(booking)

        customer_user = db.query(User).filter(User.id == booking.customer_id).first()
        if customer_user and customer_user.fcm_token:
            send_to_token(
                customer_user.fcm_token,
                "Final Bill Ready",
                f"Review and approve the bill for {booking.job_title}",
                data={"route": "/confirmBill", "bookingId": str(booking.id)},
            )

        return {
            "message": "Bill submitted for customer approval",
            "status": booking.status,
            "extra_cost": booking.extra_cost,
        }
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()


@router.post("/booking/{booking_id}/confirm")
def confirm_booking(booking_id: int, current: User = Depends(require_customer)):
    """Customer approves the final bill: complete the booking and credit the worker.

    This is the single point where earnings move. Because it requires the booking
    to be in awaiting_confirmation, a repeated call sees 'completed' and is
    rejected — so the worker is credited exactly once.
    """
    db = SessionLocal()
    try:
        booking = db.query(Booking).filter(Booking.id == booking_id).first()
        if not booking:
            raise HTTPException(status_code=404, detail="Booking not found")
        if booking.customer_id != current.id:
            raise HTTPException(status_code=403, detail="This booking is not yours")
        if booking.status != "awaiting_confirmation":
            raise HTTPException(
                status_code=409,
                detail=f"Cannot confirm a booking with status '{booking.status}'",
            )

        worker = db.query(Worker).filter(Worker.user_id == booking.worker_id).first()
        if not worker:
            raise HTTPException(status_code=404, detail="Worker not found")

        # Payout from the verified figures (measured time + customer-approved extras).
        service_cost = (worker.hourly_rate or 0.0) * (booking.time_taken or 0.0)
        commission = 0.10 * service_cost
        worker_earning = service_cost - commission + (booking.extra_cost or 0.0)
        worker.money_earned = (worker.money_earned or 0.0) + worker_earning

        booking.status = "completed"
        booking.completed_at = datetime.utcnow()  # anchors the 7-day chat auto-close window
        db.commit()
        db.refresh(booking)

        customer_user = db.query(User).filter(User.id == booking.customer_id).first()
        if customer_user and customer_user.fcm_token:
            send_to_token(
                customer_user.fcm_token,
                "Job Completed ",
                f"View payslip for {booking.job_title}",
                data={"route": "/payslip", "bookingId": str(booking.id)},
            )
            send_to_token(
                customer_user.fcm_token,
                "Rate Your Worker",
                "Share feedback to help improve service quality",
                data={
                    "route": "/rate",
                    "customerId": str(booking.customer_id),
                    "workerId": str(booking.worker_id),
                    "bookingId": str(booking.id),
                },
            )

        return {"message": "Booking confirmed and completed", "status": booking.status}
    except HTTPException:
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

        # Parse the itemized extras (best-effort; older bookings have no JSON).
        try:
            extras = json.loads(booking.extras) if booking.extras else []
        except (ValueError, TypeError):
            extras = []

        service_cost = round(hourly_rate * time_taken, 2)
        commission = round(0.10 * hourly_rate * time_taken, 2)
        total_cost = round((hourly_rate * time_taken * 1.10) + extra_cost, 2)

        return {
            "worker_name": worker.name if worker else "Unknown",
            "job_title": booking.job_title,
            "status": booking.status,  # lets the customer's waiting screen poll for state
            "time_taken": time_taken,
            "extra_cost": extra_cost,
            "extra_reason": extra_reason,
            "extras": extras,
            "service_cost": service_cost,
            "commission": commission,
            "total_cost": total_cost,
        }
    finally:
        db.close()
