"""
services/database.py
負責與 SQLite 資料庫互動，包含行事曆事件與設定參數的存取。
"""
import sqlite3
import json
import os
from datetime import datetime, timedelta

DB_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), "entryway.db")

def _get_conn():
    """取得資料庫連線"""
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    return conn

def init_db() -> None:
    """初始化資料庫與資料表，若無資料則建立預設 Demo 資料"""
    conn = _get_conn()
    cur = conn.cursor()
    
    # 建立行事曆、設定表與使用者 UUID 對照表
    cur.executescript("""
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

    # 寫入行行曆 Demo 資料
    if cur.execute("SELECT COUNT(*) FROM events").fetchone()[0] == 0:
        _seed_demo_data(cur)
        conn.commit()
    conn.close()

def _seed_demo_data(cur) -> None:
    """產生幾筆假行事曆資料供展示使用"""
    today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    events = [
        ("社區公告：電梯維修", today + timedelta(hours=9), today + timedelta(hours=11), "public", None),
        ("牙醫預約", today + timedelta(days=1, hours=14), today + timedelta(days=1, hours=15), "private", "jason"),
        ("健身房", today + timedelta(hours=7), today + timedelta(hours=8), "private", "mark"),
    ]
    cur.executemany(
        "INSERT INTO events (title, start_dt, end_dt, visibility, owner_id) VALUES (?,?,?,?,?)",
        [(t, s.isoformat(), e.isoformat(), v, o) for t, s, e, v, o in events],
    )

def get_events(user_ids: list[str]) -> list[dict]:
    """根據辨識出的使用者，回傳他們有權限看到的行事曆事件"""
    conn = _get_conn()
    now = datetime.now().isoformat()
    
    if user_ids:
        # 顯示公開事件 + 該使用者的私人事件
        placeholders = ",".join("?" * len(user_ids))
        query = f"""
            SELECT * FROM events WHERE end_dt >= ? AND 
            (visibility = 'public' OR (visibility IN ('private','shared') AND owner_id IN ({placeholders})))
            ORDER BY start_dt ASC
        """
        rows = conn.execute(query, [now] + user_ids).fetchall()
    else:
        # 訪客只顯示公開事件
        rows = conn.execute(
            "SELECT * FROM events WHERE visibility = 'public' AND end_dt >= ? ORDER BY start_dt ASC",
            (now,)
        ).fetchall()
        
    conn.close()
    return [dict(r) for r in rows]

def get_setting(key: str, default=None):
    """取得設定值 (JSON格式)"""
    conn = _get_conn()
    row = conn.execute("SELECT value FROM settings WHERE key = ?", (key,)).fetchone()
    conn.close()
    return json.loads(row["value"]) if row else default

def set_setting(key: str, value) -> None:
    """儲存設定值 (轉為JSON儲存)"""
    conn = _get_conn()
    conn.execute(
        "INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)",
        (key, json.dumps(value, ensure_ascii=False)),
    )
    conn.commit()
    conn.close()

def get_user_uuid(name: str) -> str | None:
    """根據使用者名稱取得其 UUID"""
    conn = _get_conn()
    row = conn.execute("SELECT uuid FROM users WHERE name = ?", (name,)).fetchone()
    conn.close()
    return row["uuid"] if row else None

def add_user(uuid_str: str, name: str) -> None:
    """新增使用者與其 UUID 對應關係"""
    conn = _get_conn()
    conn.execute("INSERT OR REPLACE INTO users (uuid, name) VALUES (?, ?)", (uuid_str, name))
    conn.commit()
    conn.close()

def get_user_names(uuids: list[str]) -> list[str]:
    """將辨識出的 UUID 列表轉換為使用者名稱列表"""
    if not uuids:
        return []
    conn = _get_conn()
    placeholders = ",".join("?" * len(uuids))
    rows = conn.execute(f"SELECT name FROM users WHERE uuid IN ({placeholders})", uuids).fetchall()
    conn.close()
    return [r["name"] for r in rows]

def add_event(title: str, start_dt: str, end_dt: str, visibility: str, owner_id: str | None = None) -> bool:
    """新增行事曆事件"""
    conn = _get_conn()
    try:
        conn.execute(
            "INSERT INTO events (title, start_dt, end_dt, visibility, owner_id) VALUES (?, ?, ?, ?, ?)",
            (title, start_dt, end_dt, visibility, owner_id)
        )
        conn.commit()
        return True
    except Exception as e:
        print(f"Error adding event: {e}")
        return False
    finally:
        conn.close()

