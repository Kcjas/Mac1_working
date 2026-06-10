# backend/routers/chat.py
"""1:1 messaging between the customer and the worker of a booking.

The booking is the chat "room": only its two parties (customer_id / worker_id)
may read or post. Chat opens at booking creation and stays open until 7 days
after the booking is completed, after which it is closed unless an admin has
flipped ``chat_force_open``.

Delivery is poll-based (no WebSocket layer in this stack). Reads are pure GETs;
marking messages read is a separate explicit POST so refreshes / multiple
devices never silently mutate state.
"""

from datetime import datetime, timedelta
from typing import Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel, Field
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from ..database import SessionLocal
from ..models import User, Booking, Message
from ..notifications import send_to_token
from ..auth_deps import get_current_user
from ..limiter import limiter

router = APIRouter(prefix="/chat", tags=["Chat"])

CHAT_RETENTION = timedelta(days=7)
MAX_BODY_LEN = 2000
MIN_SEND_INTERVAL = timedelta(seconds=1)  # per-sender-per-booking burst guard

_CHAT_CLOSED = HTTPException(
    status_code=status.HTTP_403_FORBIDDEN,
    detail="Chat is closed for this booking",
)
_NOT_A_PARTY = HTTPException(
    status_code=status.HTTP_403_FORBIDDEN,
    detail="You are not a participant in this booking",
)


class SendIn(BaseModel):
    body: str = Field(..., min_length=1, max_length=MAX_BODY_LEN)
    message_type: str = "text"


class ReadIn(BaseModel):
    up_to_id: int


def unread_counts(db: Session, booking_ids: List[int], viewer_id: int) -> Dict[int, int]:
    """Map of booking_id -> count of messages unread by ``viewer_id`` (i.e.
    sent by the other party and not yet marked read). One grouped query so
    list endpoints don't fan out into N requests."""
    if not booking_ids:
        return {}
    rows = (
        db.query(Message.booking_id, func.count(Message.id))
        .filter(
            Message.booking_id.in_(booking_ids),
            Message.sender_id != viewer_id,
            Message.read_at.is_(None),
        )
        .group_by(Message.booking_id)
        .all()
    )
    return {bid: cnt for bid, cnt in rows}


def _authorize_booking(db: Session, booking_id: int, user: User) -> Booking:
    """Load the booking and ensure ``user`` is the customer or the worker."""
    booking = db.query(Booking).filter(Booking.id == booking_id).first()
    if not booking:
        raise HTTPException(status_code=404, detail="Booking not found")
    if user.id not in (booking.customer_id, booking.worker_id):
        raise _NOT_A_PARTY
    return booking


def _chat_open(booking: Booking) -> bool:
    """Chat is open while the job is active, or within 7 days of completion,
    or whenever an admin has force-reopened it."""
    if booking.chat_force_open:
        return True
    if booking.status != "completed":
        return True
    if booking.completed_at is None:
        # Completed without a recorded timestamp (legacy row) -> treat as closed.
        return False
    return datetime.utcnow() <= booking.completed_at + CHAT_RETENTION


def _serialize(m: Message, user_id: int) -> dict:
    return {
        "id": m.id,
        "sender_id": m.sender_id,
        "body": m.body,
        "message_type": m.message_type,
        "created_at": m.created_at.isoformat() if m.created_at else None,
        "read_at": m.read_at.isoformat() if m.read_at else None,
        "is_mine": m.sender_id == user_id,
    }


