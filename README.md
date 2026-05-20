# 玄關智慧中樞 — 系統架構與流程圖手冊

本文件記錄了「玄關智慧中樞」專案中，各個元件（QML 介面、Backend 橋樑、AppState 狀態管理、Camera 背景服務）之間的互動關係、呼叫函式（Functions）與傳遞訊號（Signals）。

---

```
bd/ (專案根目錄)
├── main.py                          # 🚀 程式啟動進入點（連接 Python 後端與 QML 前端）
├── README.md                        # 📝 系統架構與流程圖手冊（內含運作時序與流程圖）
├── entryway.db                      # 🗄️ SQLite 資料庫檔案（儲存行事曆與系統設定）
├── pyproject.toml / uv.lock         # 📦 Python 專案套件依賴與鎖定檔
├── face_db/                         # 👤 註冊的人臉相片資料夾（依人名分類儲存）
│
├── services/                        # ⚙️ 後端服務模組 (Backend Services)
│   ├── state.py                     #     └─ AppState：全域狀態與執行緒同步鎖管理
│   ├── camera_service.py            #     └─ 背景 OpenCV 擷取影像與 DeepFace 人臉辨識
│   ├── database.py                  #     └─ SQLite 資料庫讀寫（行事曆事件與 Visibility 過濾）
│   ├── weather_service.py           #     └─ 非同步抓取 Open-Meteo 天氣 API
│   ├── youbike_service.py           #     └─ 非同步抓取台北市 YouBike 即時車位 API
│   └── settings_service.py          #     └─ 設定管理、OSM 城市搜尋與 YouBike 站點搜尋
│
└── qml/                             # 🎨 前端使用者介面 (Frontend QML)
    ├── main.qml                     #     └─ 主視窗與面板展開/縮放動畫控制器
    ├── LeftPanel.qml                #     └─ 左側常駐面板（時間與天氣）
    ├── RightPanel.qml               #     └─ 右側彈出面板（個人化行事曆與 YouBike）
    ├── ClockWidget.qml              #     └─ 時間/日期小工具
    ├── WeatherWidget.qml            #     └─ 天氣小工具
    ├── CalendarWidget.qml           #     └─ 行事曆清單小工具
    ├── YouBikeWidget.qml            #     └─ YouBike 站點狀態小工具
    ├── SettingsDialog.qml           #     └─ 系統設定彈出視窗
    └── RegisterDialog.qml           #     └─ 人員註冊拍照彈出視窗

```

## 1. 系統啟動與初始化流程 (System Startup)

### 📊 Mermaid 時序圖
```mermaid
sequenceDiagram
    participant Main as main.py (主執行緒)
    participant DB as SQLite 資料庫
    participant Camera as CameraService (背景執行緒)
    participant QML as QML Engine (前端介面)
    
    Main->>Main: 1. 設定 UI Basic 按鈕樣式 (Mac 相容)
    Main->>DB: 2. init_db() (建立表格、寫入假行事曆資料)
    Main->>Camera: 3. 啟動背景相機掃描執行緒 (camera.start())
    Main->>Main: 4. 建立 Backend 橋樑 (連結 state 與 camera)
    Main->>QML: 5. 註冊 "backend" 物件至 QML 全域內容
    Main->>QML: 6. 載入 main.qml 畫面並顯示視窗
    Main->>Main: 7. 主動抓取一次天氣 (fetch_weather)
    Main->>Main: 8. 進入 Qt 主事件迴圈 (app.exec())
```



## 2. 人臉偵測、辨識與介面更新流程 (Face Detection & UI Update)

### 📊 Mermaid 流程圖
```mermaid
flowchart TD
    Start([1. 背景迴圈開始]) --> TimeoutCheck{2. 是否大於 5 秒沒看到人臉?}
    TimeoutCheck -- YES (人離開了) --> SetIdle[3. 將狀態設為 idle ➔ QML 收起右面板] --> ReadFrame[4. 讀取相機影像]
    TimeoutCheck -- NO (人還在或剛開始) --> ReadFrame
    
    ReadFrame --> CheckPreview{5. 是否正在進行相機測試?}
    CheckPreview -- YES --> SendBase64[6. 影像等比例縮小並轉為 Base64 傳給 QML 預覽] --> SleepPreview[休息 0.1秒] --> Start
    CheckPreview -- NO --> OpenCVFace{7. OpenCV 快速偵測: 畫面有人臉嗎?}
    
    OpenCVFace -- NO (沒人) --> SleepIdle[休息 0.6秒] --> Start
    OpenCVFace -- YES (有人) --> UpdateTime[8. 更新最後看到人臉的時間] --> DeepFace{9. 執行 DeepFace 深度學習人臉比對}
    
    DeepFace -- 比對成功 (熟人) --> SetUsers[10. 將狀態設為 users ➔ QML 展開並顯示個人行事曆] --> SleepNormal[休息 0.6秒] --> Start
    DeepFace -- 比對失敗 (訪客) --> SetGuest[11. 將狀態設為 guest ➔ QML 展開並顯示訪客歡迎語] --> SleepNormal --> Start
```

## 3. 新人員註冊流程 (User Registration)

### 📊 Mermaid 時序圖
```mermaid
sequenceDiagram
    actor User as 使用者
    participant QML as 註冊對話框 (QML)
    participant Backend as Backend (main.py)
    participant State as AppState (state.py)
    participant Camera as CameraService (背景)
    
    User->>QML: 1. 輸入名字 (如 "kai") 並按下確認
    QML->>Backend: 2. 呼叫 register_user("kai")
    Backend->>State: 3. 呼叫 start_register("kai")
    Note over State: 4. 安全鎖定 (Lock)<br/>寫入註冊標記：(True, "kai")<br/>釋放鎖 (Unlock)
    
    loop 每 0.6 秒檢查一次
        Camera->>State: 5. 呼叫 consume_register_flag()
        Note over State: 6. 安全鎖定 (Lock)<br/>取出標記，並清空回 (False, "")<br/>釋放鎖 (Unlock)
        State-->>Camera: 回傳 (True, "kai")
    end
    
    Camera->>Camera: 7. 拍下當前的畫面 (frame)
    Camera->>Camera: 8. 建立資料夾並儲存照片：face_db/kai/photo.jpg
    Camera->>State: 9. 發送 rebuild_started 訊號 (UI 開始顯示轉圈圈)
    Camera->>Camera: 10. 刪除快取並調用 DeepFace.find 讓模型重新學習
    Camera->>State: 11. 發送 rebuild_done 訊號
    State-->>QML: 12. 關閉對話框，停止轉圈圈
```

## 4. 資料非同步抓取流程 (Async Weather & YouBike Fetch)

### 📊 Mermaid 時序圖
```mermaid
sequenceDiagram
    participant UI as 前端介面 (QML)
    participant Backend as Backend (main.py)
    participant Thread as 獨立背景執行緒
    participant API as 外部 API (伺服器)
    
    UI->>Backend: 1. 呼叫 fetch_weather() / fetch_youbike()
    Backend->>Thread: 2. 創建並啟動背景執行緒 (Thread)
    activate Thread
    Thread->>API: 3. 透過網路發送 API 請求 (設定 5~8秒逾時)
    API-->>Thread: 4. 回傳 JSON 原始資料
    Note over Thread: 5. 解析資料格式<br/>(若網路斷線，會給予 "--" 安全佔位符)
    Thread->>Backend: 6. 發射 weatherUpdated / youbikeUpdated 訊號 (傳入乾淨資料)
    deactivate Thread
    Backend-->>UI: 7. UI 接收訊號，自動重新整理清單表格
```
