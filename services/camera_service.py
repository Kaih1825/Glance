"""
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
_NO_FACE_TIMEOUT = 8.0   # 多久沒看到人臉就將 UI 切回閒置模式
_LOOP_INTERVAL = 0.6     # 迴圈間隔 (節省 CPU 資源)

class CameraService:
    def __init__(self, state: AppState):
        self._state = state
        self._stop_event = threading.Event()
        self._thread = threading.Thread(target=self._loop, daemon=True)
        self._cascade = cv2.CascadeClassifier(_CASCADE_PATH) # opencv 的人臉偵測器
        self._cap = None  # Camera Instance
        self._last_face_time = 0.0
        self._needs_reconnect = False
        self._preview_idx: int | None = None

    def start(self):
        """啟動攝影機背景服務"""
        os.makedirs(FACE_DB_DIR, exist_ok=True)
        self._thread.start()

    def stop(self):
        """停止攝影機背景服務"""
        self._stop_event.set()
        
    def reconnect_camera(self):
        """通知攝影機重新連線（通常是切換相機時呼叫）"""
        self._needs_reconnect = True
        
    def set_preview_index(self, idx: int | None):
        """進入或離開預覽模式，並切換相機"""
        self._preview_idx = idx
        self._needs_reconnect = True

    def _loop(self):
        """主要的攝影機執行迴圈"""
        from services.settings_service import get_camera_index
        
        # 檢查是否需要下載模型 (第一次啟動)
        weights_dir = os.path.join(os.path.expanduser("~"), ".deepface", "weights")
        has_arcface = os.path.exists(os.path.join(weights_dir, "arcface_weights.h5"))
        has_retinaface = os.path.exists(os.path.join(weights_dir, "retinaface.h5"))
        if not has_arcface or not has_retinaface:
            self._state.model_download_started.emit()
            try:
                from deepface import DeepFace
                # 下載人臉特徵比對模型 (ArcFace)
                DeepFace.build_model("ArcFace")
                
                # 下載人臉偵測模型 (retinaface)
                # 最穩妥的做法是餵給它一張黑圖，強制它載入/下載偵測器
                import numpy as np
                dummy_img = np.zeros((224, 224, 3), dtype=np.uint8)
                DeepFace.extract_faces(img_path=dummy_img, detector_backend="retinaface", enforce_detection=False)
            except Exception as e:
                logger.error(f"Download model error: {e}")
            self._state.model_download_done.emit()
        
        # 開啟攝影機
        self._cap = cv2.VideoCapture(get_camera_index())

        try:
            while not self._stop_event.is_set():
                # ── 逾時檢查 (閒置切換) ──
                # 確保不論鏡頭是否故障，只要一段時間沒抓到人臉就關閉面板
                if self._preview_idx is None and self._state.mode != "idle":
                    if self._last_face_time == 0.0 or time.monotonic() - self._last_face_time >= _NO_FACE_TIMEOUT:
                        self._last_face_time = 0.0
                        self._state.set_mode("idle")

                # 處理切換相機請求
                if self._needs_reconnect:
                    self._needs_reconnect = False
                    if self._cap:
                        self._cap.release()
                    target_idx = self._preview_idx if self._preview_idx is not None else get_camera_index()
                    self._cap = cv2.VideoCapture(target_idx)
                    self._cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
                    self._cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
                    actual_w = self._cap.get(cv2.CAP_PROP_FRAME_WIDTH)
                    actual_h = self._cap.get(cv2.CAP_PROP_FRAME_HEIGHT)
                    logger.info(f"Camera #{target_idx} opened — negotiated resolution: {actual_w:.0f}x{actual_h:.0f}")
                    self._last_face_time = 0.0 # 切換相機後重設時間戳記，讓狀態重新計算
                    
                if not self._cap or not self._cap.isOpened():
                    # 找不到攝影機就休息一下 (避免無窮迴圈吃CPU)，並每 5 秒嘗試重新連線一次
                    time.sleep(1.0)
                    if time.monotonic() - getattr(self, '_last_retry_time', 0) > 5.0:
                        self._last_retry_time = time.monotonic()
                        if self._cap:
                            self._cap.release()
                        target_idx = self._preview_idx if self._preview_idx is not None else get_camera_index()
                        self._cap = cv2.VideoCapture(target_idx)
                    continue

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
                    
                # ── 預覽模式 ──
                if self._preview_idx is not None:
                    import base64
                    target_w = 320
                    target_h = int(target_w * actual_h / actual_w)
                    small = cv2.resize(frame, (target_w, target_h))
                    _, buffer = cv2.imencode('.jpg', small, [cv2.IMWRITE_JPEG_QUALITY, 50])
                    b64 = base64.b64encode(buffer).decode('utf-8')
                    self._state.preview_frame.emit("data:image/jpeg;base64," + b64)
                    time.sleep(0.03) # 約 30 FPS
                    continue

                # 階段一：使用快速的 OpenCV 偵測是否有人臉
                # 放寬條件：降低 minNeighbors 和 minSize，避免光線稍微不好時直接把畫面丟棄
                gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
                faces = self._cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=3, minSize=(40, 40))

                if len(faces) == 0:
                    time.sleep(_LOOP_INTERVAL)
                    continue

                # 階段二：使用較耗資源的 DeepFace 進行「辨識」是誰
                users = self._run_deepface(frame)
                
                # 如果 users 是 False，代表 DeepFace 發現這其實不是人臉（OpenCV 誤判）
                if users is False:
                    time.sleep(_LOOP_INTERVAL)
                    continue
                
                # 辨識完成後，更新時間戳記（避免比對耗時導致逾時計算錯誤）
                self._last_face_time = time.monotonic()
                
                if users:
                    self._state.set_mode("users", users)
                else:
                    self._state.set_mode("guest")

                time.sleep(_LOOP_INTERVAL)
        finally:
            if self._cap:
                self._cap.release()

    def _run_deepface(self, frame: np.ndarray) -> list[str] | None | bool:
        """透過 DeepFace 比對資料庫，回傳辨識出的人名列表。回傳 False 代表找不到人臉（OpenCV 誤判）。"""
        # 如果資料庫是空的，我們還是可以用 extract_faces 驗證一下是不是真的有人臉
        try:
            from deepface import DeepFace
            if not [d for d in os.listdir(FACE_DB_DIR) if os.path.isdir(os.path.join(FACE_DB_DIR, d))]:
                # 資料庫為空，只驗證是否有人臉
                DeepFace.extract_faces(img_path=frame, detector_backend="retinaface", enforce_detection=False)
                return None
            
            # 進行人臉比對
            results = DeepFace.find(
                img_path=frame, db_path=FACE_DB_DIR,
                model_name="ArcFace", detector_backend="retinaface",
                anti_spoofing=False, enforce_detection=False, silent=True
            )

            from services import database
            user_ids = [os.path.relpath(df.iloc[0]["identity"], FACE_DB_DIR).split(os.sep)[0] for df in results if not df.empty]
            user_ids = list(dict.fromkeys(user_ids)) # deduplicate
            
            # 將辨識出的 UUID 列表轉換為使用者名稱列表
            user_names = database.get_user_names(user_ids)
            return user_names if user_names else None
        except ValueError as e:
            if "Face could not be detected" in str(e) or "could not be detected" in str(e) or "could not find any face" in str(e).lower():
                return False
            logger.exception("DeepFace ValueError: %s", e)
            return None
        except Exception as e:
            logger.exception("DeepFace find 發生異常: %s", e)
            return None

    def _handle_register(self, user_id: str):
        """處理註冊請求：拍照存檔並強制 DeepFace 重新建立特徵庫"""
        self._state.rebuild_started.emit() # 通知 UI 顯示載入轉圈圈
        
        from services import database
        import uuid
        
        # 取得或為新使用者生成 UUID 
        user_uuid = database.get_user_uuid(user_id)
        if not user_uuid:
            user_uuid = str(uuid.uuid4())
            database.add_user(user_uuid, user_id)
            logger.info(f"為新人員建立 UUID 對應: {user_id} -> {user_uuid}")
        
        # 給使用者一點時間抬頭看鏡頭，避免拍到按滑鼠時的低頭/模糊畫面
        time.sleep(1.5)
        # 清空 OpenCV 的影像暫存區 (buffer 裡通常有幾張舊的 frame)
        for _ in range(5):
            self._cap.read()
            
        ret, frame = self._cap.read()
        if ret:
            # 1. 建立資料夾並儲存照片
            user_dir = os.path.join(FACE_DB_DIR, user_uuid)
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
