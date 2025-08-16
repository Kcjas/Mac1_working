from __future__ import annotations
import re
from datetime import datetime
from typing import Optional, List, Dict, Any, Literal

from fastapi import APIRouter
from pydantic import BaseModel, Field

from ..services import get_workers_by_skill, create_job_request  # implemented below

router = APIRouter(prefix="/convai", tags=["convai"])

# -------------------- Schemas --------------------
class MessageIn(BaseModel):
    session_id: str = Field(..., min_length=1)
    message: str = Field(..., min_length=1)
    user_id: Optional[int] = None
    user_lat: Optional[float] = None
    user_lon: Optional[float] = None

class Suggestion(BaseModel):
    id: int
    worker_id: int
    name: str
    rating: float
    hourly_rate: float
    distance: float  # km

class MessageOut(BaseModel):
    reply: str
    suggestions: Optional[List[Suggestion]] = None
    state: Dict[str, Any] = {}

# -------------------- State ----------------------
DIALOG_STATE: Dict[str, Dict[str, Any]] = {}
DEFAULT_GREETING = "Hi! Tell me what’s going on and where. I’ll find the right worker near you."

ALLOWED_SKILLS = {"plumbing", "electrical", "carpentry", "cleaning", "hvac"}
KEYWORDS = {
    "plumbing":   ["leak", "pipe", "sink", "tap", "toilet", "clog", "drain"],
    "electrical": ["light", "socket", "wiring", "switch", "breaker", "fuse", "power"],
    "carpentry":  ["door", "hinge", "shelf", "wood", "cabinet"],
    "cleaning":   ["clean", "stain", "mold", "mould", "dust", "deep clean"],
    "hvac":       ["aircon", "ac", "air con", "air conditioner", "cooling", "heating"],
}

def _classify_skill(text: str) -> str | None:
    t = text.lower()
    scores = {k: 0 for k in KEYWORDS}
    for label, words in KEYWORDS.items():
        for w in words:
            if w in t:
                scores[label] += 1
    best = max(scores, key=scores.get)
    return best if scores[best] > 0 else None

def _echo_issue(state: Dict[str, Any]) -> str:
    parts = []
    if state.get("skill"):
        parts.append(f"{state['skill']}")
    if state.get("problem"):
        parts.append(f"— {state['problem']}")
    summary = " ".join(parts) if parts else "unspecified"
    return f"Okay, I’ve captured the issue as: “{summary}”."

