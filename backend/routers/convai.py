from fastapi import APIRouter, HTTPException, Body
from pydantic import BaseModel, Field, validator
from datetime import datetime, timedelta
from typing import Optional, Dict, Any, List, Literal
import re


from ..services import get_workers_by_skill

router = APIRouter(prefix="/convai", tags=["ConversationalAI"])


SESSIONS: Dict[str, Dict[str, Any]] = {}
SESSION_TTL = timedelta(hours=4)  

Skill = Literal["plumber", "electrician", "cleaning", "hvac"]
ALLOWED_SKILLS: set[str] = {"plumber", "electrician", "cleaning", "hvac"}

class WorkerSuggestion(BaseModel):
    worker_id: int
    name: str
    rating: float = Field(ge=0, le=5)
    distance: float = Field(ge=0)  # km
    hourly_rate: float = Field(ge=0)

class ChatIn(BaseModel):
    session_id: str
    message: str
    user_id: Optional[int] = None
    user_lat: Optional[float] = None
    user_lon: Optional[float] = None

    @validator("session_id")
    def _strip_sid(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("session_id required")
        return v

class ChatOut(BaseModel):
    session_id: str
    reply: str
    suggestions: Optional[List[WorkerSuggestion]] = None
    state: Dict[str, Any]
    redirect: Optional[Dict[str, Any]] = None

INTENT_KEYWORDS = {
    "greet": [" hi ", " hello ", " hey ", " good morning ", " good evening "],
    "goodbye": [" bye ", " goodbye ", " see you ", " cya ", " later "],
    "help": [" help ", " support ", " need "],
    "problem_report": [
        " leak ", " tap ", " pipe ", " clog ", " drain ",
        " light ", " fuse ", " wire ", " short ",
        " clean ", " dust ", " vacuum ",
        " ac ", " aircon ", " hvac ", " cooling ", " air conditioner ", " heat "
    ],
}

SKILL_KEYWORDS: Dict[Skill, List[str]] = {
    "plumber":      [" leak ", " tap ", " pipe ", " clog ", " drain ", " water ", " plumb "],
    "electrician":  [" electric ", " light ", " fuse ", " wire ", " short ", " fan ", " power "],
    "cleaning":     [" clean ", " dust ", " vacuum ", " maid ", " tidy ", " sweep "],
    "hvac":         [" ac ", " aircon ", " hvac ", " cooling ", " air conditioner ", " heat "],
}

NUM_WORDS = {
    "one": 1, "first": 1, "1st": 1,
    "two": 2, "second": 2, "2nd": 2,
    "three": 3, "third": 3, "3rd": 3,
}

def _pad(t: str) -> str:
    return f" {t.lower().strip()} "

def detect_intent(text: str) -> str:
    t = _pad(text)
    for intent, words in INTENT_KEYWORDS.items():
        if any(w in t for w in words):
            return intent
    return "unknown"

def detect_skill(text: str) -> Optional[Skill]:
    t = _pad(text)
    for sk in ALLOWED_SKILLS:
        if f" {sk} " in t:
            return sk  
    for skill, words in SKILL_KEYWORDS.items():
        if any(w in t for w in words):
            return skill
    return None

def extract_choice(text: str, max_choice: int) -> Optional[int]:
    t = _pad(text)
    m = re.search(r"\b([1-9])\b", t)
    if m:
        val = int(m.group(1))
        if 1 <= val <= max_choice:
            return val
    for k, v in NUM_WORDS.items():
        if f" {k} " in t and 1 <= v <= max_choice:
            return v
    return None

def location_ok(lat: Optional[float], lon: Optional[float]) -> bool:
    if lat is None or lon is None:
        return False
    return -90.0 <= lat <= 90.0 and -180.0 <= lon <= 180.0

def init_session(session_id: str) -> Dict[str, Any]:
    state: Dict[str, Any] = {
        "intent": None,
        "skill": None,
        "problem": None,
        "stage": "start",  
        "last_suggestions": [],
        "redirect": None,
        "touched_at": datetime.utcnow(),
    }
    SESSIONS[session_id] = state
    return state

def touch(state: Dict[str, Any]) -> None:
    state["touched_at"] = datetime.utcnow()

def get_state(sid: str) -> Dict[str, Any]:
    state = SESSIONS.get(sid)
    if not state:
        return init_session(sid)
    last = state.get("touched_at")
    if isinstance(last, datetime) and datetime.utcnow() - last > SESSION_TTL:
        return init_session(sid)
    return state



def act_search_workers(skill: Skill, user_lat: float, user_lon: float) -> List[WorkerSuggestion]:
    raw = get_workers_by_skill(skill=skill, user_lat=user_lat, user_lon=user_lon) or []
    out: List[WorkerSuggestion] = []
    for r in raw[:3]:
        wid = (
            r.get("profile_id")
            or r.get("id")
            or r.get("user_id")
        )
        if wid is None:
            continue
        out.append(WorkerSuggestion(
            worker_id=int(wid),
            name=str(r.get("name") or f"Worker {wid}"),
            rating=float(r.get("rating") or 0.0),
            distance=float(r.get("distance_km") or 0.0),  
            hourly_rate=float(r.get("hourly_rate") or 0.0),
        ))
    return out




def policy(state: Dict[str, Any], user_msg: str, meta: Dict[str, Any]) -> str:
    touch(state)
    user_msg_lower = user_msg.lower().strip()

    if state["stage"] == "start":
        detected_intent = detect_intent(user_msg)
        detected_skill = detect_skill(user_msg)

        if detected_intent == "greet" and not detected_skill:
            state["stage"] = "identify_skill"
            return "Hi! I can help you find workers. What type of service do you need? (plumber, electrician, cleaning, or HVAC)"

        if detected_skill:
            state["skill"] = detected_skill
            state["problem"] = user_msg
            state["stage"] = "show_workers"
        else:
            state["stage"] = "identify_skill"
            return "Hi! I can help you find workers. What type of service do you need? (plumber, electrician, cleaning, or HVAC)"

    if state["stage"] == "identify_skill":
        detected_skill = detect_skill(user_msg)

        if detected_skill:
            state["skill"] = detected_skill
            state["problem"] = user_msg
            state["stage"] = "show_workers"
        else:
            return "I didn't catch that. Which service do you need? (plumber, electrician, cleaning, or HVAC)"

    if state["stage"] == "show_workers":
        skill: Optional[Skill] = state.get("skill")
        if not skill or skill not in ALLOWED_SKILLS:
            state["stage"] = "identify_skill"
            return "What type of service do you need? (plumber, electrician, cleaning, or HVAC)"

        if not location_ok(meta.get("user_lat"), meta.get("user_lon")):
            return "Please share a valid location (latitude & longitude) so I can find nearby workers."

        suggestions = act_search_workers(skill, float(meta["user_lat"]), float(meta["user_lon"]))
        lines = [
            f"{i}. {w.name} • ⭐ {w.rating:.1f}/5 • {w.distance:.1f} km away • ${w.hourly_rate:.2f}/hr"
            for i, w in enumerate(suggestions, 1)
        ]       
        state["last_suggestions"] = [w.dict() for w in suggestions]
        state["stage"] = "choose_worker"
        return (
            f"Here are the top {skill}s near you:\n\n"
            + "\n".join(lines)
            + "\n\nReply with 1, 2, or 3 to open a job request with that worker."
        ) 
    
    if state["stage"] == "choose_worker":
        suggestions: List[Dict[str, Any]] = state.get("last_suggestions") or []
        if not suggestions:
            state["stage"] = "identify_skill"
            return "Let's try again. Which service do you need? (plumber, electrician, cleaning, or HVAC)"

        # Use the lowercase version for parsing (extract_choice normalizes anyway)
        choice = extract_choice(user_msg_lower, max_choice=len(suggestions))
        if choice is None:
            return "Please reply with 1, 2, or 3 to choose a worker."

        chosen = suggestions[choice - 1]  # dict

        # Build redirect payload in the shape the Flutter client expects
        state["redirect"] = {
            "path": "/job-request",
            "params": {
                "workerId": chosen["worker_id"],
                "workerName": chosen["name"],
                "workerSkill": state.get("skill"),
                "hourlyRate": chosen["hourly_rate"],
                "distance": chosen["distance"],
                "problem": state.get("problem"),
                "customerId": meta.get("user_id"),
                "customerLat": meta.get("user_lat"),
                "customerLon": meta.get("user_lon"),
            }
        }

        state["stage"] = "done"
        return f"Perfect — opening the job request page for {chosen['name']}…"

    if state["stage"] == "done":
        state.update({
            "intent": None,
            "skill": None,
            "problem": None,
            "stage": "start",
            "last_suggestions": [],
            "redirect": None,
        })
        return "Is there anything else I can help you with?"

    return "I'm not sure what you mean. Type 'help' to start over."


@router.post("/message", response_model=ChatOut)
def convai_message(payload: ChatIn):
    state = get_state(payload.session_id)

    reply = policy(state, payload.message, {
        "user_id": payload.user_id,
        "user_lat": payload.user_lat,
        "user_lon": payload.user_lon,
    })

    redirect_payload = state.get("redirect")
    if redirect_payload:
        state["redirect"] = None
    suggestions = state.get("last_suggestions") or None
    suggestions_model = [WorkerSuggestion(**s) for s in suggestions] if suggestions else None
    return ChatOut(
        session_id=payload.session_id,
        reply=reply,
        suggestions=suggestions_model,
        state=state,
        redirect=redirect_payload,
    )

@router.post("/reset", response_model=ChatOut)
def convai_reset(session_id: str = Body(..., embed=True)):
    state = init_session(session_id)
    return ChatOut(
        session_id=session_id,
        reply="New conversation started. What type of service do you need? (plumber, electrician, cleaning, or HVAC)",
        state=state
    )

@router.get("/state", response_model=Dict[str, Any])
def convai_state(session_id: str):
    return get_state(session_id)
