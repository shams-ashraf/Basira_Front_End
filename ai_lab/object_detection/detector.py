import os
import time
import uuid
from datetime import datetime
import traceback

import cv2
import numpy as np
from fastapi import APIRouter, File, Form, UploadFile

from ai_lab.face_recognition.recognizer import compare_against_child
from ai_lab.vision_service import vision_service

router = APIRouter()

TARGET_OBJECTS = {"chair", "bed", "hanger", "fork"}
TARGET_PERSON = {"person"}
MODEL_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "back", "yolov8n.pt"))

_object_model = None
_person_model = None


def _load_model(role: str):
    from ultralytics import YOLO

    global _object_model, _person_model
    if role == "object":
        if _object_model is None:
            _object_model = YOLO(MODEL_PATH)
        return _object_model
    if _person_model is None:
        _person_model = YOLO(MODEL_PATH)
    return _person_model


def _storage_dir(*parts: str) -> str:
    root = os.path.dirname(os.path.dirname(__file__))
    path = os.path.join(root, "storage", *parts)
    os.makedirs(path, exist_ok=True)
    return path


def _crop_box(image, box):
    x1, y1, x2, y2 = box
    h, w = image.shape[:2]
    x1 = max(0, min(w - 1, int(x1)))
    y1 = max(0, min(h - 1, int(y1)))
    x2 = max(1, min(w, int(x2)))
    y2 = max(1, min(h, int(y2)))
    return image[y1:y2, x1:x2]


def _draw_boxes(image, detections):
    for detection in detections:
        x1, y1, x2, y2 = detection["box"]
        label = detection["label"]
        color = (0, 255, 0) if label != "person" else (255, 0, 0)
        cv2.rectangle(image, (x1, y1), (x2, y2), color, 2)
        cv2.putText(
            image,
            f'{label} {detection["confidence"]:.2f}',
            (x1, max(20, y1 - 8)),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.6,
            color,
            2,
        )
    return image


def _run_model(model, image_path: str, allowed_labels: set[str]):
    results = model.predict(image_path, verbose=False)
    detections = []
    for result in results:
        for box in result.boxes:
            cls = int(box.cls[0])
            label = model.names[cls]
            if label not in allowed_labels:
                continue
            detections.append(
                {
                    "label": label,
                    "confidence": round(float(box.conf[0]), 2),
                    "box": list(map(int, box.xyxy[0].tolist())),
                }
            )
    return detections


@router.post("/run")
async def run_detection(file: UploadFile = File(...), child_id: str = Form("unknown")):
    started = time.perf_counter()
    temp_path = None
    try:
        contents = await file.read()
        npimg = np.frombuffer(contents, np.uint8)
        image = cv2.imdecode(npimg, cv2.IMREAD_COLOR)
        if image is None:
            return {"success": False, "error": "Invalid image", "timestamp": datetime.now().isoformat()}

        temp_dir = _storage_dir("results", f"child_{child_id}")
        temp_path = os.path.join(temp_dir, f"temp_{uuid.uuid4().hex}.jpg")
        cv2.imwrite(temp_path, image)

        object_model = _load_model("object")
        person_model = _load_model("person")

        object_start = time.perf_counter()
        object_detections = _run_model(object_model, temp_path, TARGET_OBJECTS)
        object_time = time.perf_counter() - object_start

        person_start = time.perf_counter()
        person_detections = _run_model(person_model, temp_path, TARGET_PERSON)
        person_time = time.perf_counter() - person_start

        detections = object_detections + person_detections
        processed = _draw_boxes(image.copy(), detections)

        processed_dir = _storage_dir("processed", f"child_{child_id}")
        filename = f"processed_{uuid.uuid4().hex}.jpg"
        processed_path = os.path.join(processed_dir, filename)
        cv2.imwrite(processed_path, processed)

        face_result = {"best_match": "Unknown", "best_score": 0.0, "similarity_scores": {}}
        face_time = 0.0
        if person_detections:
            face_start = time.perf_counter()
            face_crop = _crop_box(image, person_detections[0]["box"])
            if face_crop.size > 0:
                face_result = compare_against_child(face_crop, child_id)
            face_time = time.perf_counter() - face_start

        step_logs = [
            {
                "title": "YOLO Objects",
                "result": [f'{d["label"]} ({d["confidence"]:.2f}) {d["box"]}' for d in object_detections] or ["None"],
            },
            {
                "title": "YOLO Person",
                "result": [f'{d["label"]} ({d["confidence"]:.2f}) {d["box"]}' for d in person_detections] or ["None"],
            },
            {
                "title": "Bounding Boxes",
                "result": [f'{d["label"]}: {d["box"]}' for d in detections] or ["None"],
            },
        ]
        if person_detections:
            step_logs.append(
                {
                    "title": "Face Recognition",
                    "result": [f'{name} : {score:.4f}' for name, score in face_result["similarity_scores"].items()] or ["Unknown"],
                }
            )

        return {
            "success": True,
            "timestamp": datetime.now().isoformat(),
            "detected_objects": [d["label"] for d in object_detections],
            "person_detected": bool(person_detections),
            "detections": detections,
            "best_match": face_result["best_match"],
            "best_score": face_result["best_score"],
            "similarity_scores": face_result["similarity_scores"],
            "processed_image": processed_path,
            "processed_image_url": f"/storage/processed/child_{child_id}/{filename}",
            "step_logs": step_logs,
            "timings": {
                "YOLO Objects": f"{object_time:.2f}s",
                "YOLO Person": f"{person_time:.2f}s",
                "Face Recognition": f"{face_time:.2f}s",
                "Total Time": f"{(time.perf_counter() - started):.2f}s",
            },
        }
    except Exception as exc:
        return {
            "success": False,
            "error": str(exc),
            "traceback": traceback.format_exc(),
            "step_logs": [{"title": "Error", "result": [str(exc)]}],
            "timestamp": datetime.now().isoformat(),
        }
    finally:
        if temp_path and os.path.exists(temp_path):
            try:
                os.remove(temp_path)
            except Exception:
                pass