# -------------------- Router ---------------------
@router.post("/message", response_model=MessageOut)
def message(payload: MessageIn):
    sid = payload.session_id
    state = DIALOG_STATE.setdefault(sid, {"stage": "start", "turns": 0})
    state["turns"] += 1

    text = payload.message.strip()

    # Start: greet explicitly on hi/hello
    if state["stage"] == "start":
        if text.lower() in {"hi", "hello", "hey"}:
            state["stage"] = "gather_info"
            return MessageOut(reply=DEFAULT_GREETING, state=state)
        state["stage"] = "gather_info"  # fall through to gather

    # Opportunistic slot fill
    if "skill" not in state or not state["skill"]:
        s = _classify_skill(text)
        if s in ALLOWED_SKILLS:
            state["skill"] = s
    if "problem" not in state or not state["problem"]:
        if len(text) > 3:
            # keep it short in state to avoid huge echoes
            state["problem"] = text[:160]

    # Try to pull a simple date like "tomorrow 10:00" later if you want; optional.

    # -------- Gather info
    if state["stage"] == "gather_info":
        missing = []
        if not state.get("skill"):   missing.append("skill")
        if not state.get("problem"): missing.append("problem")

        if missing:
            slot = missing[0]
            if slot == "skill":
                return MessageOut(
                    reply="What kind of help do you need — plumbing, electrical, carpentry, cleaning, or HVAC?",
                    state=state
                )
            if slot == "problem":
                return MessageOut(
                    reply="Could you describe the problem in a sentence or two?",
                    state=state
                )

        # we have enough → propose
        suggestions_raw = get_workers_by_skill(
            skill=state["skill"],
            user_lat=payload.user_lat,
            user_lon=payload.user_lon,
            limit=5
        )
        
        suggestions: List[Suggestion] = [
             Suggestion(
                  id=int(w["user_id"]),          # show the user id (or w["id"] since we aliased it)
                  worker_id=int(w["user_id"]),   # <-- CRITICAL: this must be users.id
                  name=str(w["name"]),
                  rating=float(w.get("rating", 0.0)),
                  hourly_rate=float(w.get("hourly_rate", 0.0)),
                  distance=round(float(w.get("distance_km", 0.0)), 2),
                  )
                  for w in suggestions_raw
                ]
        state["last_suggestions"] = suggestions
        state["stage"] = "propose"

        if not suggestions:
            return MessageOut(
                reply=_echo_issue(state) + " I couldn’t find anyone nearby just yet. Say “request #1” to notify the closest available workers.",
                state=state,
            )

        bullets = "\n".join([
            f"• {s.name} — ⭐ {s.rating} • {s.distance} km • ${s.hourly_rate}/hr"
            for s in suggestions
        ])
        reply = (
            f"{_echo_issue(state)} Here are the best matches near you:\n"
            f"{bullets}\n\n"
            "Say “request #1” to send a job request, or “book #1 for tomorrow 14:00”."
        )
        return MessageOut(reply=reply, suggestions=suggestions, state=state)

    # -------- Propose: allow "request #N" immediately
    if state["stage"] == "propose":
        m = re.search(r"#(\d+)", text)
        idx = int(m.group(1)) - 1 if m else None
        lowered = text.lower()
        wants_request = "request" in lowered or "quote" in lowered
        wants_book = "book" in lowered or "schedule" in lowered

        suggestions: List[Suggestion] = state.get("last_suggestions") or []

        if wants_request and idx is not None and 0 <= idx < len(suggestions):
            chosen: Suggestion = suggestions[idx]
            # Create a minimal job-request record
            if payload.user_id and payload.user_lat is not None and payload.user_lon is not None:
                create_job_request(
                    customer_id=payload.user_id,
                    worker_id=chosen.worker_id,
                    description=state.get("problem") or state.get("skill") or "general",
                    when_dt=datetime.utcnow(),  # replace with parsed datetime if you add it
                    lat=payload.user_lat,
                    lon=payload.user_lon,
                )
                state["stage"] = "done"
                return MessageOut(
                    reply=f"Sent! Your job request to {chosen.name} is in. I’ll notify you when they respond.",
                    state=state
                )
            else:
                return MessageOut(
                    reply="I need your account and location to send the job request.",
                    state=state
                )

        if wants_book and idx is not None and 0 <= idx < len(suggestions):
            chosen: Suggestion = suggestions[idx]
            state["chosen_worker"] = chosen.model_dump()
            state["stage"] = "confirm"
            return MessageOut(
                reply=f"Great, I’ll contact {chosen.name}. Should I **send a job request** now, or do you want to **book** directly for a specific time?",
                state=state
            )

        return MessageOut(
            reply="Please choose a worker like “request #1” or “book #2”.",
            state=state
        )

    # -------- Confirm
    if state["stage"] == "confirm":
        lowered = text.lower()
        wants_request = "request" in lowered or "quote" in lowered
        wants_book = "book" in lowered or "schedule" in lowered
        chosen = state.get("chosen_worker")

        if wants_request and chosen and payload.user_id and payload.user_lat is not None and payload.user_lon is not None:
            create_job_request(
                customer_id=payload.user_id,
                worker_id=chosen["worker_id"],
                description=state.get("problem") or state.get("skill") or "general",
                when_dt=datetime.utcnow(),
                lat=payload.user_lat,
                lon=payload.user_lon,
            )
            state["stage"] = "done"
            return MessageOut(
                reply=f"Sent! Your job request to {chosen['name']} is in. I’ll notify you when they respond.",
                state=state
            )

        if wants_book and chosen:
            state["stage"] = "done"
            return MessageOut(
                reply=_echo_issue(state) + " I’ll take you to the booking screen with the details pre‑filled.",
                state=state
            )

        return MessageOut(
            reply="Say “book” to proceed with direct booking, or “request” to send a job request first.",
            state=state
        )

    # -------- Done
    if state["stage"] == "done":
        return MessageOut(reply="All set. Need anything else?", state=state)

    return MessageOut(reply="Sorry, I didn’t follow that. Could you rephrase?", state=state)
