import random
from app.state_manager import EmotionState

# Emotional Response Templates for the Explainability Layer
# Keeps the AI sounding warm, supportive, and child-friendly.

EMOTIONAL_TEMPLATES = {
    EmotionState.CALM: {
        "obstacle": [
            "Just a heads up, there's a {object} ahead.",
            "Careful, I see a {object} near you.",
        ],
        "unknown_person": [
            "There's someone nearby that I don't recognize. Do you want me to alert your parents?",
        ],
        "general_chat": [
            "I'm here! What would you like to do?",
            "Everything looks good around you.",
        ]
    },
    EmotionState.STRESSED: {
        "obstacle": [
            "Stop for a moment, there is a {object} in front of you. Take your time.",
            "Please wait, let's step back from the {object}.",
        ],
        "unknown_person": [
            "I don't know who is nearby, I am sending a message to your parents just in case. Hold my hand.",
        ],
        "general_chat": [
            "Take a deep breath, I am right here with you.",
            "Do you want me to call mom or dad?",
        ]
    },
    EmotionState.WITHDRAWN: {
        "obstacle": [
            "Careful of the {object}. I'm right here to guide you.",
        ],
        "general_chat": [
            "You've been quiet for a while. Is there anything I can help you with?",
            "If you want to play a game or read a story, just let me know.",
        ]
    },
    EmotionState.CURIOUS: {
        "obstacle": [
            "There's a {object} right there! Let's walk around it safely.",
        ],
        "general_chat": [
            "Let's explore! I see a lot of fun things.",
        ]
    }
}

def get_template(emotion: EmotionState, category: str, **kwargs) -> str:
    """Retrieves an emotionally appropriate response template."""
    templates = EMOTIONAL_TEMPLATES.get(emotion, EMOTIONAL_TEMPLATES[EmotionState.CALM])
    options = templates.get(category, EMOTIONAL_TEMPLATES[EmotionState.CALM].get(category, [""]))
    response = random.choice(options)
    return response.format(**kwargs)
