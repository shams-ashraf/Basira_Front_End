from app.state_manager import SystemMode

INDOOR_CLASSES = ["chair", "table", "bed", "sofa", "door"]
OUTDOOR_CLASSES = ["car", "bus", "traffic light", "stop sign", "person", "dog"]
HAZARD_CLASSES = ["car", "bus", "stairs", "hole", "fire"]

def filter_yolo_detections(detections: list, current_mode: SystemMode) -> list:
    """
    Dynamically filters YOLO detections based on the system's current mode.
    Reduces cognitive load on the assistant and child by ignoring irrelevant objects.
    """
    filtered = []
    
    for det in detections:
        cls = det.get("class_name", "")
        conf = det.get("confidence", 0.0)
        
        # Always prioritize high confidence hazards
        if cls in HAZARD_CLASSES and conf > 0.7:
            filtered.append(det)
            continue
            
        if current_mode == SystemMode.INDOOR and cls in INDOOR_CLASSES:
            filtered.append(det)
        elif current_mode == SystemMode.OUTDOOR and cls in OUTDOOR_CLASSES:
            filtered.append(det)
        elif current_mode == SystemMode.PERSON_FOCUS and cls == "person":
            filtered.append(det)
        elif current_mode == SystemMode.GENERAL:
            # Maybe require higher confidence for general mode to reduce noise
            if conf > 0.6:
                filtered.append(det)
                
    return filtered
