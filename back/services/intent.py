import re

class IntentService:
    def __init__(self):
        self.intents = {
            "scene_description": [
                r"what is in front of me",
                r"describe the scene",
                r"where am i",
                r"what do you see",
                r"what is around me",
                r"describe surroundings",
                r"وصف المشهد",
                r"ماذا يوجد أمامي",
                r"صف المشهد",
                r"ماذا ترى",
                r"ماذا حولي",
                r"شغل السين سامري",
                r"شغب السين سامري",
                r"السين سامري",
                r"سين سامري",
                r"ما هذا المشهد",
                r"وش قدامي"
            ],
            "object_search": [
                r"where is the (.+)",
                r"find the (.+)",
                r"look for (.+)",
                r"is there a (.+) in front of me",
                r"can you see a (.+)",
                r"أين (.+)",
                r"ابحث عن (.+)",
                r"وين (.+)",
                r"دور على (.+)",
                r"هل يوجد (.+) أمامي",
                r"هل ترى (.+)"
            ],
            "navigation_help": [
                r"how do i get to (.+)",
                r"guide me to (.+)",
                r"take me to (.+)",
                r"navigation help",
                r"كيف أصل إلى (.+)",
                r"خذني إلى (.+)",
                r"وجهني إلى (.+)",
                r"مساعدة في التنقل"
            ]
        }

    def detect_intent(self, text):
        text = text.lower().strip()
        if not text:
            return "none", None

        for intent, patterns in self.intents.items():
            for pattern in patterns:
                match = re.search(pattern, text)
                if match:
                    # Extract entity if any (e.g., the object name)
                    entity = match.group(1) if match.groups() else None
                    return intent, entity

        # Default fallback
        return "general_chat", None

intent_service = IntentService()
