from fastapi import FastAPI, HTTPException
import mysql.connector
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
from pymongo import MongoClient
from pydantic import BaseModel
from typing import Literal, Optional
from bson import ObjectId

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

class UserIn(BaseModel):
    name: str
    gender: str
    source: Optional[Literal["MySQL", "MongoDB"]] = None

def get_db_connection():
    return mysql.connector.connect(
        host="localhost",
        user="root",
        password="",
        database="student",
        port=3306
    )

# MongoDB Connection
try:
    mongo_client = MongoClient("mongodb://localhost:27017/")
    # Test connection
    mongo_client.admin.command('ping')
    print("MongoDB connected successfully")
    
    # List all databases to debug
    databases = mongo_client.list_database_names()
    print(f"Available databases: {databases}")
    
    mongo_db = mongo_client["studentdb"]
    # List all collections to debug
    collections = mongo_db.list_collection_names()
    print(f"Available collections in student_db: {collections}")
    
    mongo_collection = mongo_db["users"]
    # Count documents to debug
    count = mongo_collection.count_documents({})
    print(f"Documents in users collection: {count}")
    
except Exception as e:
    print(f"MongoDB connection error: {e}")
    mongo_client = None
    mongo_collection = None


@app.get("/users")
def read_users():
    try:
        # ----- MySQL Data ----
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT * FROM users")
        mysql_users = cursor.fetchall()
        cursor.close()
        conn.close()
        
        # ----- MongoDB Data ----
        if mongo_collection is None:
            mongo_users = []
        else:
            try:
                mongo_users = list(mongo_collection.find({}, {"name": 1, "gender": 1}))
                for doc in mongo_users:
                    if "_id" in doc:
                        doc["_id"] = str(doc["_id"])
            except Exception as mongo_error:
                mongo_users = []
                print(f"MongoDB error: {mongo_error}")
        
        # ----- Combine Both ----
        combined_users = mysql_users + mongo_users
        print(f"MySQL users: {mysql_users}")
        print(f"MongoDB users: {mongo_users}")
        print(f"Combined: {combined_users}")
        return combined_users
    except Exception as e:
        return {"error": str(e)}

@app.post("/users")
def create_user(user: UserIn):
    source = user.source or "MySQL"
    if source == "MongoDB":
        if mongo_collection is None:
            raise HTTPException(status_code=503, detail="MongoDB is not connected")
        try:
            result = mongo_collection.insert_one({"name": user.name, "gender": user.gender})
            return {"_id": str(result.inserted_id), "name": user.name, "gender": user.gender}
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))

    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute(
            "INSERT INTO users (name, gender) VALUES (%s, %s)",
            (user.name, user.gender),
        )
        conn.commit()
        new_id = cursor.lastrowid
        cursor.execute("SELECT * FROM users WHERE idno = %s", (new_id,))
        created = cursor.fetchone()
        cursor.close()
        conn.close()
        return created
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.put("/users/{user_id}")
def update_user(user_id: str, user: UserIn, source: Optional[Literal["MySQL", "MongoDB"]] = None):
    effective_source = source or user.source or "MySQL"
    if effective_source == "MongoDB":
        if mongo_collection is None:
            raise HTTPException(status_code=503, detail="MongoDB is not connected")
        try:
            oid = ObjectId(user_id)
        except Exception:
            raise HTTPException(status_code=400, detail="Invalid MongoDB _id")

        try:
            result = mongo_collection.update_one(
                {"_id": oid},
                {"$set": {"name": user.name, "gender": user.gender}},
            )
            if result.matched_count == 0:
                raise HTTPException(status_code=404, detail="User not found")
            doc = mongo_collection.find_one({"_id": oid}, {"_id": 1, "name": 1, "gender": 1})
            return {"_id": str(doc["_id"]), "name": doc.get("name"), "gender": doc.get("gender")}
        except HTTPException:
            raise
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))

    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute(
            "UPDATE users SET name = %s, gender = %s WHERE idno = %s",
            (user.name, user.gender, user_id),
        )
        conn.commit()
        if cursor.rowcount == 0:
            cursor.close()
            conn.close()
            raise HTTPException(status_code=404, detail="User not found")
        cursor.execute("SELECT * FROM users WHERE idno = %s", (user_id,))
        updated = cursor.fetchone()
        cursor.close()
        conn.close()
        return updated
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/users/{user_id}")
def delete_user(user_id: str, source: Optional[Literal["MySQL", "MongoDB"]] = None):
    effective_source = source or "MySQL"
    if effective_source == "MongoDB":
        if mongo_collection is None:
            raise HTTPException(status_code=503, detail="MongoDB is not connected")
        try:
            oid = ObjectId(user_id)
        except Exception:
            raise HTTPException(status_code=400, detail="Invalid MongoDB _id")

        try:
            result = mongo_collection.delete_one({"_id": oid})
            if result.deleted_count == 0:
                raise HTTPException(status_code=404, detail="User not found")
            return {"status": "ok"}
        except HTTPException:
            raise
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))

    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("DELETE FROM users WHERE idno = %s", (user_id,))
        conn.commit()
        deleted = cursor.rowcount
        cursor.close()
        conn.close()
        if deleted == 0:
            raise HTTPException(status_code=404, detail="User not found")
        return {"status": "ok"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8000)