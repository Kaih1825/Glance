"""
services/database.py
負責與 SQLite 資料庫互動，包含行事曆事件與設定參數的存取。
"""
import sqlite3
import json
import os
from contextlib import closing

DB_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), "entryway.db")

def _get_conn():
    """取得資料庫連線"""
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    return conn

def init_db() -> None:
    """初始化資料庫與資料表"""
    with closing(_get_conn()) as conn:
        conn.executescript("""
            CREATE TABLE IF NOT EXISTS events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                start_dt TEXT NOT NULL,
                end_dt TEXT NOT NULL,
                visibility TEXT NOT NULL DEFAULT 'public',
                owner_id TEXT
            );
            CREATE TABLE IF NOT EXISTS settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL DEFAULT '{}'
            );
            CREATE TABLE IF NOT EXISTS users (
                uuid TEXT PRIMARY KEY,
                name TEXT NOT NULL UNIQUE
            );
        """)
        conn.commit()

def get_events(user_ids: list[str]) -> list[dict]:
    """根據辨識出的使用者，回傳他們有權限看到的行事曆事件"""
    with closing(_get_conn()) as conn:
        rows = conn.execute("SELECT * FROM events ORDER BY start_dt ASC").fetchall()
    
    filtered_events = []
    for r in rows:
        event = dict(r)
        vis = event.get("visibility", "public")
        owner_id = event.get("owner_id")
        
        if vis == "public":
            filtered_events.append(event)
        elif vis in ("private", "shared") and owner_id and user_ids:
            owners = [o.strip() for o in owner_id.split(",")]
            if any(uid in owners for uid in user_ids):
                filtered_events.append(event)
                    
    return filtered_events

def get_setting(key: str, default=None):
    """取得設定值 (JSON格式)"""
    with closing(_get_conn()) as conn:
        row = conn.execute("SELECT value FROM settings WHERE key = ?", (key,)).fetchone()
        return json.loads(row["value"]) if row else default

def set_setting(key: str, value) -> None:
    """儲存設定值 (轉為JSON儲存)"""
    with closing(_get_conn()) as conn:
        conn.execute("INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)", 
                     (key, json.dumps(value, ensure_ascii=False)))
        conn.commit()

def get_user_uuid(name: str) -> str | None:
    """根據使用者名稱取得其 UUID"""
    with closing(_get_conn()) as conn:
        row = conn.execute("SELECT uuid FROM users WHERE name = ?", (name,)).fetchone()
        return row["uuid"] if row else None

def add_user(uuid_str: str, name: str) -> None:
    """新增使用者與其 UUID 對應關係"""
    with closing(_get_conn()) as conn:
        conn.execute("INSERT OR REPLACE INTO users (uuid, name) VALUES (?, ?)", (uuid_str, name))
        conn.commit()

def get_user_names(uuids: list[str]) -> list[str]:
    """將辨識出的 UUID 列表轉換為使用者名稱列表"""
    if not uuids:
        return []
    placeholders = ",".join("?" * len(uuids))
    with closing(_get_conn()) as conn:
        rows = conn.execute(f"SELECT name FROM users WHERE uuid IN ({placeholders})", uuids).fetchall()
        return [r["name"] for r in rows]

def add_event(title: str, start_dt: str, end_dt: str, visibility: str, owner_id: str | None = None) -> bool:
    """新增行事曆事件"""
    try:
        with closing(_get_conn()) as conn:
            conn.execute(
                "INSERT INTO events (title, start_dt, end_dt, visibility, owner_id) VALUES (?, ?, ?, ?, ?)",
                (title, start_dt, end_dt, visibility, owner_id)
            )
            conn.commit()
            return True
    except Exception as e:
        print(f"Error adding event: {e}")
        return False

def get_all_user_names() -> list[str]:
    """取得所有使用者名稱"""
    with closing(_get_conn()) as conn:
        rows = conn.execute("SELECT name FROM users ORDER BY name ASC").fetchall()
        return [r["name"] for r in rows]

def get_home_location() -> dict | None:
    """取得使用者設定的主要位置（lat, lng, name），若未設定則回傳 None"""
    return get_setting("home_location")

def set_home_location(lat: float, lng: float, name: str) -> None:
    """儲存使用者的主要位置"""
    set_setting("home_location", {"lat": lat, "lng": lng, "name": name})
