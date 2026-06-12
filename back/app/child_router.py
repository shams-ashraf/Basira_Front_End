from fastapi import APIRouter, HTTPException, BackgroundTasks
from pydantic import BaseModel
from typing import Optional
from app.event_bus import bus
from app.state_manager import state, EmotionState

router = APIRouter()

class VoiceInput(BaseModel):
    text: str
    inferred_emotion: Optional[str] = None

class CameraFrameEvent(BaseModel):
    # In reality, this might be a multipart form data for image bytes
    # For now, representing metadata
    timestamp: float
    mode_override: Optional[str] = None

@router.post("/voice")
async def receive_voice(payload: VoiceInput):
    """Endpoint for child app to send transcribed voice text."""
    if payload.inferred_emotion:
        await bus.publish("emotion_inferred", {"emotion": payload.inferred_emotion})
        
    await bus.publish("voice_input_received", {"text": payload.text})
    return {"status": "processing"}

@router.post("/emotion")
async def update_emotion(emotion: str):
    """Endpoint to update child's inferred emotional state explicitly."""
    try:
        emo_enum = EmotionState(emotion.upper())
        state.update_emotion(emo_enum)
        return {"status": "success", "current_emotion": state.context.emotion}
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid emotion state")
