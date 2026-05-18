import os

services_dir = "/Users/kai/Desktop/bd/services"
main_py = "/Users/kai/Desktop/bd/main.py"

weather_code = '''"""
services/weather_service.py
負責向 Open-Meteo API 抓取目前天氣資訊。
"""
import requests
from services.settings_service import get_weather_locations

_WEATHER_API = "https://api.open-meteo.com/v1/forecast"

# 簡單的 WMO 天氣代碼對應表 (Emoji, 中文描述)
_WMO_MAP = {
    0: ("☀️", "晴天"),
    1: ("🌤️", "大致晴朗"), 2: ("⛅", "多雲"), 3: ("☁️", "陰天"),
    45: ("🌫️", "起霧"), 51: ("🌦️", "毛毛雨"), 61: ("🌧️", "小雨"),
    63: ("🌧️", "中雨"), 65: ("🌧️", "大雨"), 80: ("🌦️", "陣雨"),
    95: ("⛈️", "雷雨")
}

# 預設地點（當使用者沒有設定時使用）
_DEFAULT_LOCATIONS = [{"name": "臺北", "lat": 25.04, "lon": 121.51, "country": "台灣"}]

def fetch_weather() -> list[dict]:
    """抓取設定地點的天氣，回傳包含溫度、濕度、風速等資訊的字典列表。"""
    locations = get_weather_locations() or _DEFAULT_LOCATIONS
    results = []
    
    for loc in locations[:2]: # 最多抓取兩個地點
        try:
            resp = requests.get(
                _WEATHER_API,
                params={
                    "latitude": loc["lat"],
                    "longitude": loc["lon"],
                    "current": "temperature_2m,apparent_temperature,weathercode,relativehumidity_2m,windspeed_10m",
                    "timezone": "Asia/Taipei",
                },
                timeout=5,
            )
            resp.raise_for_status()
            data = resp.json().get("current", {})
            
            # 解析天氣代碼，若找不到對應則顯示未知
            code = int(data.get("weathercode", 0))
            emoji, condition = _WMO_MAP.get(code, ("🌡️", "未知"))
            
            results.append({
                "name": loc["name"],
                "temp": round(data.get("temperature_2m", 0), 1),
                "feels_like": round(data.get("apparent_temperature", 0), 1),
                "emoji": emoji,
                "condition": condition,
                "humidity": int(data.get("relativehumidity_2m", 0)),
                "wind_speed": round(data.get("windspeed_10m", 0), 1),
            })
        except Exception:
            # 發生錯誤時給予預設佔位內容
            results.append({
                "name": loc.get("name", "未知地點"),
                "temp": "--", "feels_like": "--",
                "emoji": "❓", "condition": "無法取得資料",
                "humidity": "--", "wind_speed": "--",
            })
            
    return results
'''

youbike_code = '''"""
services/youbike_service.py
負責抓取 YouBike 2.0 即時站點資訊。
"""
import requests
from services.settings_service import get_youbike_stations

_YOUBIKE_API = "https://tcgbusfs.blob.core.windows.net/dotapp/youbike/v2/youbike_immediate.json"

def fetch_youbike() -> list[dict]:
    """抓取設定好的 YouBike 站點狀態（包含可借車輛、空位數量）。"""
    saved = get_youbike_stations()
    try:
        resp = requests.get(_YOUBIKE_API, timeout=8)
        resp.raise_for_status()
        all_stations = resp.json()

        if saved:
            # 過濾出使用者設定的站點
            saved_snos = {s["sno"] for s in saved}
            filtered = [s for s in all_stations if s.get("sno") in saved_snos]
        else:
            # 如果沒有設定，隨機(按名稱排序)取前 5 個作為 Demo
            filtered = sorted(all_stations, key=lambda s: s.get("sna", ""))[:5]

        # 整理成 UI 需要的格式
        return [{
            "sno": s.get("sno", ""),
            "sna": s.get("sna", ""),
            "sarea": s.get("sarea", ""),
            "sbi": int(s.get("sbi", 0)),    # 可借車輛數
            "bemp": int(s.get("bemp", 0)),  # 空車位數
            "tot": int(s.get("tot", 0)),    # 總車位數
            "act": s.get("act", "1"),       # 1 表示正常營運
        } for s in filtered]
        
    except Exception as exc:
        return [{"sna": f"無法取得資料 ({exc})", "sbi": 0, "bemp": 0, "tot": 0, "act": "0"}]
'''

