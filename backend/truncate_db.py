import sqlite3
import os

def truncate_database():
    db_path = os.path.join(os.path.dirname(__file__), 'users.db')
    
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # Delete all data from all tables
        cursor.execute('DELETE FROM users')
        cursor.execute('DELETE FROM user_session')
        cursor.execute('DELETE FROM job_role_details')
        cursor.execute('DELETE FROM onboarding_data')
        cursor.execute('DELETE FROM career_recommendations')
        
        # Reset auto-increment counters
        cursor.execute('DELETE FROM sqlite_sequence WHERE name="users"')
        cursor.execute('DELETE FROM sqlite_sequence WHERE name="job_role_details"')
        cursor.execute('DELETE FROM sqlite_sequence WHERE name="user_session"')
        cursor.execute('DELETE FROM sqlite_sequence WHERE name="onboarding_data"')
        cursor.execute('DELETE FROM sqlite_sequence WHERE name="career_recommendations"')
        
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