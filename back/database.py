import os
import sys
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

# Reconfigure output stream encoding for UTF-8 compatibility on Windows terminal
if hasattr(sys.stdout, 'reconfigure'):
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

DATABASE_URL = os.getenv(
    "DATABASE_URL", 
    "postgresql://postgres:postgres@localhost:5432/basira"
)

use_sqlite = False
if DATABASE_URL.startswith("postgresql"):
    try:
        import psycopg2
    except ImportError:
        print("[WARNING] psycopg2 is not installed. Cannot connect to PostgreSQL.")
        use_sqlite = True

if use_sqlite:
    print("[INFO] Falling back to local SQLite database.")
    DATABASE_URL = "sqlite:///./basera.db"

connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}

try:
    # Try connecting to database
    engine = create_engine(DATABASE_URL, connect_args=connect_args)
    # Test connection
    with engine.connect() as conn:
        print(f"[INFO] Connected to database: {DATABASE_URL}")
except Exception as e:
    print(f"[WARNING] Failed to connect to database at {DATABASE_URL}: {e}")
    print("[WARNING] Falling back to SQLite database: sqlite:///./basera.db")
    DATABASE_URL = "sqlite:///./basera.db"
    engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})

SessionLocal = sessionmaker(bind=engine)
Base = declarative_base()