state_code = '''"""
services/state.py
負責管理整個應用程式的狀態（像是目前是誰站在前面，是否正在註冊等）。
使用 PyQt 的 pyqtSignal 讓狀態改變時能自動通知 UI 更新。
"""
import threading
from PyQt6.QtCore import QObject, pyqtSignal

class AppState(QObject):
    # 定義通知 UI 的各種訊號 (Signals)
    mode_changed = pyqtSignal(str, list)   # 模式改變 (idle, guest, users)
    rebuild_started = pyqtSignal()         # 臉部特徵庫開始重建
    rebuild_done = pyqtSignal()            # 臉部特徵庫重建完成

    def __init__(self):
        super().__init__()
        self.mode = "idle"                # 預設模式：無人 (idle)
        self.identified_users = []        # 辨識出來的使用者名單

        # 用於與背景攝影機執行緒溝通的變數
        self.force_rescan = threading.Event()
        self.register_flag = (False, "")
        self.register_lock = threading.Lock()

    def set_mode(self, mode: str, users: list = None) -> None:
        """設定目前的模式，並發送訊號通知 UI"""
        self.mode = mode
        self.identified_users = users or []
        self.mode_changed.emit(mode, self.identified_users)

    def start_register(self, user_id: str) -> None:
        """發出註冊新使用者的請求"""
        with self.register_lock:
            self.register_flag = (True, user_id)

    def consume_register_flag(self) -> tuple[bool, str]:
        """攝影機讀取註冊請求，讀取後清除請求"""
        with self.register_lock:
            flag = self.register_flag
            self.register_flag = (False, "")
            return flag

    def trigger_rescan(self) -> None:
        """強制攝影機重新掃描人臉"""
        self.force_rescan.set()
'''

database_code = '''"""
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
    
    # 建立行事曆與設定表
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
    """)
    conn.commit()

    # 寫入行事曆 Demo 資料
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
'''

settings_code = '''"""
services/settings_service.py
封裝所有設定相關的邏輯，包含讀取天氣、YouBike、相機設定，以及處理搜尋 API。
"""
import requests
import subprocess
import platform
from services.database import get_setting, set_setting

# ── 天氣設定 ──
def get_weather_locations() -> list[dict]:
    return get_setting("weather_locations", [])[:2]

def set_weather_locations(locations: list[dict]):
    set_setting("weather_locations", locations[:2])

# ── YouBike設定 ──
def get_youbike_stations() -> list[dict]:
    return get_setting("youbike_stations", [])[:2]

def set_youbike_stations(stations: list[dict]):
    set_setting("youbike_stations", stations[:2])

# ── 攝影機設定 ──
def get_camera_index() -> int:
    return int(get_setting("camera_index", 0))

def set_camera_index(index: int):
    set_setting("camera_index", index)

def get_available_cameras() -> list[str]:
    """獲取可用的攝影機列表（針對 Mac 特別處理名稱）"""
    cams = []
    if platform.system() == "Darwin":
        try:
            # 透過 Swift 呼叫蘋果底層 API 來取得攝影機真實名稱
            res = subprocess.run(
                ["swift", "-"], 
                input="import AVFoundation\\nfor d in AVCaptureDevice.devices(for: .video) { print(d.localizedName) }", 
                capture_output=True, text=True, timeout=2
            )
            cams = [line.strip() for line in res.stdout.splitlines() if line.strip()]
        except Exception:
            pass
    # 若抓不到，給予預設名稱
    while len(cams) < 5:
        cams.append(f"攝影機 {len(cams)}")
    return cams[:5]

# ── 搜尋 API ──
def search_weather_location(query: str) -> list[dict]:
    """搜尋城市名稱 (使用 Open-Meteo Geocoding)"""
    if not query.strip(): return []
    try:
        resp = requests.get(
            "https://geocoding-api.open-meteo.com/v1/search",
            params={"name": query, "count": 10, "language": "zh", "format": "json"},
            timeout=5
        ).json()
        return [{"name": r.get("name"), "lat": r.get("latitude"), "lon": r.get("longitude")} for r in resp.get("results", [])]
    except Exception:
        return []

def search_youbike_stations(query: str) -> list[dict]:
    """搜尋 YouBike 站點"""
    if not query.strip(): return []
    try:
        stations = requests.get("https://tcgbusfs.blob.core.windows.net/dotapp/youbike/v2/youbike_immediate.json", timeout=5).json()
        q = query.lower()
        return [{"sno": s.get("sno"), "sna": s.get("sna"), "sarea": s.get("sarea")} for s in stations if q in s.get("sna", "").lower()][:20]
    except Exception:
        return []
'''

