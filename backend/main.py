from fastapi import FastAPI
import mysql.connector
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
from pymongo import MongoClient
app = FastAPI()
app.add_middleware(
CORSMiddleware,
allow_origins=["*"],
allow_methods=["*"],
allow_headers=["*"],
)
def get_db_connection():
    return mysql.connector.connect(
        host="localhost",
        user="root",
        password="",
        database="student",
        port=3307
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
        try:
            mongo_users = list(mongo_collection.find({}, {"_id": 0}))
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

if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8000)