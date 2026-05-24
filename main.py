"""
main.py
玄關智慧中樞 — Entryway Smart Hub
程式進入點：負責啟動 Qt 應用程式、初始化服務，並扮演 Python 與 QML (UI) 溝通的橋樑。
"""
import sys
import os
import threading
from pathlib import Path

from PyQt6.QtCore import QObject, pyqtSlot, pyqtSignal, QUrl
from PyQt6.QtGui import QGuiApplication
from PyQt6.QtQml import QQmlApplicationEngine

# 引入自訂的各種服務
from services.database import init_db
from services.state import AppState
from services.camera_service import CameraService
from services.weather_service import fetch_weather
from services.youbike_service import fetch_youbike
from services import database, settings_service
from services.recommendation_service import fetch_recommendation


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
    
    weatherFetchStarted = pyqtSignal()
    youbikeFetchStarted = pyqtSignal()
    recommendationFetchStarted = pyqtSignal()
    
    weatherSearchResults = pyqtSignal('QVariantList')# 通知天氣搜尋結果
    youbikeSearchResults = pyqtSignal('QVariantList')# 通知 YouBike 搜尋結果
    settingsLoaded = pyqtSignal('QVariantList', 'QVariantList', int, 'QVariantList') # 載入設定
    previewFrame = pyqtSignal(str)                   # 攝影機預覽畫面
    recommendationUpdated = pyqtSignal('QVariantMap')# 推薦站點資料更新
    homeLocationSearchResults = pyqtSignal('QVariantList') # 位置搜尋結果
    homeLocationLoaded = pyqtSignal('QVariantMap')   # 通知 QML 目前已儲存的位置

    def __init__(self, state: AppState, camera: CameraService):
        super().__init__()
        self.state = state
        self.camera = camera
        
        # 綁定：當後台 state 改變時，觸發我們自己定義的訊號給 QML
        self.state.mode_changed.connect(self._on_mode_change)
        self.state.rebuild_started.connect(self.rebuildStarted.emit)
        self.state.rebuild_done.connect(self.rebuildDone.emit)
        self.state.preview_frame.connect(self.previewFrame.emit)

    def _on_mode_change(self, mode: str, users: list[str]):
        """當攝影機偵測狀態改變時，更新 UI 並刷新資料"""
        self.modeChanged.emit(mode, users)
        if mode != "idle":
            self.fetch_youbike()
            self.fetch_calendar(users)
            self.fetch_recommendation()

    # ── 給 QML 呼叫的函式 (Slots) ──

    @pyqtSlot(str)
    def register_user(self, user_id: str):
        """從 UI 按下「註冊新人員」"""
        self.state.start_register(user_id)

    @pyqtSlot(str, str, str, str, str)
    def add_event(self, title: str, start_dt: str, end_dt: str, visibility: str, owner_id: str):
        """從 UI 新增行事曆事件"""
        owner = owner_id if (owner_id and owner_id != "None" and owner_id != "") else None
        success = database.add_event(title, start_dt, end_dt, visibility, owner)
        if success:
            self.fetch_calendar(self.state.identified_users)

    @pyqtSlot(result='QVariantList')
    def get_all_users(self):
        """取得所有註冊使用者"""
        return database.get_all_user_names()


    @pyqtSlot()
    def fetch_weather(self):
        """非同步抓取天氣，避免卡住畫面"""
        self.weatherFetchStarted.emit()
        threading.Thread(target=lambda: self.weatherUpdated.emit(fetch_weather()), daemon=True).start()

    @pyqtSlot()
    def fetch_youbike(self):
        """非同步抓取 YouBike，避免卡住畫面"""
        self.youbikeFetchStarted.emit()
        threading.Thread(target=lambda: self.youbikeUpdated.emit(fetch_youbike()), daemon=True).start()
        
    def fetch_calendar(self, users: list[str]):
        """非同步抓取行事曆，避免卡住畫面"""
        threading.Thread(target=lambda: self.calendarUpdated.emit(database.get_events(users)), daemon=True).start()

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

    def _clean_qjsvalue(self, array):
        """將 QML 傳來的 JS 陣列安全轉換為純 Python 字典列表"""
        res = []
        for item in array:
            if hasattr(item, 'toVariant'):
                item = item.toVariant()
            res.append(dict(item))
        return res

    @pyqtSlot('QVariantList', 'QVariantList', int)
    def save_settings(self, w_locs, b_locs, c_idx):
        """儲存從 UI 傳來的設定，並立刻刷新畫面資料與攝影機"""
        old_idx = settings_service.get_camera_index()
        
        settings_service.set_weather_locations(self._clean_qjsvalue(w_locs))
        settings_service.set_youbike_stations(self._clean_qjsvalue(b_locs))
        settings_service.set_camera_index(c_idx)
        
        # 攝影機改變時重新連線
        if old_idx != c_idx:
            self.camera.reconnect_camera()
            
        self.fetch_weather()
        if self.state.mode != "idle":
            self.fetch_youbike()

    @pyqtSlot(str)
    def search_weather(self, query: str):
        threading.Thread(target=lambda: self.weatherSearchResults.emit(settings_service.search_weather_location(query)), daemon=True).start()

    @pyqtSlot(str)
    def search_youbike(self, query: str):
        threading.Thread(target=lambda: self.youbikeSearchResults.emit(settings_service.search_youbike_stations(query)), daemon=True).start()

    # ── 推薦站點 (Recommendation) ──

    @pyqtSlot()
    def fetch_recommendation(self):
        """非同步取得附近最推薦的 YouBike 站點"""
        self.recommendationFetchStarted.emit()
        def _do():
            loc = settings_service.get_home_location()
            result = fetch_recommendation(loc["lat"], loc["lng"]) if loc else None
            self.recommendationUpdated.emit(result or {})
        threading.Thread(target=_do, daemon=True).start()

    @pyqtSlot(float, float, str)
    def save_home_location(self, lat: float, lng: float, name: str):
        """儲存使用者主要位置，並立刻觸發推薦更新"""
        settings_service.set_home_location(lat, lng, name)
        settings_service.init_default_data()
        self.fetch_recommendation()
        self.fetch_weather()
        if self.state.mode != "idle":
            self.fetch_youbike()

    @pyqtSlot()
    def load_home_location(self):
        """讀取儲存的位置並通知 QML"""
        loc = settings_service.get_home_location()
        self.homeLocationLoaded.emit(loc if loc else {})

    @pyqtSlot(str)
    def search_home_location(self, query: str):
        """搜尋地點名稱（Nominatim）並回傳候選座標"""
        threading.Thread(target=lambda: self.homeLocationSearchResults.emit(settings_service.search_home_location(query)), daemon=True).start()

    @pyqtSlot(float, float)
    def action_replace_youbike(self, lat: float = 0.0, lng: float = 0.0):
        """清除已儲存的Youbike站點，加入附近的Youbike站點"""
        def _do():
            nonlocal lat, lng
            if lat == 0.0 and lng == 0.0:
                loc = settings_service.get_home_location()
                if not loc: return
                lat, lng = loc["lat"], loc["lng"]
            
            stations = settings_service._fetch_nearby_youbike(lat, lng)
            if stations:
                settings_service.set_youbike_stations(stations)
                self.fetch_youbike()
                self.load_settings()
        threading.Thread(target=_do, daemon=True).start()

    @pyqtSlot(float, float)
    def action_add_youbike(self, lat: float = 0.0, lng: float = 0.0):
        """加入附近的Youbike站點"""
        def _do():
            nonlocal lat, lng
            if lat == 0.0 and lng == 0.0:
                loc = settings_service.get_home_location()
                if not loc: return
                lat, lng = loc["lat"], loc["lng"]
                
            stations = settings_service._fetch_nearby_youbike(lat, lng)
            if stations:
                existing = settings_service.get_youbike_stations()
                existing_snos = {s["sno"] for s in existing}
                for s in stations:
                    if s["sno"] not in existing_snos:
                        existing.append(s)
                settings_service.set_youbike_stations(existing)
                self.fetch_youbike()
                self.load_settings()
        threading.Thread(target=_do, daemon=True).start()

    @pyqtSlot(float, float, str)
    def action_add_weather(self, lat: float = 0.0, lng: float = 0.0, name: str = ""):
        """加入天氣站點"""
        def _do():
            nonlocal lat, lng, name
            if lat == 0.0 and lng == 0.0:
                loc = settings_service.get_home_location()
                if not loc: return
                lat, lng, name = loc["lat"], loc["lng"], loc["name"]
                
            w_locs = settings_service.get_weather_locations()
            if not any(w["lat"] == lat and w["lon"] == lng for w in w_locs):
                w_locs.append({
                    "name": name,
                    "lat": lat,
                    "lon": lng
                })
                settings_service.set_weather_locations(w_locs)
                self.fetch_weather()
                self.load_settings()
        threading.Thread(target=_do, daemon=True).start()


    @pyqtSlot(int)
    def test_camera(self, idx: int):
        """進入相機預覽模式"""
        self.camera.set_preview_index(idx)
        
    @pyqtSlot()
    def stop_test_camera(self):
        """離開相機預覽模式"""
        self.camera.set_preview_index(None)


def main():
    # 解決 Mac 上預設樣式不允許改變按鈕顏色的問題
    os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"
    
    # 建立應用程式主體
    app = QGuiApplication(sys.argv)
    
    # 初始化資料庫與狀態
    init_db()
    settings_service.init_default_data()
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
    # 通知 QML 目前儲存的位置（供 LocationSetupDialog 判斷是否需要引導設定）
    backend.load_home_location()
    
    # 進入主迴圈，直到視窗關閉
    res = app.exec()
    
    # 關閉時安全結束相機服務
    camera.stop()
    sys.exit(res)

if __name__ == "__main__":
    main()