camera_code = '''"""
services/camera_service.py
負責在背景透過 OpenCV 捕捉畫面，並利用 DeepFace 進行人臉辨識。
這是一個獨立的背景執行緒 (Thread)，不會卡住 UI。
"""
import os
import glob
import time
import threading
import logging
import cv2
import numpy as np
from services.state import AppState

logger = logging.getLogger(__name__)

# 人臉資料庫存放路徑
FACE_DB_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "face_db")
# OpenCV 的 Haar 級聯分類器（初步偵測是否有人臉，速度快但較不精準）
_CASCADE_PATH = cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
_NO_FACE_TIMEOUT = 5.0   # 多久沒看到人臉就將 UI 切回閒置模式
_LOOP_INTERVAL = 0.6     # 迴圈間隔 (節省 CPU 資源)

class CameraService:
    def __init__(self, state: AppState):
        self._state = state
        self._stop_event = threading.Event()
        self._thread = threading.Thread(target=self._loop, daemon=True)
        self._cascade = cv2.CascadeClassifier(_CASCADE_PATH)
        self._cap = None
        self._last_face_time = 0.0

    def start(self):
        """啟動攝影機背景服務"""
        os.makedirs(FACE_DB_DIR, exist_ok=True)
        self._thread.start()

    def stop(self):
        """停止攝影機背景服務"""
        self._stop_event.set()

    def _loop(self):
        """主要的攝影機執行迴圈"""
        from services.settings_service import get_camera_index
        
        # 開啟攝影機
        self._cap = cv2.VideoCapture(get_camera_index())
        if not self._cap.isOpened():
            # 找不到攝影機就直接結束 (依靠 UI 的 Demo 按鈕展示)
            return

        try:
            while not self._stop_event.is_set():
                # 處理「重新辨識」的請求
                if self._state.force_rescan.is_set():
                    self._state.force_rescan.clear()
                    self._last_face_time = 0.0

                # 處理「註冊新人員」的請求
                active, user_id = self._state.consume_register_flag()
                if active and user_id:
                    self._handle_register(user_id)
                    time.sleep(_LOOP_INTERVAL)
                    continue

                # 抓取目前畫面
                ret, frame = self._cap.read()
                if not ret:
                    time.sleep(_LOOP_INTERVAL)
                    continue

                # 階段一：使用快速的 OpenCV 偵測是否有人臉
                gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
                faces = self._cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5, minSize=(60, 60))

                if len(faces) == 0:
                    # 如果畫面上沒人，檢查是不是已經超過超時時間，是的話切換為閒置模式
                    if self._last_face_time > 0 and (time.monotonic() - self._last_face_time >= _NO_FACE_TIMEOUT):
                        self._last_face_time = 0.0
                        self._state.set_mode("idle")
                    time.sleep(_LOOP_INTERVAL)
                    continue

                # 畫面上有人臉，更新時間戳記
                self._last_face_time = time.monotonic()

                # 階段二：使用較耗資源的 DeepFace 進行「辨識」是誰
                users = self._run_deepface(frame)
                if users:
                    self._state.set_mode("users", users)
                else:
                    self._state.set_mode("guest")

                time.sleep(_LOOP_INTERVAL)
        finally:
            if self._cap:
                self._cap.release()

    def _run_deepface(self, frame: np.ndarray) -> list[str] | None:
        """透過 DeepFace 比對資料庫，回傳辨識出的人名列表。"""
        # 如果資料庫是空的，直接當作訪客
        if not [d for d in os.listdir(FACE_DB_DIR) if os.path.isdir(os.path.join(FACE_DB_DIR, d))]:
            return None

        try:
            from deepface import DeepFace
            # 進行人臉比對，開啟防偽 (anti_spoofing) 避免照片騙過相機
            results = DeepFace.find(
                img_path=frame, db_path=FACE_DB_DIR,
                model_name="ArcFace", detector_backend="retinaface",
                anti_spoofing=True, enforce_detection=False, silent=True
            )

            user_ids = []
            for df in results:
                if not df.empty:
                    # 從檔案路徑中抽取出人名 (face_db/人名/圖片.jpg)
                    uid = os.path.relpath(df.iloc[0]["identity"], FACE_DB_DIR).split(os.sep)[0]
                    if uid not in user_ids:
                        user_ids.append(uid)
            return user_ids if user_ids else None
        except Exception:
            return None

    def _handle_register(self, user_id: str):
        """處理註冊請求：拍照存檔並強制 DeepFace 重新建立特徵庫"""
        self._state.rebuild_started.emit() # 通知 UI 顯示載入轉圈圈
        
        ret, frame = self._cap.read()
        if ret:
            # 1. 建立資料夾並儲存照片
            user_dir = os.path.join(FACE_DB_DIR, user_id)
            os.makedirs(user_dir, exist_ok=True)
            cv2.imwrite(os.path.join(user_dir, f"frame_{int(time.time())}.jpg"), frame)

            # 2. 刪除舊的特徵庫快取 (.pkl)
            for pkl in glob.glob(os.path.join(FACE_DB_DIR, "**", "*.pkl"), recursive=True):
                try: os.remove(pkl)
                except OSError: pass

            # 3. 呼叫 find 強制 DeepFace 重新學習一次資料庫
            try:
                from deepface import DeepFace
                DeepFace.find(img_path=frame, db_path=FACE_DB_DIR, enforce_detection=False, silent=True)
            except Exception:
                pass
                
        self._state.rebuild_done.emit() # 通知 UI 結束轉圈圈
'''

