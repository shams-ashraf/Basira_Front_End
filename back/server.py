import os
import json
import uuid
import shutil
import threading
import time
from datetime import datetime
from typing import List, Optional

import numpy as np
import cv2
import anyio  # For running sync in async
from fastapi import FastAPI, UploadFile, File, Form, WebSocket, WebSocketDisconnect, Request, Depends, HTTPException, status
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from database import Base, engine, SessionLocal
from models import (
    User, Child, DeviceLink, Person, UnknownPerson, 
    Alert, ActivityHistory, SystemLog, CaptionLog, Setting, Notification
)
from services.face import get_embedding, extract_face, cosine_similarity
from services.vision import vision_service
from services.voice import voice_service
from services.intent import intent_service
from services.security import (
    get_password_hash, verify_password,
    create_access_token, create_refresh_token, decode_token
)
from services.logger import log_system_event, log_activity
from services.logger import log_exception

# =========================
# ⚙️ CONFIG & INITIALIZATION
# =========================
THRESHOLD = 0.70
BASE_DIR = "database"
UNKNOWN_DIR = "unknown"

os.makedirs(BASE_DIR, exist_ok=True)
os.makedirs(UNKNOWN_DIR, exist_ok=True)

# Create all database tables
Base.metadata.create_all(bind=engine)

def _ensure_person_child_column():
    with engine.begin() as connection:
        columns = [row[1] for row in connection.exec_driver_sql("PRAGMA table_info(persons)").fetchall()]
        if "child_id" not in columns:
            connection.exec_driver_sql("ALTER TABLE persons ADD COLUMN child_id INTEGER")

_ensure_person_child_column()

app = FastAPI(
    title="Basira AI Assistant Backend",
    version="2.0.0",
    description="AI-powered assistive system backend for visually impaired children."
)

@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    log_system_event(
        "WARNING",
        "HTTP",
        request.url.path,
        f"HTTP {exc.status_code}: {exc.detail}",
        details=f"method={request.method} path={request.url.path}",
    )
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "detail": exc.detail,
            "status_code": exc.status_code,
            "path": request.url.path,
        },
    )


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    log_exception("Unhandled", request.url.path, exc)
    return JSONResponse(
        status_code=500,
        content={
            "detail": "Internal server error",
            "path": request.url.path,
        },
    )

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Serve audio files
AUDIO_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), 'audio'))
os.makedirs(AUDIO_DIR, exist_ok=True)
app.mount("/audio", StaticFiles(directory=AUDIO_DIR), name="audio")

# Serve reports files
REPORTS_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), 'reports'))
os.makedirs(REPORTS_DIR, exist_ok=True)
app.mount("/reports", StaticFiles(directory=REPORTS_DIR), name="reports")

# =========================
# 🔒 AUTHENTICATION DEPENDENCY
# =========================
security_scheme = HTTPBearer()

def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security_scheme)) -> User:
    token = credentials.credentials
    payload = decode_token(token)
    if not payload or payload.get("type") != "access":
        log_system_event("WARNING", "Auth", "TokenVerify", "Invalid or expired access token attempt")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired access token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    user_id = payload.get("sub")
    with SessionLocal() as db:
        user = db.query(User).filter(User.id == int(user_id)).first()
        if not user:
            log_system_event("WARNING", "Auth", "GetUser", f"User with ID {user_id} not found")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="User not found",
            )
        return user

