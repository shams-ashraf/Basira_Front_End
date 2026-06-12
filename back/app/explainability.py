from app.event_bus import bus
from app.state_manager import state
from app.personality import get_template
import logging

logger = logging.getLogger(__name__)

class ExplainabilityLayer:
    """
    Converts raw AI outputs (e.g., YOLO classes, distances) into
    child-friendly, emotionally aware natural language.
    """
    def __init__(self):
        bus.subscribe("explain_obstacle", self.explain_obstacle)
        bus.subscribe("explain_person", self.explain_person)

    async def explain_obstacle(self, data: dict):
        obj_class = data.get("class_name", "object")
        distance = data.get("distance", 1.0)
        emotion = state.context.emotion
        
        # Select appropriate language
        text = get_template(emotion, "obstacle", object=obj_class)
        logger.info(f"Explainability Layer generated: {text}")
        
        # Route to TTS
        await bus.publish("tts_request", {"text": text, "priority": "high" if distance < 1.0 else "normal"})

    async def explain_person(self, data: dict):
        person_name = data.get("name", "Unknown")
        emotion = state.context.emotion
        
        if person_name == "Unknown":
            text = get_template(emotion, "unknown_person")
        else:
            # Assuming familiar person
            text = f"Oh, {person_name} is here!"
            
        logger.info(f"Explainability Layer generated: {text}")
        await bus.publish("tts_request", {"text": text, "priority": "normal"})

explainability = ExplainabilityLayer()