main_code = '''"""
main.py
玄關智慧中樞 — Entryway Smart Hub
程式進入點：負責啟動 Qt 應用程式、初始化服務，並扮演 Python 與 QML (UI) 溝通的橋樑。
"""
import sys
import os
import threading
from pathlib import Path

from PyQt6.QtCore import QObject, pyqtSlot, pyqtSignal
from PyQt6.QtGui import QGuiApplication
from PyQt6.QtQml import QQmlApplicationEngine

# 引入自訂的各種服務
from services.database import init_db
from services.state import AppState
from services.camera_service import CameraService
from services.weather_service import fetch_weather
from services.youbike_service import fetch_youbike
from services import database, settings_service


class Backend(QObject):
    """
    這是一個作為前端 (QML) 與後端 (Python Services) 橋樑的類別。
    所有 QML 介面要抓資料或呼叫功能，都是透過這裡。
    """
    
    # 定義發送給 QML 的訊號 (Signals)
    modeChanged = pyqtSignal(str, 'QVariantList')    # 通知模式改變 (閒置/訪客/已辨識使用者)
    rebuildStarted = pyqtSignal()                    # 通知開始重建人臉資料庫
    rebuildDone = pyqtSignal()                       # 通知重建結束
    
    weatherUpdated = pyqtSignal('QVariantList')      # 通知天氣資料已更新
    youbikeUpdated = pyqtSignal('QVariantList')      # 通知 YouBike 資料已更新
    calendarUpdated = pyqtSignal('QVariantList')     # 通知行事曆資料已更新
    
    weatherSearchResults = pyqtSignal('QVariantList')# 通知天氣搜尋結果
    youbikeSearchResults = pyqtSignal('QVariantList')# 通知 YouBike 搜尋結果
    settingsLoaded = pyqtSignal('QVariantList', 'QVariantList', int, 'QVariantList') # 載入設定

    def __init__(self, state: AppState, camera: CameraService):
        super().__init__()
        self.state = state
        self.camera = camera
        self._demo_active = False
        
        # 綁定：當後台 state 改變時，觸發我們自己定義的訊號給 QML
        self.state.mode_changed.connect(self._on_mode_change)
        self.state.rebuild_started.connect(self.rebuildStarted.emit)
        self.state.rebuild_done.connect(self.rebuildDone.emit)

    def _on_mode_change(self, mode: str, users: list[str]):
        """當攝影機偵測狀態改變時，更新 UI 並刷新資料"""
        self.modeChanged.emit(mode, users)
        if mode != "idle":
            self.fetch_youbike()
            self.fetch_calendar(users)

    # ── 給 QML 呼叫的函式 (Slots) ──

    @pyqtSlot()
    def trigger_rescan(self):
        """從 UI 按下「重新辨識」"""
        self.state.set_mode("idle")
        self.state.trigger_rescan()

    @pyqtSlot(str)
    def register_user(self, user_id: str):
        """從 UI 按下「註冊新人員」"""
        self.state.start_register(user_id)

    @pyqtSlot()
    def toggle_demo(self):
        """開啟/關閉模擬測試模式"""
        self._demo_active = not self._demo_active
        if self._demo_active:
            self.state.set_mode("users", ["jason", "mark"])
        else:
            self.state.set_mode("idle")

    @pyqtSlot()
    def fetch_weather(self):
        """非同步抓取天氣，避免卡住畫面"""
        def _do():
            self.weatherUpdated.emit(fetch_weather())
        threading.Thread(target=_do, daemon=True).start()

    @pyqtSlot()
    def fetch_youbike(self):
        """非同步抓取 YouBike，避免卡住畫面"""
        def _do():
            self.youbikeUpdated.emit(fetch_youbike())
        threading.Thread(target=_do, daemon=True).start()
        
    def fetch_calendar(self, users: list[str]):
        """非同步抓取行事曆，避免卡住畫面"""
        def _do():
            self.calendarUpdated.emit(database.get_events(users))
        threading.Thread(target=_do, daemon=True).start()

    # ── 設定相關 (Settings) ──

    @pyqtSlot()
    def load_settings(self):
        """讀取目前所有設定，並傳送給 UI"""
        self.settingsLoaded.emit(
            settings_service.get_weather_locations(),
            settings_service.get_youbike_stations(),
            settings_service.get_camera_index(),
            settings_service.get_available_cameras()
        )

    @pyqtSlot('QVariantList', 'QVariantList', int)
    def save_settings(self, w_locs, b_locs, c_idx):
        """儲存從 UI 傳來的設定，並立刻刷新畫面資料"""
        settings_service.set_weather_locations(list(w_locs))
        settings_service.set_youbike_stations(list(b_locs))
        settings_service.set_camera_index(c_idx)
        
        self.fetch_weather()
        if self.state.mode != "idle":
            self.fetch_youbike()

    @pyqtSlot(str)
    def search_weather(self, query: str):
        def _do(): self.weatherSearchResults.emit(settings_service.search_weather_location(query))
        threading.Thread(target=_do, daemon=True).start()

    @pyqtSlot(str)
    def search_youbike(self, query: str):
        def _do(): self.youbikeSearchResults.emit(settings_service.search_youbike_stations(query))
        threading.Thread(target=_do, daemon=True).start()


def main():
    # 解決 Mac 上預設樣式不允許改變按鈕顏色的問題
    os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"
    
    # 建立應用程式主體
    app = QGuiApplication(sys.argv)
    
    # 初始化資料庫與狀態
    init_db()
    state = AppState()
    
    # 啟動相機背景服務
    camera = CameraService(state=state)
    camera.start()
    
    # 建立連接 UI 與 Python 的橋樑
    backend = Backend(state, camera)
    
    # 啟動 QML 引擎並註冊橋樑
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("backend", backend)
    
    # 載入主介面 QML
    qml_file = Path(__file__).parent / "qml" / "main.qml"
    engine.load(QUrl.fromLocalFile(str(qml_file)))
    
    if not engine.rootObjects():
        sys.exit(-1)
        
    # 一啟動就先抓一次天氣
    backend.fetch_weather()
    
    # 進入主迴圈，直到視窗關閉
    res = app.exec()
    
    # 關閉時安全結束相機服務
    camera.stop()
    sys.exit(res)

if __name__ == "__main__":
    main()
'''

with open(f"{services_dir}/weather_service.py", "w") as f: f.write(weather_code)
with open(f"{services_dir}/youbike_service.py", "w") as f: f.write(youbike_code)
with open(f"{services_dir}/state.py", "w") as f: f.write(state_code)
with open(f"{services_dir}/database.py", "w") as f: f.write(database_code)
with open(f"{services_dir}/settings_service.py", "w") as f: f.write(settings_code)
with open(f"{services_dir}/camera_service.py", "w") as f: f.write(camera_code)
with open(main_py, "w") as f: f.write(main_code)
