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
    previewFrame = pyqtSignal(str)                   # 攝影機預覽畫面

    def __init__(self, state: AppState, camera: CameraService):
        super().__init__()
        self.state = state
        self.camera = camera
        self._demo_active = False
        
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

    @pyqtSlot(str, str, str, str, str)
    def add_event(self, title: str, start_dt: str, end_dt: str, visibility: str, owner_id: str):
        """從 UI 新增行事曆事件"""
        owner = owner_id if (owner_id and owner_id != "None" and owner_id != "") else None
        success = database.add_event(title, start_dt, end_dt, visibility, owner)
        if success:
            self.fetch_calendar(self.state.identified_users)

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
        def _do(): self.weatherSearchResults.emit(settings_service.search_weather_location(query))
        threading.Thread(target=_do, daemon=True).start()

    @pyqtSlot(str)
    def search_youbike(self, query: str):
        def _do(): self.youbikeSearchResults.emit(settings_service.search_youbike_stations(query))
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
