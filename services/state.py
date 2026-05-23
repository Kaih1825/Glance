"""
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
    preview_frame = pyqtSignal(str)        # 傳遞預覽畫面給 UI (base64)

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
        new_users = users or []
        if self.mode == mode and self.identified_users == new_users:
            return
        self.mode = mode
        self.identified_users = new_users
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
