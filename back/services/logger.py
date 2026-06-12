import sys
import traceback
from datetime import datetime

from database import SessionLocal
from models import ActivityHistory, SystemLog


def log_system_event(level: str, module: str, action: str, message: str, details: str = None):
    """Logs system events to console and database."""
    prefix = f"[{level}]"
    if level == "INFO":
        color = "\033[92m"
    elif level == "WARNING":
        color = "\033[93m"
    elif level == "ERROR":
        color = "\033[91m"
    elif level == "CRITICAL":
        color = "\033[95m"
    else:
        color = ""
    reset = "\033[0m"

    print(f"{color}{prefix} {message}{reset}")
    if details:
        print(details)
    sys.stdout.flush()

    try:
        with SessionLocal() as db:
            log_item = SystemLog(
                timestamp=datetime.now().isoformat(),
                level=level,
                module=module,
                action=action,
                message=message,
                details=details,
            )
            db.add(log_item)
            db.commit()
    except Exception as e:
        print(f"⚠️ Database Log Error: {e}")
        sys.stdout.flush()


def log_activity(child_id: int, action: str, details: str):
    """Logs user and child activities to console and database."""
    print(f"\033[94m[ACTIVITY]\033[0m Child {child_id} - {action}: {details}")
    sys.stdout.flush()

    try:
        with SessionLocal() as db:
            activity = ActivityHistory(
                child_id=child_id,
                action=action,
                details=details,
                timestamp=datetime.now().isoformat(),
            )
            db.add(activity)
            db.commit()
    except Exception as e:
        print(f"⚠️ Database Activity Log Error: {e}")
        sys.stdout.flush()


def log_exception(module: str, action: str, error: Exception):
    """Logs an exception with stack trace."""
    log_system_event(
        "ERROR",
        module,
        action,
        str(error),
        details=traceback.format_exc(),
    )
