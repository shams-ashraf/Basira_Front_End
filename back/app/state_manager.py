from enum import Enum
from pydantic import BaseModel
from typing import Optional
import time

class SystemMode(str, Enum):
    INDOOR = "INDOOR"
    OUTDOOR = "OUTDOOR"
    PERSON_FOCUS = "PERSON_FOCUS"
    EMERGENCY = "EMERGENCY"
    GENERAL = "GENERAL"

class EmotionState(str, Enum):
    CALM = "CALM"
    STRESSED = "STRESSED"
    CURIOUS = "CURIOUS"
    WITHDRAWN = "WITHDRAWN"

class ChildContext(BaseModel):
    current_mode: SystemMode = SystemMode.GENERAL
    emotion: EmotionState = EmotionState.CALM
    last_known_location: Optional[str] = None
    is_silent: bool = False
    last_interaction_time: float = time.time()
    danger_level: int = 0  # 0 to 10

class StateManager:
    """
    Manages the global state and context of the child.
    """
    def __init__(self):
        self.context = ChildContext()

    def update_mode(self, mode: SystemMode):
        self.context.current_mode = mode

    def update_emotion(self, emotion: EmotionState):
        self.context.emotion = emotion

    def update_interaction(self):
        self.context.is_silent = False
        self.context.last_interaction_time = time.time()

    def check_silence(self, threshold_seconds: int = 300) -> bool:
        """Checks if the child has been silent for a prolonged period."""
        if (time.time() - self.context.last_interaction_time) > threshold_seconds:
            self.context.is_silent = True
            return True
        return False

# Global instance
state = StateManager()
