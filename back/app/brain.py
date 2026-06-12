from typing import Any, Dict
from app.event_bus import bus
from app.state_manager import state, SystemMode, EmotionState
import logging

logger = logging.getLogger(__name__)

class OrchestratorBrain:
    """
    The central intelligence unit.
    Decides what to do based on events, routes to correct models.
    """
    def __init__(self):
        # Bind core events
        bus.subscribe("voice_input_received", self.handle_voice_input)
        bus.subscribe("obstacle_detected", self.handle_obstacle)
        bus.subscribe("emotion_inferred", self.handle_emotion_change)
        
    async def start(self):
        bus.start()
        logger.info("Orchestrator Brain is active.")

    async def handle_voice_input(self, data: Dict[str, Any]):
        """
        Smart Path entry point.
        Analyzes intent and routes.
        """
        text = data.get("text", "")
        logger.info(f"Brain processing voice input: {text}")
        state.update_interaction()
        
        # Simple rule-based intent for now.
        if "where" in text.lower() or "find" in text.lower():
            await bus.publish("intent_find_object", data)
        elif "read" in text.lower():
            await bus.publish("intent_read_text", data)
        else:
            await bus.publish("intent_chat", data)

    async def handle_obstacle(self, data: Dict[str, Any]):
        """
        Fast Path entry point.
        """
        distance = data.get("distance", 1.0)
        obj_class = data.get("class_name", "object")
        
        if distance < 0.8:
            logger.warning(f"CRITICAL: {obj_class} at {distance}m")
            # Interrupt current TTS/Chat
            await bus.publish("cancel_tts")
            
            # Send immediate warning via Explainability layer
            warning_text = f"Stop, there is a {obj_class} right in front of you."
            await bus.publish("tts_request", {"text": warning_text, "priority": "high"})
            
            state.update_mode(SystemMode.EMERGENCY)

    async def handle_emotion_change(self, data: Dict[str, Any]):
        emotion_str = data.get("emotion")
        try:
            emotion = EmotionState(emotion_str)
            state.update_emotion(emotion)
            logger.info(f"Child emotion updated to: {emotion}")
        except ValueError:
            pass

brain = OrchestratorBrain()