@router.get("/threads")
def list_threads(user: User = Depends(get_current_user)):
    """Inbox: every booking the current user is a party to that has at least one
    message, newest activity first. Each entry carries the other party's name, a
    last-message preview, the unread count, and whether chat is still open."""
    db = SessionLocal()
    try:
        bookings = (
            db.query(Booking)
            .filter(or_(Booking.customer_id == user.id, Booking.worker_id == user.id))
            .all()
        )
        unread = unread_counts(db, [b.id for b in bookings], viewer_id=user.id)

        threads = []
        for b in bookings:
            last = (
                db.query(Message)
                .filter(Message.booking_id == b.id)
                .order_by(Message.id.desc())
                .first()
            )
            if last is None:
                continue  # inbox shows only conversations that have messages
            other_id = b.worker_id if user.id == b.customer_id else b.customer_id
            other = db.query(User).filter(User.id == other_id).first()
            threads.append({
                "booking_id": b.id,
                "job_title": b.job_title,
                "other_id": other_id,
                "other_name": other.name if other else "User",
                "unread_count": unread.get(b.id, 0),
                "chat_open": _chat_open(b),
                "last_body": last.body,
                "last_at": last.created_at.isoformat() if last.created_at else None,
                "last_is_mine": last.sender_id == user.id,
            })

        threads.sort(key=lambda t: t["last_at"] or "", reverse=True)
        return {
            "total_unread": sum(t["unread_count"] for t in threads),
            "threads": threads,
        }
    finally:
        db.close()


@router.get("/{booking_id}/messages")
def list_messages(
    booking_id: int,
    after_id: Optional[int] = None,
    user: User = Depends(get_current_user),
):
    """Pure read. Returns messages ordered by id, optionally only those newer
    than ``after_id`` for incremental polling. Never mutates state."""
    db = SessionLocal()
    try:
        booking = _authorize_booking(db, booking_id, user)
        q = db.query(Message).filter(Message.booking_id == booking_id)
        if after_id is not None:
            q = q.filter(Message.id > after_id)
        messages = q.order_by(Message.id.asc()).all()
        return {
            "chat_open": _chat_open(booking),
            "messages": [_serialize(m, user.id) for m in messages],
        }
    finally:
        db.close()


@router.post("/{booking_id}/messages")
@limiter.limit("20/minute")
def send_message(
    booking_id: int,
    payload: SendIn,
    request: Request,
    user: User = Depends(get_current_user),
):
    db = SessionLocal()
    try:
        booking = _authorize_booking(db, booking_id, user)
        if not _chat_open(booking):
            raise _CHAT_CLOSED

        body = payload.body.strip()
        if not body:
            raise HTTPException(status_code=400, detail="Message body is empty")

        # Per-(sender, booking) burst guard.
        last = (
            db.query(Message)
            .filter(Message.booking_id == booking_id, Message.sender_id == user.id)
            .order_by(Message.id.desc())
            .first()
        )
        if last and last.created_at and (
            datetime.utcnow() - last.created_at < MIN_SEND_INTERVAL
        ):
            raise HTTPException(status_code=429, detail="You're sending messages too fast")

        msg = Message(
            booking_id=booking_id,
            sender_id=user.id,
            body=body,
            message_type=payload.message_type or "text",
        )
        db.add(msg)
        db.commit()
        db.refresh(msg)

        # Notify the other party (only while chat is open).
        other_id = booking.worker_id if user.id == booking.customer_id else booking.customer_id
        other = db.query(User).filter(User.id == other_id).first()
        if other and other.fcm_token:
            send_to_token(
                other.fcm_token,
                user.name or "New message",
                body if len(body) <= 120 else body[:117] + "…",
                data={"route": "/chat", "bookingId": str(booking_id)},
            )

        return _serialize(msg, user.id)
    except HTTPException:
        db.rollback()
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()


@router.post("/{booking_id}/read")
def mark_read(
    booking_id: int,
    payload: ReadIn,
    user: User = Depends(get_current_user),
):
    """Mark the other party's messages (id <= up_to_id) as read. The only
    endpoint that mutates read state."""
    db = SessionLocal()
    try:
        _authorize_booking(db, booking_id, user)
        updated = (
            db.query(Message)
            .filter(
                Message.booking_id == booking_id,
                Message.sender_id != user.id,
                Message.id <= payload.up_to_id,
                Message.read_at.is_(None),
            )
            .update({Message.read_at: datetime.utcnow()}, synchronize_session=False)
        )
        db.commit()
        return {"updated": updated}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()
