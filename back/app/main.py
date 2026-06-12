from server import app
from app.event_bus import bus
from app.brain import brain
from fastapi import APIRouter
from app.state_manager import state

# Include orchestrator routes if needed or stub them
orchestrator_router = APIRouter()

@orchestrator_router.get("/status", tags=["Orchestrator"])
async def get_child_status():
    return {
        "current_mode": state.context.current_mode,
        "emotion": state.context.emotion,
        "last_known_location": state.context.last_known_location,
        "is_silent": state.context.is_silent,
        "danger_level": state.context.danger_level
    }

app.include_router(orchestrator_router, prefix="/api/v1/orchestrator")

@app.on_event("startup")
async def startup_event():
    """Start the event bus and orchestrator when the server starts."""
    await brain.start()

@app.on_event("shutdown")
async def shutdown_event():
    """Cleanly shut down the event bus."""
    await bus.stop()
