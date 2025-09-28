from fastapi import APIRouter, HTTPException, Body
from pydantic import BaseModel
from datetime import datetime
from typing import Optional, Dict, Any, List
import re

# Import ONLY shared modules (never from main.py)
from ..services import get_workers_by_skill  # note: no create_job_request import

router = APIRouter(prefix="/convai", tags=["ConversationalAI"])

# ---------------- Session store (swap to Redis/DB in prod) ----------------
SESSIONS: Dict[str, Dict[str, Any]] = {}

# ---------------- Schemas ----------------
class ChatIn(BaseModel):
    session_id: str
    message: str
    user_id: Optional[int] = None
    user_lat: Optional[float] = None
    user_lon: Optional[float] = None

class ChatOut(BaseModel):
    session_id: str
    reply: str
    suggestions: Optional[List[Dict[str, Any]]] = None
    state: Dict[str, Any]
    # New: tell the client to navigate to a page (frontend handles the redirect)
    redirect: Optional[Dict[str, Any]] = None

# ---------------- NLU (simple; upgrade later) ----------------
ALLOWED_SKILLS = {"plumber", "electrician", "cleaning", "hvac"}

INTENT_KEYWORDS = {
    "greet": ["hi", "hello", "hey"],
    "goodbye": ["bye", "goodbye", "see you"],
    "help": ["help", "support"],
    # removed: "book" intent — request-only flow
    "request": ["request", "quote", "estimate"],
    "problem_report": [
        "leak", "tap", "pipe", "clog", "drain",
        "light", "fuse", "wire", "short",
        "clean", "dust", "vacuum",
        "ac", "aircon", "hvac", "cooling", "air conditioner"
    ],
}

SKILL_KEYWORDS = {
    "plumber": ["leak", "tap", "pipe", "clog", "drain"],
    "electrician": ["electric", "light", "fuse", "wire", "short", "fan"],
    "cleaning": ["clean", "dust", "vacuum", "maid"],
    "hvac": ["ac", "aircon", "hvac", "cooling", "air conditioner"],
}

def detect_intent(text: str) -> str:
    t = text.lower()
    for intent, words in INTENT_KEYWORDS.items():
        if any(w in t for w in words):
            return intent
    return "unknown"


def detect_skill(text: str) -> Optional[str]:
    t = text.lower()
    for skill, words in SKILL_KEYWORDS.items():
        if any(w in t for w in words):
            return skill
    return None


DATE_RE = re.compile(r"(\b(?:today|tomorrow)\b|\b\d{4}-\d{2}-\d{2}\b|\b\d{1,2}/\d{1,2}/\d{2,4}\b)")
TIME_RE = re.compile(r"\b(\d{1,2}:\d{2})\b")

def extract_datetime(text: str) -> Optional[datetime]:
    txt = text.lower()
    now = datetime.now()
    m_date = DATE_RE.search(txt)
    m_time = TIME_RE.search(txt)

    date = None
    if m_date:
        token = m_date.group(1)
        if token == "today":
            date = now.date()
        elif token == "tomorrow":
            date = now.date().fromordinal(now.date().toordinal() + 1)
        else:
            try:
                if "-" in token:
                    date = datetime.strptime(token, "%Y-%m-%d").date()
                else:
                    parts = token.split("/")
                    if len(parts[2]) == 2:
                        parts[2] = "20" + parts[2]
                    date = datetime.strptime("/".join(parts), "%d/%m/%Y").date()
            except:  # noqa: E722 — keep simple here
                pass

    time = None
    if m_time:
        try:
            time = datetime.strptime(m_time.group(1), "%H:%M").time()
        except:  # noqa: E722
            pass

    if date and time:
        return datetime.combine(date, time)
    if date:
        return datetime.combine(date, datetime.strptime("10:00", "%H:%M").time())
    return None

# ---------------- State helpers ----------------

def init_session(session_id: str) -> Dict[str, Any]:
    state: Dict[str, Any] = {
        "intent": None,
        "skill": None,
        "problem": None,
        "preferred_datetime": None,
        "address": None,
        "stage": "start",            # start -> gather_info -> propose -> confirm -> done
        "last_suggestions": [],
        "chosen_worker": None,
        # store a one-shot redirect to be emitted in ChatOut
        "redirect": None,
    }
    SESSIONS[session_id] = state
    return state


def need_slots(state: Dict[str, Any]) -> List[str]:
    needed: List[str] = []
    if not state.get("skill"):
        needed.append("skill")
    if not state.get("problem"):
        needed.append("problem")
    if not state.get("preferred_datetime"):
        needed.append("preferred_datetime")
    if not state.get("address"):
        needed.append("address")
    return needed

# ---------------- Actions ----------------

def act_search_workers(skill: str, user_lat: float, user_lon: float) -> List[Dict[str, Any]]:
    # Use shared service (already sorts by distance)
    results = get_workers_by_skill(skill, customer_lat=user_lat, customer_lon=user_lon)
    return results[:3]

# ---------------- Dialog policy ----------------