# =========================
# 🔑 AUTHENTICATION ROUTES
# =========================
@app.post("/auth/signup")
async def signup(email: str = Form(...), password: str = Form(...), role: str = Form(...)):
    with SessionLocal() as db:
        existing = db.query(User).filter(User.email == email).first()
        if existing:
            log_system_event("WARNING", "Auth", "Signup", f"Signup failed: email {email} already registered")
            raise HTTPException(status_code=400, detail="Email already registered")
        
        user = User(
            email=email,
            password=get_password_hash(password),
            role=role,
            created_at=datetime.now().isoformat()
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        
        # Initialize default settings for user
        setting = Setting(
            user_id=user.id,
            server_ip="192.168.100.58",
            esp32_ip="192.168.1.100",
            websocket_url="ws://192.168.100.58:5000/voice/stream",
            detection_threshold=0.70,
            default_caption_model="vit",
            voice_speed=150.0,
            voice_language="ar",
            notification_settings="{}"
        )
        db.add(setting)
        db.commit()
        
        log_system_event("INFO", "Auth", "Signup", f"User {email} registered successfully as role: {role}")
        log_activity(child_id=0, action="Signup", details=f"User {email} signed up as {role}")
        return {"message": "User registered successfully", "user_id": user.id}


@app.post("/auth/login")
async def login(email: str = Form(...), password: str = Form(...)):
    with SessionLocal() as db:
        user = db.query(User).filter(User.email == email).first()
        if not user:
            log_system_event("WARNING", "Auth", "Login", f"Failed login attempt for email: {email}")
            raise HTTPException(status_code=400, detail="Incorrect email or password")
        if not verify_password(password, user.password):
            log_system_event("WARNING", "Auth", "Login", f"Failed login attempt for email: {email}")
            raise HTTPException(status_code=400, detail="Incorrect email or password")
        
        access_token = create_access_token(user.id)
        refresh_token = create_refresh_token(user.id)
        
        log_system_event("INFO", "Auth", "Login", f"User {email} logged in successfully")
        log_activity(child_id=0, action="Login", details=f"User {email} logged in")
        return {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer",
            "role": user.role,
            "user_id": user.id,
            "email": user.email
        }


@app.post("/auth/refresh")
async def refresh_token(refresh_token: str = Form(...)):
    payload = decode_token(refresh_token)
    if not payload or payload.get("type") != "refresh":
        log_system_event("WARNING", "Auth", "Refresh", "Invalid or expired refresh token attempt")
        raise HTTPException(status_code=401, detail="Invalid refresh token")
    
    user_id = payload.get("sub")
    access_token = create_access_token(user_id)
    return {
        "access_token": access_token,
        "token_type": "bearer"
    }


@app.get("/auth/me")
async def get_me(current_user: User = Depends(get_current_user)):
    return {
        "id": current_user.id,
        "email": current_user.email,
        "role": current_user.role,
        "created_at": current_user.created_at
    }

@app.post("/auth/logout")
async def logout(current_user: User = Depends(get_current_user)):
    log_system_event("INFO", "Auth", "Logout", f"User {current_user.email} logged out")
    log_activity(child_id=0, action="Logout", details=f"User {current_user.email} logged out")
    return {"message": "Logged out successfully"}

# =========================
# 📱 PARENT-CHILD MANAGEMENT
# =========================
@app.post("/parent/children")
async def create_child(name: str = Form(...), current_user: User = Depends(get_current_user)):
    if current_user.role != "parent":
        raise HTTPException(status_code=403, detail="Only parents can register children")
    
    device_code = f"BASIRA-{uuid.uuid4().hex[:6].upper()}"
    with SessionLocal() as db:
        child = Child(
            name=name,
            device_code=device_code,
            created_at=datetime.now().isoformat()
        )
        child.parent_id = current_user.id
        db.add(child)
        db.commit()
        db.refresh(child)
        
        # Link child automatically
        link = DeviceLink(
            parent_id=current_user.id,
            child_id=child.id,
            linked_at=datetime.now().isoformat()
        )
        db.add(link)
        db.commit()
        
        log_system_event("INFO", "Parent", "CreateChild", f"Child {name} created with device code: {device_code}")
        log_activity(child_id=child.id, action="QR Linked", details=f"Child profile linked to parent {current_user.email}")
        return {
            "child_id": child.id,
            "name": child.name,
            "device_code": device_code
        }

@app.get("/parent/children")
async def get_children(current_user: User = Depends(get_current_user)):
    if current_user.role != "parent":
        raise HTTPException(status_code=403, detail="Only parents can view children")
    with SessionLocal() as db:
        children = db.query(Child).filter(Child.parent_id == current_user.id).all()
        return [
            {
                "id": c.id,
                "name": c.name,
                "device_code": c.device_code,
                "created_at": c.created_at
            }
            for c in children
        ]

@app.post("/pair/confirm")
async def pair_confirm(device_code: str = Form(...), current_user: User = Depends(get_current_user)):
    if current_user.role != "parent":
        raise HTTPException(status_code=403, detail="Only parents can pair devices")
    with SessionLocal() as db:
        child = db.query(Child).filter(Child.device_code == device_code).first()
        if not child:
            log_system_event("WARNING", "Pairing", "Scan", f"Pairing failed: device code {device_code} not found")
            raise HTTPException(status_code=404, detail="Child profile/device code not found")

        existing_link = db.query(DeviceLink).filter(
            DeviceLink.parent_id == current_user.id,
            DeviceLink.child_id == child.id
        ).first()
        
        if not existing_link:
            link = DeviceLink(
                parent_id=current_user.id,
                child_id=child.id,
                linked_at=datetime.now().isoformat()
            )
            db.add(link)
            db.commit()
        
        log_system_event("INFO", "Parent Linked", "Pairing", f"Parent {current_user.email} successfully paired with Child {child.name}")
        log_activity(child_id=child.id, action="QR Linked", details=f"Linked to parent {current_user.email}")
        return {"status": "linked", "child_id": child.id, "child_name": child.name}

@app.get("/pair/status")
async def pair_status(device_code: str):
    with SessionLocal() as db:
        child = db.query(Child).filter(Child.device_code == device_code).first()
        if not child:
            return {"linked": False, "error": "Invalid device code"}
        
        link = db.query(DeviceLink).filter(DeviceLink.child_id == child.id).first()
        return {
            "linked": link is not None,
            "child_id": child.id,
            "child_name": child.name
        }

# =========================
# 👥 GET PERSONS (KNOWN)
# =========================
@app.get("/persons")
def get_persons(request: Request, child_id: int | None = None, current_user: User = Depends(get_current_user)):
    base_url = str(request.base_url).rstrip('/')
    with SessionLocal() as db:
        parent_id = current_user.id
        query = db.query(Person).filter(Person.user_id == parent_id)
        if child_id is not None:
            query = query.filter(Person.child_id == child_id)
        persons = query.order_by(Person.id.desc()).all()
    result = []
    for p in persons:
        child_folder = str(p.child_id or "shared")
        folder = f"{BASE_DIR}/user_{parent_id}/{child_folder}/{p.name}"
        image_url = None
        if os.path.exists(folder):
            files = os.listdir(folder)
            if files:
                image_url = f"{base_url}/image/{parent_id}/{child_folder}/{p.name}/{files[0]}"
        result.append({
            "id": p.id,
            "name": p.name,
            "image": image_url,
            "child_id": p.child_id,
        })
    return result

# =========================
# ✅ FAST VALIDATION
# =========================
@app.post("/validate_face")
async def validate_face(file: UploadFile = File(...)):
    contents = await file.read()
    npimg = np.frombuffer(contents, np.uint8)
    img = cv2.imdecode(npimg, cv2.IMREAD_COLOR)
    
    if img is None:
        return {"valid": False, "error": "Invalid image"}

    from services.face import fast_detect_face
    has_face = await anyio.to_thread.run_sync(fast_detect_face, img)
    return {"valid": has_face}

# =========================
# ➕ REGISTER (FACE REGISTRATION WITH VALIDATION)
# =========================
@app.post("/register")
async def register(
    name: str = Form(...),
    child_id: int = Form(default=0),
    files: List[UploadFile] = File(...),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != "parent":
        raise HTTPException(status_code=403, detail="Only parents can register faces")
    
    log_system_event("INFO", "Face Registration", "Add Person Started", f"Registering face '{name}' with {len(files)} files")
    
    parent_id = current_user.id
    folder = f"{BASE_DIR}/user_{parent_id}/{child_id or 'shared'}/{name}"
    os.makedirs(folder, exist_ok=True)

    embeddings = []
    saved_paths = []
    
    # Process files synchronously to validate faces immediately
    for file in files:
        contents = await file.read()
        filename = f"{uuid.uuid4()}.jpg"
        path = os.path.join(folder, filename)
        
        with open(path, "wb") as f:
            f.write(contents)
        
        # 1. Try to extract and crop face first
        cropped = extract_face(path)
        if cropped is not None:
            # Overwrite original file with cropped face to improve quality
            cv2.imwrite(path, cropped)
            emb = get_embedding(cropped)
        else:
            # Fallback: direct embedding
            img = cv2.imread(path)
            emb = get_embedding(img) if img is not None else None
            
        if emb is not None:
            embeddings.append(emb)
            saved_paths.append(path)
        else:
            # Remove bad files
            if os.path.exists(path):
                os.remove(path)
                
    if not embeddings:
        # Clean folder
        if os.path.exists(folder):
            shutil.rmtree(folder)
        log_system_event("ERROR", "Face Registration", "Face Extraction Failed", f"No faces detected or embedding generation failed for {name}")
        raise HTTPException(
            status_code=400, 
            detail="Embedding generation failed. No valid faces detected in the provided images."
        )

    # Compute average embedding
    avg = np.mean(embeddings, axis=0).tolist()
    
    with SessionLocal() as db:
        existing = db.query(Person).filter(
            Person.user_id == parent_id,
            Person.name == name
        ).first()

        if existing:
            existing.embedding_vector = json.dumps(avg)
            existing.embedding_model = "Facenet"
            existing.embedding_version = "1.0"
            existing.timestamp = datetime.now().isoformat()
            db.commit()
            db.refresh(existing)
            person_id = existing.id
        else:
            person = Person(
                user_id=parent_id,
                child_id=child_id if child_id > 0 else None,
                name=name,
                embedding_vector=json.dumps(avg),
                embedding_model="Facenet",
                embedding_version="1.0",
                timestamp=datetime.now().isoformat(),
                storage_path=folder
            )
            db.add(person)
            db.commit()
            db.refresh(person)
            person_id = person.id
            
        log_activity(child_id=0, action="Person Added", details=f"Registered known person: {name}")
        log_system_event(
            "INFO", "Face Registration", "Embedding Generated", 
            f"Successfully generated embedding for {name}. Image Count: {len(saved_paths)}. Storage Path: {folder}"
        )
        
        return {
            "message": f"Successfully registered {name}!",
            "person_id": person_id,
            "images_processed": len(saved_paths)
        }

# =========================
# 📸 PERSON IMAGES
# =========================
@app.get("/person_images")
def person_images(name: str, child_id: int | None = None, current_user: User = Depends(get_current_user), request: Request = None):
    base_url = str(request.base_url).rstrip('/')
    parent_id = current_user.id
    child_folder = str(child_id or 'shared')
    folder = f"{BASE_DIR}/user_{parent_id}/{child_folder}/{name}"

    if not os.path.exists(folder):
        return []

    # Sort files (newest first)
    files = sorted(os.listdir(folder), reverse=True)
    return [
        f"{base_url}/image/{parent_id}/{child_folder}/{name}/{f}"
        for f in files
    ]

# =========================
# 🧠 RECOGNIZE (FACE RECOGNITION PIPELINE)
# =========================
@app.post("/recognize")
async def recognize(file: UploadFile = File(...), child_id: int = Form(default=0)):
    log_system_event("INFO", "Face Recognition", "Face Recognition Started", "Starting face recognition on received frame")
    contents = await file.read()
    npimg = np.frombuffer(contents, np.uint8)
    img = cv2.imdecode(npimg, cv2.IMREAD_COLOR)

    if img is None:
        return {"name": "No face", "score": 0}

    emb = get_embedding(img)
    if emb is None:
        return {"name": "No face", "score": 0}

    with SessionLocal() as db:
        # Match against all registered persons
        persons = db.query(Person).all()
        best_score = -1.0
        best_person = None

        for p in persons:
            if not p.embedding_vector:
                continue
            db_emb = np.array(json.loads(p.embedding_vector))
            score = cosine_similarity(emb, db_emb)
            if score > best_score:
                best_score = score
                best_person = p

        # Check if match meets the similarity threshold
        if best_person and best_score >= THRESHOLD:
            best_name = best_person.name
            
            # Log successful recognition
            log_activity(child_id=child_id, action="Face Recognized", details=f"Recognized {best_name} (Similarity: {best_score:.2f})")
            log_system_event(
                "INFO", "Face Recognition", "Person Recognized", 
                f"[FACE] Model: Facenet, Embedding Length: 128, Match: {best_name}, Similarity: {best_score:.2f}"
            )
            
            return {
                "name": best_name,
                "score": float(best_score),
                "recognized": True
            }
        else:
            # No match found -> Unknown Person Flow
            best_name = "Unknown"
            filename = f"{child_id}_{uuid.uuid4()}.jpg"
            face_path = os.path.join(UNKNOWN_DIR, filename)
            
            with open(face_path, "wb") as f:
                f.write(contents)
                
            # Store in DB
            unknown = UnknownPerson(
                child_id=child_id,
                face_image_path=face_path,
                detected_at=datetime.now().isoformat(),
                is_converted=False
            )
            db.add(unknown)
            db.commit()
            db.refresh(unknown)
            
            # Create system alert
            alert = Alert(
                child_id=child_id,
                type="Unknown Person",
                message="An unknown person was detected in front of the child.",
                timestamp=datetime.now().isoformat(),
                is_resolved=False
            )
            db.add(alert)
            
            # Mock Firebase Cloud Messaging notification
            notification = Notification(
                user_id=1,  # Default parent ID placeholder
                type="Unknown Person",
                title="Unknown Person Detected",
                body="A new unknown person has been detected near your child.",
                sent_at=datetime.now().isoformat(),
                status="sent"
            )
            db.add(notification)
            db.commit()
            
            log_activity(child_id=child_id, action="Unknown Person Detected", details="Unknown face captured and logged")
            log_system_event("WARNING", "Face Recognition", "Unknown Person", f"[WARNING] Unknown Person Detected. Image saved to: {face_path}. Notification Sent.")
            
            return {
                "name": "Unknown",
                "score": float(best_score) if best_score > 0 else 0.0,
                "recognized": False,
                "unknown_id": unknown.id
            }

# =========================
# ❓ UNKNOWN LIST & ENDPOINTS
# =========================
@app.get("/unknown")
def get_unknown(
    request: Request,
    child_id: int | None = None,
    current_user: User = Depends(get_current_user)
):
    base_url = str(request.base_url).rstrip('/')
    with SessionLocal() as db:
        if current_user.role == "parent":
            # If parent, get all unknown persons linked to parent's children
            children = db.query(Child).filter(Child.parent_id == current_user.id).all()
            child_map = {c.id: c.name for c in children}
            child_ids = list(child_map.keys())
            if child_id is not None:
                if child_id not in child_ids:
                    raise HTTPException(status_code=403, detail="Child not linked to current parent")
                child_ids = [child_id]
        else:
            # If child, get only this child's unknowns
            child_map = {current_user.id: "Me"}
            child_ids = [child_id if child_id is not None else current_user.id]
        
        unknowns = db.query(UnknownPerson).filter(
            UnknownPerson.child_id.in_(child_ids),
            UnknownPerson.is_converted == False
        ).all()
        
        return [
            {
                "id": str(u.id),
                "url": f"{base_url}/unknown_image/{u.child_id}/{os.path.basename(u.face_image_path)}",
                "detected_at": u.detected_at,
                "child_id": u.child_id,
                "child_name": child_map.get(u.child_id, f"Child {u.child_id}")
            }
            for u in unknowns
        ]

@app.post("/parent/link_child")
async def link_child_backend(
    child_id: int = Form(...),
    child_name: str = Form(...),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != "parent":
        raise HTTPException(status_code=403, detail="Only parents can link children")
    
    with SessionLocal() as db:
        # Create or update child entry mapping child's User.id to parent
        child = db.query(Child).filter(Child.id == child_id).first()
        if not child:
            child = Child(
                id=child_id,
                name=child_name,
                parent_id=current_user.id,
                device_code=f"LINKED-{uuid.uuid4().hex[:6].upper()}",
                created_at=datetime.now().isoformat()
            )
            db.add(child)
        else:
            child.parent_id = current_user.id
            child.name = child_name
            
        # Create DeviceLink record
        existing_link = db.query(DeviceLink).filter(
            DeviceLink.parent_id == current_user.id,
            DeviceLink.child_id == child_id
        ).first()
        
        if not existing_link:
            link = DeviceLink(
                parent_id=current_user.id,
                child_id=child_id,
                linked_at=datetime.now().isoformat()
            )
            db.add(link)
            
        db.commit()
        
    log_activity(child_id=child_id, action="QR Linked", details=f"Linked to parent {current_user.email}")
    log_system_event("INFO", "Parent Linked", "Pairing", f"Parent {current_user.email} paired with Child {child_name}")
    return {"status": "linked", "child_id": child_id, "child_name": child_name}


@app.get("/unknown_image/{child_id}/{filename}")
def unknown_image(child_id: int, filename: str):
    path = os.path.join(UNKNOWN_DIR, f"child_{child_id}", filename)
    if os.path.exists(path):
        return FileResponse(path)
    return {"error": "not found"}

@app.post("/upload_unknown")
async def upload_unknown(
    file: UploadFile = File(...),
    child_id: int = Form(default=0)
):
    child_folder = os.path.join(UNKNOWN_DIR, f"child_{child_id}")
    os.makedirs(child_folder, exist_ok=True)
    contents = await file.read()
    filename = f"{child_id}_{uuid.uuid4()}.jpg"
    path = os.path.join(child_folder, filename)
    # Resize the image if it's too large to save memory and storage
    npimg = np.frombuffer(contents, np.uint8)
    img = cv2.imdecode(npimg, cv2.IMREAD_COLOR)
    if img is not None:
        h, w = img.shape[:2]
        max_dim = 1024
        if max(h, w) > max_dim:
            scale = max_dim / max(h, w)
            new_w = int(w * scale)
            new_h = int(h * scale)
            img = cv2.resize(img, (new_w, new_h), interpolation=cv2.INTER_AREA)
        cv2.imwrite(path, img)
    else:
        with open(path, "wb") as f:
            f.write(contents)
        
    with SessionLocal() as db:
        unknown = UnknownPerson(
            child_id=child_id,
            face_image_path=path,
            detected_at=datetime.now().isoformat(),
            is_converted=False
        )
        db.add(unknown)
        
        alert = Alert(
            child_id=child_id,
            type="Unknown Person",
            message="An unknown person was captured on camera.",
            timestamp=datetime.now().isoformat(),
            is_resolved=False
        )
        db.add(alert)
        db.commit()
        db.refresh(unknown)
        unknown_id = unknown.id
        
    log_activity(child_id=child_id, action="Unknown Person Detected", details=f"Child uploaded unknown face frame: {filename}")
    log_system_event("WARNING", "Face Recognition", "Unknown Saved", f"[WARNING] Unknown saved from child={child_id} → {filename}")
    return {"status": "saved", "filename": filename, "unknown_id": unknown_id}

# =========================
# 🔁 UNKNOWN → PERSON (CONVERT)
# =========================
@app.post("/unknown_to_person")
async def unknown_to_person(
    name: str = Form(...),
    unknown_id: int = Form(...),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != "parent":
        raise HTTPException(status_code=403, detail="Only parents can register faces")
        
    parent_id = current_user.id
    with SessionLocal() as db:
        unknown = db.query(UnknownPerson).filter(UnknownPerson.id == unknown_id).first()
        if not unknown or not os.path.exists(unknown.face_image_path):
            return {"error": "Unknown face image not found"}
            
        src = unknown.face_image_path
        folder = f"{BASE_DIR}/user_{parent_id}/{name}"
        os.makedirs(folder, exist_ok=True)
        dst = os.path.join(folder, f"{uuid.uuid4()}.jpg")
        
        # Crop face before moving
        cropped = extract_face(src)
        if cropped is not None:
            cv2.imwrite(dst, cropped)
            emb = get_embedding(cropped)
        else:
            # Fallback
            shutil.copy(src, dst)
            emb = get_embedding(src)
            
        if emb is None:
            # Clean dst
            if os.path.exists(dst):
                os.remove(dst)
            log_system_event("ERROR", "Face Registration", "Face Extraction Failed", f"Converting unknown to face failed: No face detected in {src}")
            return {"error": "Face validation failed during conversion."}
            
        # Delete original from unknown directory
        if os.path.exists(src):
            os.remove(src)
            
        person = Person(
            user_id=parent_id,
            child_id=unknown.child_id,
            name=name,
            embedding_vector=json.dumps(emb.tolist()),
            embedding_model="Facenet",
            embedding_version="1.0",
            timestamp=datetime.now().isoformat(),
            storage_path=folder
        )
        db.add(person)
        
        # Get child_id before deleting
        child_id = unknown.child_id
        
        # Delete the unknown record from database
        db.delete(unknown)
        db.commit()
        
        log_activity(child_id=child_id, action="Unknown Person Converted", details=f"Mapped unknown face ID {unknown_id} to name: {name}")
        log_system_event("INFO", "Face Registration", "Unknown Converted", f"Converted unknown face {unknown_id} to known person '{name}' successfully.")
        return {"message": "converted successfully", "person_id": person.id}

# =========================
# ❌ DELETE & EDIT PERSONS
# =========================
@app.delete("/person/{id}")
def delete_person(id: int, current_user: User = Depends(get_current_user)):
    with SessionLocal() as db:
        p = db.query(Person).filter(Person.id == id, Person.user_id == current_user.id).first()
        if not p:
            return {"message": "Person not found"}

        if p.storage_path and os.path.exists(p.storage_path):
            shutil.rmtree(p.storage_path)

        name = p.name
        db.delete(p)
        db.commit()
        log_activity(child_id=0, action="Person Deleted", details=f"Deleted person: {name}")
        log_system_event("INFO", "Parent", "DeletePerson", f"Deleted person '{name}' successfully")
        return {"message": "deleted"}

@app.put("/person/{id}")
async def edit_person(id: int, name: str = Form(...), current_user: User = Depends(get_current_user)):
    with SessionLocal() as db:
        p = db.query(Person).filter(Person.id == id, Person.user_id == current_user.id).first()
        if not p:
            return {"error": "Person not found"}

        old_name = p.name
        old_folder = f"{BASE_DIR}/user_{p.user_id}/{old_name}"
        new_folder = f"{BASE_DIR}/user_{p.user_id}/{name}"

        if os.path.exists(old_folder):
            os.rename(old_folder, new_folder)
            p.storage_path = new_folder

        p.name = name
        db.commit()
        log_activity(child_id=0, action="Person Edited", details=f"Renamed person from {old_name} to {name}")
        log_system_event("INFO", "Parent", "EditPerson", f"Renamed person {id} from '{old_name}' to '{name}'")
        return {"message": "updated"}

@app.get("/image/{user_id}/{child_id}/{name}/{filename}")
def get_image(user_id: int, child_id: str, name: str, filename: str):
    path = os.path.join(BASE_DIR, f"user_{user_id}", child_id, name, filename)
    if os.path.exists(path):
        return FileResponse(path)
    return {"error": "image not found"}

# =========================
# 📸 VISION PIPELINE (YOLO / CAPTIONS)
# =========================
@app.get("/health")
def health_check():
    return {
        "status": "ok",
        "timestamp": datetime.now().isoformat()
    }

@app.post("/vision/detect")
async def detect_objects(file: UploadFile = File(...), child_id: int = Form(default=0)):
    log_system_event("INFO", "YOLO", "YOLO Started", "Running object detection on frame")
    start_time = time.perf_counter()
    contents = await file.read()
    temp_path = f"temp_{uuid.uuid4()}.jpg"
    with open(temp_path, "wb") as f:
        f.write(contents)
    
    try:
        detections = await anyio.to_thread.run_sync(vision_service.detect_objects, temp_path)
        processing_time = round((time.perf_counter() - start_time) * 1000, 2)
        
        labels = [d["label"] for d in detections]
        log_activity(child_id=child_id, action="Object Detected", details=f"Detected objects: {', '.join(labels) if labels else 'None'}")
        log_system_event("INFO", "YOLO", "Objects Detected", f"[INFO] Frame Captured. YOLO Completed in {processing_time}ms. Detected: {', '.join(labels)}")
        
        return {
            "success": True,
            "detections": detections,
            "timestamp": datetime.now().isoformat(),
            "processing_time_ms": processing_time,
            "error": None
        }
    except Exception as e:
        log_system_event("ERROR", "YOLO", "DetectionFailed", f"YOLO processing error: {e}")
        return {
            "success": False,
            "detections": [],
            "timestamp": datetime.now().isoformat(),
            "error": str(e)
        }
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)

@app.post("/vision/caption")
async def generate_caption(
    file: UploadFile = File(...),
    model_type: str = Form("vit"),
    child_id: int = Form(default=0)
):
    log_system_event("INFO", "Caption", "Caption Generated", f"Generating scene caption using model: {model_type}")
    start_time = time.perf_counter()
    contents = await file.read()
    temp_path = f"temp_{uuid.uuid4()}.jpg"
    with open(temp_path, "wb") as f:
        f.write(contents)
    
    try:
        caption = await anyio.to_thread.run_sync(vision_service.generate_caption, temp_path, model_type)
        processing_time_ms = round((time.perf_counter() - start_time) * 1000, 2)
        
        # Print caption dynamically to terminal
        print(f"\n[{model_type.upper()}]\n{caption}\n")
        
        # Save caption to DB
        with SessionLocal() as db:
            log_cap = CaptionLog(
                child_id=child_id,
                model_name=model_type,
                caption=caption,
                confidence=1.0,
                execution_time=processing_time_ms / 1000.0,
                timestamp=datetime.now().isoformat()
            )
            db.add(log_cap)
            db.commit()
            
        log_activity(child_id=child_id, action="Caption Generated", details=f"Model: {model_type}, Caption: {caption}")
        log_system_event("INFO", "Caption", "Caption Saved", f"[INFO] Caption generated by {model_type} in {processing_time_ms}ms")
        
        return {
            "success": True,
            "caption": caption,
            "summary": caption,
            "timestamp": datetime.now().isoformat(),
            "processing_time_ms": processing_time_ms,
            "error": None
        }
    except Exception as e:
        log_system_event("ERROR", "Caption", "CaptionFailed", f"Captioning error: {e}")
        return {
            "success": False,
            "caption": "",
            "summary": "",
            "timestamp": datetime.now().isoformat(),
            "error": str(e)
        }
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)

# =========================
# 🎤 VOICE STREAM (VOSK WEBSOCKET)
# =========================
@app.websocket("/voice/stream")
async def voice_stream(websocket: WebSocket):
    await websocket.accept()
    log_system_event("INFO", "WebSocket", "Child Connected", "[INFO] Child connected to Voice WebSocket Stream")

    try:
        while True:
            message = await websocket.receive()
            text = ""
            is_final = True

            if message.get("text") is not None:
                text = str(message["text"]).strip()
            elif message.get("bytes") is not None:
                recognizer = voice_service.get_stt_recognizer()
                if not recognizer:
                    await websocket.send_json({
                        "error": "Voice model is not available on the server. The app will use device speech recognition instead."
                    })
                    continue

                audio_chunk = message["bytes"]
                text, is_final = voice_service.process_audio_chunk(recognizer, audio_chunk)
            else:
                continue
            
            if text and is_final:
                log_system_event("INFO", "Voice", "Speech Recognized", f"Speech Input Recognized: '{text}'")
                intent, entity = intent_service.detect_intent(text)
                log_system_event("INFO", "Voice", "Intent Classified", f"Intent: '{intent}', Entity: '{entity}'")
                
                response_text = ""
                action = None
                is_arabic = any("\u0600" <= c <= "\u06FF" for c in text)
                
                # Intent processing mapping
                if intent == "scene_description":
                    response_text = "سأقوم بفحص المشهد أمامك." if is_arabic else "I'm looking at the scene for you."
                    action = "capture_scene"
                elif intent == "object_search":
                    response_text = f"سأبحث عن {entity} من أجلك." if is_arabic else f"I will help you find the {entity}."
                    action = f"find_{entity}"
                elif intent == "navigation_help":
                    response_text = "سأرشدك إلى الاتجاه الصحيح." if is_arabic else "I will guide you to safety."
                    action = "navigate"
                else:
                    response_text = "أنا صديقتك بصيرة، كيف يمكنني مساعدتك؟" if is_arabic else "I'm your friend Basira, how can I help?"
                    action = "help"
                
                # Text-to-Speech response generation
                audio_filename, _ = await anyio.to_thread.run_sync(voice_service.text_to_speech, response_text)
                
                # Dynamically construct server base URL from websocket request
                host = websocket.headers.get("host", "192.168.100.58:5000")
                audio_url = f"http://{host}/audio/{audio_filename}"
                
                await websocket.send_json({
                    "text": response_text,
                    "intent": intent,
                    "action": action,
                    "audio_url": audio_url
                })
                
                log_activity(child_id=0, action="SOS Activated" if intent == "emergency" else "Voice Intent", details=f"Intent: {intent}, Response: {response_text}")
                log_system_event("INFO", "Voice", "TTS Sent", f"Sent TTS audio response: {audio_url}")
                
    except WebSocketDisconnect:
        log_system_event("INFO", "WebSocket", "Child Disconnected", "[INFO] Child disconnected from Voice Stream")
    except Exception as e:
        log_system_event("ERROR", "WebSocket", "Error", f"Voice Stream Error: {e}")

# =========================
# 🔔 ALERTS
# =========================
@app.get("/alerts")
def get_alerts(
    child_id: int | None = None,
    current_user: User = Depends(get_current_user)
):
    with SessionLocal() as db:
        if current_user.role == "parent":
            children = db.query(Child).filter(Child.parent_id == current_user.id).all()
            child_ids = [c.id for c in children]
            if child_id is not None:
                if child_id not in child_ids:
                    raise HTTPException(status_code=403, detail="Child not linked to current parent")
                child_ids = [child_id]
            alerts = db.query(Alert).filter(Alert.child_id.in_(child_ids)).order_by(Alert.id.desc()).all()
        else:
            target_child_id = child_id if child_id is not None else current_user.id
            alerts = db.query(Alert).filter(Alert.child_id == target_child_id).order_by(Alert.id.desc()).all()
            
        return [
            {
                "id": a.id,
                "child_id": a.child_id,
                "type": a.type,
                "message": a.message,
                "timestamp": a.timestamp,
                "is_resolved": a.is_resolved
            }
            for a in alerts
        ]

@app.post("/alerts")
def create_alert(type: str = Form(...), message: str = Form(...), child_id: int = Form(...)):
    with SessionLocal() as db:
        alert = Alert(
            child_id=child_id,
            type=type,
            message=message,
            timestamp=datetime.now().isoformat(),
            is_resolved=False
        )
        db.add(alert)
        db.commit()
        db.refresh(alert)
        
        log_activity(child_id=child_id, action="SOS Activated" if type == "SOS" else "Alert Fired", details=message)
        log_system_event("WARNING", "Alert", "CreateAlert", f"[INFO] Notification Sent: Alert '{type}' - {message}")
        return {"id": alert.id, "status": "created"}

# =========================
# 📝 REPORT EXPORT ROUTE
# =========================
# =========================
# 📝 REPORT EXPORT ROUTE
# =========================
@app.get("/reports/{child_id}/{report_type}")
def download_report(child_id: int, report_type: str, current_user: User = Depends(get_current_user)):
    """Generate and return a PDF report for the given child."""
    if current_user.role != "parent":
        raise HTTPException(status_code=403, detail="Only parents can access reports")

    with SessionLocal() as db:
        if report_type == "activity":
            filepath = generate_activity_report(db, child_id)
        elif report_type == "detection":
            filepath = generate_detection_report(db, child_id)
        elif report_type == "unknown":
            filepath = generate_unknown_report(db, child_id)
        elif report_type == "alerts":
            filepath = generate_alerts_report(db, child_id)
        elif report_type == "full":
            filepath = generate_full_child_report(db, child_id)
        else:
            raise HTTPException(status_code=400, detail="Invalid report type requested")

        if os.path.exists(filepath):
            return FileResponse(filepath, filename=os.path.basename(filepath), media_type="application/pdf")
        raise HTTPException(status_code=404, detail="Failed to generate report PDF file")
# Helper report generation stubs
def _ensure_reports_dir() -> str:
    reports_dir = os.path.join(BASE_DIR, "reports")
    os.makedirs(reports_dir, exist_ok=True)
    return reports_dir

def _create_dummy_pdf(report_name: str, child_id: int) -> str:
    reports_dir = _ensure_reports_dir()
    filename = f"{report_name}_child_{child_id}_{uuid.uuid4().hex[:6]}.pdf"
    path = os.path.join(reports_dir, filename)
    # Write a minimal PDF header (placeholder)
    with open(path, "wb") as f:
        f.write(b"%PDF-1.4\n% Dummy report generated\n")
    return path

def generate_activity_report(db, child_id: int) -> str:
    return _create_dummy_pdf("activity", child_id)

def generate_detection_report(db, child_id: int) -> str:
    return _create_dummy_pdf("detection", child_id)

def generate_unknown_report(db, child_id: int) -> str:
    return _create_dummy_pdf("unknown", child_id)

def generate_alerts_report(db, child_id: int) -> str:
    return _create_dummy_pdf("alerts", child_id)

def generate_full_child_report(db, child_id: int) -> str:
    return _create_dummy_pdf("full", child_id)

# =========================
# ⚙️ SETTINGS SYSTEM
# =========================
@app.get("/settings")
def get_settings(current_user: User = Depends(get_current_user)):
    with SessionLocal() as db:
        setting = db.query(Setting).filter(Setting.user_id == current_user.id).first()
        if not setting:
            setting = Setting(
                user_id=current_user.id,
                server_ip="192.168.100.58",
                esp32_ip="192.168.1.100",
                websocket_url="ws://192.168.100.58:5000/voice/stream",
                detection_threshold=0.70,
                default_caption_model="vit",
                voice_speed=150.0,
                voice_language="ar",
                notification_settings="{}"
            )
            db.add(setting)
            db.commit()
            db.refresh(setting)
        return {
            "server_ip": setting.server_ip,
            "esp32_ip": setting.esp32_ip,
            "websocket_url": setting.websocket_url,
            "detection_threshold": setting.detection_threshold,
            "default_caption_model": setting.default_caption_model,
            "voice_speed": setting.voice_speed,
            "voice_language": setting.voice_language,
            "notification_settings": setting.notification_settings
        }

@app.post("/settings")
def update_settings(
    server_ip: str = Form(...),
    esp32_ip: str = Form(...),
    websocket_url: str = Form(...),
    detection_threshold: float = Form(...),
    default_caption_model: str = Form(...),
    voice_speed: float = Form(...),
    voice_language: str = Form(...),
    notification_settings: str = Form(...),
    current_user: User = Depends(get_current_user)
):
    with SessionLocal() as db:
        setting = db.query(Setting).filter(Setting.user_id == current_user.id).first()
        if not setting:
            setting = Setting(user_id=current_user.id)
            db.add(setting)
            
        setting.server_ip = server_ip
        setting.esp32_ip = esp32_ip
        setting.websocket_url = websocket_url
        setting.detection_threshold = detection_threshold
        setting.default_caption_model = default_caption_model
        setting.voice_speed = voice_speed
        setting.voice_language = voice_language
        setting.notification_settings = notification_settings
        
        db.commit()
        log_activity(child_id=0, action="Settings Updated", details="User settings modified and saved")
        log_system_event("INFO", "Settings", "SettingsUpdated", f"[INFO] Notification Sent: Settings updated for user {current_user.email}")
        return {"status": "success"}

# =========================
# 📊 MONITORING & LOGS
# =========================
@app.get("/system_logs")
def get_logs(current_user: User = Depends(get_current_user)):
    if current_user.role != "parent":
        raise HTTPException(status_code=403, detail="Only parents can view system logs")
    with SessionLocal() as db:
        logs = db.query(SystemLog).order_by(SystemLog.id.desc()).limit(100).all()
        return [
            {
                "id": l.id,
                "timestamp": l.timestamp,
                "level": l.level,
                "module": l.module,
                "action": l.action,
                "message": l.message,
                "details": l.details
            }
            for l in logs
        ]

# =========================
# 🚀 MAIN RUNNER
# =========================
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("server:app", host="0.0.0.0", port=5000, reload=True)
