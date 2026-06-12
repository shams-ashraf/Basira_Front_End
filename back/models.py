from sqlalchemy import Column, Integer, String, Float, Boolean, ForeignKey, Text
from sqlalchemy.orm import relationship
from database import Base

# 1. Users table (Parent or Child accounts)
class User(Base):
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True)
    password = Column(String)  # Hashed
    role = Column(String)  # "parent" or "child"
    created_at = Column(String)

# 2. Children table (Child profile linked to parents)
class Child(Base):
    __tablename__ = "children"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String)
    parent_id = Column(Integer, ForeignKey("users.id"))
    device_code = Column(String, unique=True, index=True)
    created_at = Column(String)

# 3. Device Links table (QR Code pairings)
class DeviceLink(Base):
    __tablename__ = "device_links"
    
    id = Column(Integer, primary_key=True, index=True)
    parent_id = Column(Integer, ForeignKey("users.id"))
    child_id = Column(Integer, ForeignKey("children.id"))
    linked_at = Column(String)

# 4. Persons table (Registered/known faces)
class Person(Base):
    __tablename__ = "persons"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))  # Parent owner
    child_id = Column(Integer, ForeignKey("children.id"), nullable=True)
    name = Column(String)
    embedding_vector = Column(Text)  # JSON representation of float list
    embedding_model = Column(String)
    embedding_version = Column(String)
    timestamp = Column(String)
    storage_path = Column(String)

# 5. Unknown Persons table (Faces detected but not matched)
class UnknownPerson(Base):
    __tablename__ = "unknown_persons"
    
    id = Column(Integer, primary_key=True, index=True)
    child_id = Column(Integer, ForeignKey("children.id"))
    face_image_path = Column(String)
    detected_at = Column(String)
    is_converted = Column(Boolean, default=False)

# 6. Alerts table
class Alert(Base):
    __tablename__ = "alerts"
    
    id = Column(Integer, primary_key=True, index=True)
    child_id = Column(Integer, ForeignKey("children.id"))
    type = Column(String)  # "SOS", "Unknown Person", "Camera Offline", etc.
    message = Column(String)
    timestamp = Column(String)
    is_resolved = Column(Boolean, default=False)

# 7. Activity History table
class ActivityHistory(Base):
    __tablename__ = "activity_history"
    
    id = Column(Integer, primary_key=True, index=True)
    child_id = Column(Integer)  # Linked child profile id
    action = Column(String)
    details = Column(String)
    timestamp = Column(String)

# 8. System Logging table
class SystemLog(Base):
    __tablename__ = "system_logs"
    
    id = Column(Integer, primary_key=True, index=True)
    timestamp = Column(String)
    level = Column(String)  # INFO, WARNING, ERROR, CRITICAL
    module = Column(String)
    action = Column(String)
    message = Column(String)
    details = Column(Text)

# 9. Captions table
class CaptionLog(Base):
    __tablename__ = "captions"
    
    id = Column(Integer, primary_key=True, index=True)
    child_id = Column(Integer)
    model_name = Column(String)  # BLIP, ViT-GPT2, Florence-2
    caption = Column(Text)
    confidence = Column(Float)
    execution_time = Column(Float)
    timestamp = Column(String)

# 10. Settings table
class Setting(Base):
    __tablename__ = "settings"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    server_ip = Column(String)
    esp32_ip = Column(String)
    websocket_url = Column(String)
    detection_threshold = Column(Float)
    default_caption_model = Column(String)
    voice_speed = Column(Float)
    voice_language = Column(String)
    notification_settings = Column(Text)  # JSON string

# 11. Notifications table
class Notification(Base):
    __tablename__ = "notifications"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    type = Column(String)
    title = Column(String)
    body = Column(String)
    sent_at = Column(String)
    status = Column(String)
