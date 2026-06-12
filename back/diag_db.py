import sqlite3
import os

db_path = 'basera.db'
if not os.path.exists(db_path):
    print("Database file not found!")
else:
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    cur.execute("SELECT name FROM sqlite_master WHERE type='table'")
    tables = cur.fetchall()
    print(f"Tables: {tables}")
    for table in tables:
        name = table[0]
        cur.execute(f"PRAGMA table_info({name})")
        info = cur.fetchall()
        print(f"Table {name} info: {info}")
    conn.close()
