import os

DB_FOLDER = "database"

if not os.path.exists(DB_FOLDER):
    os.makedirs(DB_FOLDER)

def save_image(file, name):
    path = os.path.join(DB_FOLDER, f"{name}_{file.filename}")
    
    with open(path, "wb") as f:
        f.write(file.file.read())

    return path