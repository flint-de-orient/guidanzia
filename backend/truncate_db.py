import sqlite3
import os

def truncate_database():
    db_path = os.path.join(os.path.dirname(__file__), 'users.db')
    
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # Delete all data from all tables
        cursor.execute('DELETE FROM users')
        cursor.execute('DELETE FROM user_sessions')
        cursor.execute('DELETE FROM job_role_details')
        
        # Reset auto-increment counters
        cursor.execute('DELETE FROM sqlite_sequence WHERE name="users"')
        cursor.execute('DELETE FROM sqlite_sequence WHERE name="user_sessions"')
        cursor.execute('DELETE FROM sqlite_sequence WHERE name="job_role_details"')
        
        # Commit changes
        conn.commit()
        
        # Vacuum to reclaim space
        cursor.execute('VACUUM')
        
        conn.close()
        
        print("SUCCESS: Database truncated successfully!")
        print("- All user data cleared")
        print("- All session data cleared") 
        print("- All job role details cleared")
        print("- Auto-increment counters reset")
        print("- Database space reclaimed")
        
    except Exception as e:
        print(f"ERROR: Error truncating database: {e}")

if __name__ == "__main__":
    truncate_database()