def policy(state: Dict[str, Any], user_msg: str, meta: Dict[str, Any]) -> str:
    if not state.get("intent") or state["intent"] == "unknown":
        state["intent"] = detect_intent(user_msg) or "help"

    # fill slots opportunistically
    if not state.get("skill"):
        s = detect_skill(user_msg)
        if s in ALLOWED_SKILLS:
            state["skill"] = s
    if not state.get("problem"):
        if len(user_msg.strip()) > 3:
            state["problem"] = user_msg.strip()
    if not state.get("preferred_datetime"):
        dt = extract_datetime(user_msg)
        if dt:
            state["preferred_datetime"] = dt.isoformat()
    if not state.get("address"):
        if " at " in user_msg.lower():
            state["address"] = user_msg.split(" at ", 1)[1].strip()

    needed = need_slots(state)

    if state["stage"] == "start":
        state["stage"] = "gather_info"
        return "Hi! Tell me what’s going on and where. I’ll find the right worker and take you to the request form."

    if state["stage"] == "gather_info":
        if needed:
            slot = needed[0]
            if slot == "skill":
                return "What kind of help do you need — plumber, electrician, cleaning, or HVAC?"
            if slot == "problem":
                return "Could you describe the problem in a sentence or two?"
            if slot == "preferred_datetime":
                return "When would you like this done? (e.g., 2025-08-16 14:00 or 'tomorrow 10:00')"
            if slot == "address":
                return "What’s the service address?"
        # all slots present → propose workers
        if not (meta.get("user_lat") and meta.get("user_lon")):
            return "Share your location so I can find the nearest available workers."
        suggestions = act_search_workers(state["skill"], meta["user_lat"], meta["user_lon"])
        state["last_suggestions"] = suggestions
        state["stage"] = "propose"
        if not suggestions:
            return (
                f"Sorry, I couldn’t find any {state['skill']}s nearby right now. "
                "Want to open the Job Request page so workers can respond?"
            )
        bullets = [
            f"- {s['name']} • ⭐ {s['rating']}/5 • {s['distance']} km • ${s['hourly_rate']}/hr"
            for s in suggestions
        ]
        return (
            "Here are the best matches near you:\n" + "\n".join(bullets) +
            "\n\nSay ‘request #1’ to open the Job Request page for that worker."
        )

    if state["stage"] == "propose":
        # choose worker index
        idx = None
        m = re.search(r"#(\d+)", user_msg)
        if m:
            idx = int(m.group(1)) - 1
        if idx is None and state["last_suggestions"]:
            if "first" in user_msg.lower():
                idx = 0
        if idx is not None and 0 <= idx < len(state["last_suggestions"]):
            chosen = state["last_suggestions"][idx]
            state["chosen_worker"] = chosen
            state["stage"] = "confirm"
            return (
                f"Great, I’ll open the Job Request form for {chosen['name']}. "
                f"Confirm and I’ll prepare the redirect."
            )
        return "Please choose a worker like ‘request #1’."

    if state["stage"] == "confirm":
        chosen = state.get("chosen_worker")
        if not chosen:
            state["stage"] = "propose"
            return "Which worker would you like? (e.g., ‘request #1’)"

        # Instead of creating a server-side JobRequest, emit a redirect instruction.
        state["stage"] = "done"
        state["redirect"] = {
            "path": "/job-request",  # frontend route/screen
            "params": {
                "worker_id": chosen["worker_id"],
                "worker_name": chosen["name"],
                "hourly_rate": chosen["hourly_rate"],
                # optional prefill from gathered state
                "preferred_datetime": state.get("preferred_datetime"),
                "address": state.get("address"),
                "problem": state.get("problem"),
            }
        }
        return f"Opening the Job Request page for {chosen['name']}…"

    if state["stage"] == "done":
        return "All set. Need anything else?"

    return "Sorry, I didn’t follow that. Could you rephrase?"

# ---------------- Public endpoints ----------------

@router.post("/message", response_model=ChatOut)
def convai_message(payload: ChatIn):
    sid = payload.session_id.strip()
    if not sid:
        raise HTTPException(status_code=400, detail="session_id required")

    state = SESSIONS.get(sid) or init_session(sid)
    if not state.get("intent") or state["intent"] == "unknown":
        state["intent"] = detect_intent(payload.message)

    reply = policy(state, payload.message, {
        "user_id": payload.user_id,
        "user_lat": payload.user_lat,
        "user_lon": payload.user_lon,
    })

    # return the redirect instruction once; client may clear it after navigation
    redirect_payload = state.get("redirect")

    return ChatOut(
        session_id=sid,
        reply=reply,
        suggestions=state.get("last_suggestions") or None,
        state=state,
        redirect=redirect_payload,
    )


@router.post("/reset", response_model=ChatOut)
def convai_reset(session_id: str = Body(..., embed=True)):
    state = init_session(session_id)
    return ChatOut(session_id=session_id, reply="New conversation started. How can I help?", state=state)


@router.get("/state", response_model=Dict[str, Any])
def convai_state(session_id: str):
    if session_id not in SESSIONS:
        init_session(session_id)
    return SESSIONS[session_id]
