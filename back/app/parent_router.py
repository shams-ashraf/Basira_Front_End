from fastapi import APIRouter
from app.state_manager import state

router = APIRouter()

@router.get("/status")
async def get_child_status():
    """Endpoint for parent app to get the current state of the child assistant."""
    return {
        "current_mode": state.context.current_mode,
        "emotion": state.context.emotion,
        "last_known_location": state.context.last_known_location,
        "is_silent": state.context.is_silent,
        "danger_level": state.context.danger_level
    }

@router.get("/alerts")
async def get_recent_alerts():
    """Endpoint to fetch recent critical alerts."""
    # Stub: Fetch from relational DB
    return [
        {"timestamp": "2026-05-13T10:00:00Z", "level": "CRITICAL", "message": "Obstacle very close: stairs."}
    ]
