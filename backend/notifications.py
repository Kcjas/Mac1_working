import os
import logging
from typing import Iterable, Optional, Dict
try:
    import firebase_admin
    from firebase_admin import credentials, messaging
except Exception as e: 
    firebase_admin = None
    credentials = None
    messaging = None

logger = logging.getLogger("notifications")
logger.setLevel(logging.INFO)
_FCM_ENABLED = False
def _init_firebase() -> None:
    global _FCM_ENABLED
    if _FCM_ENABLED:
        return
    if firebase_admin is None:
        logger.warning("Firebase Admin SDK not installed; notifications disabled.")
        return

    if firebase_admin._apps:
        _FCM_ENABLED = True
        return
    
    key_path = os.path.join(os.path.dirname(__file__), "firebase_admin.json")
    os.environ["FIREBASE_ADMIN_CREDENTIALS"] = key_path
    key_path = os.getenv("FIREBASE_ADMIN_CREDENTIALS", "firebase_admin.json")
    if not os.path.exists(key_path):
        logger.warning(
            "Firebase service account JSON not found at '%s'. "
            "Set FIREBASE_ADMIN_CREDENTIALS or place firebase_admin.json in project root.",
            key_path,
        )
        return

    try:
        cred = credentials.Certificate(key_path)
        firebase_admin.initialize_app(cred)
        _FCM_ENABLED = True
        logger.info("Firebase Admin initialized.")
    except Exception as e:
        logger.exception("Failed to initialize Firebase Admin: %s", e)
        _FCM_ENABLED = False

_init_firebase()

def send_to_token(token: str,title: str,body: str,data: Optional[Dict[str, str]] = None,) -> str:
    if not _FCM_ENABLED:
        logger.warning("FCM disabled; skipping send_to_token(title=%r).", title)
        return "disabled"
    if not token:
        return "no-token"

    try:
        msg = messaging.Message(notification=messaging.Notification(title=title, body=body), data=data or {}, token=token,)
        resp = messaging.send(msg)
        logger.info("Push sent to token: %s (msgId=%s)", token[:12] + "…", resp)
        return resp
    except Exception as e:
        logger.exception("send_to_token failed: %s", e)
        return f"error:{e}"

def send_multicast(
    tokens: Iterable[str],
    title: str,
    body: str,
    data: Optional[Dict[str, str]] = None,
) -> Dict[str, int]:
    if not _FCM_ENABLED:
        logger.warning("FCM disabled; skipping send_multicast(title=%r).", title)
        return {"success": 0, "failure": 0}

    tokens = [t for t in tokens if t]
    if not tokens:
        return {"success": 0, "failure": 0}

    try:
        msg = messaging.MulticastMessage(
            notification=messaging.Notification(title=title, body=body),
            data=data or {},
            tokens=tokens,
        )
        resp = messaging.send_multicast(msg)
        logger.info("Multicast: %d success, %d failure", resp.success_count, resp.failure_count)
        return {"success": resp.success_count, "failure": resp.failure_count}
    except Exception as e:
        logger.exception("send_multicast failed: %s", e)
        return {"success": 0, "failure": 0}


def send_to_topic(
    topic: str,
    title: str,
    body: str,
    data: Optional[Dict[str, str]] = None,
) -> str:
    if not _FCM_ENABLED:
        logger.warning("FCM disabled; skipping send_to_topic(title=%r).", title)
        return "disabled"
    if not topic:
        return "no-topic"

    try:
        msg = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data=data or {},
            topic=topic,
        )
        resp = messaging.send(msg)
        logger.info("Push sent to topic '%s' (msgId=%s).", topic, resp)
        return resp
    except Exception as e:
        logger.exception("send_to_topic failed: %s", e)
        return f"error:{e}"
