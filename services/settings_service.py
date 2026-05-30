"""
services/settings_service.py
封裝所有設定相關的邏輯，包含讀取天氣、YouBike、相機設定，以及處理搜尋 API。
"""
import os
import json
import requests
import subprocess
import platform
from services.database import get_setting, set_setting

# ── 天氣設定 ──
def get_weather_locations() -> list[dict]:
    return get_setting("weather_locations", [])

def set_weather_locations(locations: list[dict]):
    set_setting("weather_locations", locations)

# ── YouBike 站點快取機制 ──
_CACHE_FILE = os.path.join(os.path.dirname(os.path.dirname(__file__)), "youbike_stations_cache.json")
_cached_youbike_stations = None

def _fetch_all_youbike_stations() -> list:
    global _cached_youbike_stations
    if _cached_youbike_stations:
        return _cached_youbike_stations

    # 1. 嘗試載入磁碟快取
    disk_cache = []
    if os.path.exists(_CACHE_FILE):
        try:
            with open(_CACHE_FILE, "r", encoding="utf-8") as f:
                disk_cache = json.load(f)
        except Exception as e:
            print(f"Error loading YouBike disk cache: {e}")

    # 2. 嘗試從 API 更新資料
    try:
        headers = {
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        }
        resp = requests.get("https://apis.youbike.com.tw/json/station-min-yb2.json", headers=headers, timeout=5).json()
        if isinstance(resp, list) and len(resp) > 0:
            _cached_youbike_stations = resp
            # 同步更新至磁碟快取
            try:
                with open(_CACHE_FILE, "w", encoding="utf-8") as f:
                    json.dump(resp, f, ensure_ascii=False, indent=2)
            except Exception as e:
                print(f"Error saving YouBike disk cache: {e}")
            return _cached_youbike_stations
    except Exception as e:
        print(f"Error fetching YouBike stations from API: {e}. Falling back to cache.")

    # 3. 網路失敗時，若有磁碟快取則使用
    if disk_cache:
        _cached_youbike_stations = disk_cache
        return disk_cache

    return []

# ── YouBike設定 ──
def get_youbike_stations() -> list[dict]:
    return get_setting("youbike_stations", [])

def set_youbike_stations(stations: list[dict]):
    # 儲存完整的站點字典列表，避免後續載入時重複下載與反查官方 JSON
    cleaned = []
    for s in stations:
        if isinstance(s, dict) and s.get("sno"):
            cleaned.append({
                "sno": s.get("sno"),
                "sna": s.get("sna", s.get("sno")),
                "sarea": s.get("sarea", "")
            })
    set_setting("youbike_stations", cleaned)


# ── 攝影機設定 ──
def get_camera_index() -> int:
    return int(get_setting("camera_index", 0))

def set_camera_index(index: int):
    set_setting("camera_index", index)

def get_available_cameras() -> list[str]:
    """回傳匿名的相機列表 (相機 0, 相機 1...)"""
    count = 0
    try:
        from PyQt6.QtMultimedia import QMediaDevices
        count = len(QMediaDevices.videoInputs())
    except Exception:
        pass

    import cv2
    available_cameras = []

    if count == 0:
        # 若 Qt 無法偵測，嘗試使用 OpenCV 實際開啟相機 0 來確認是否存在
        cap = cv2.VideoCapture(0)
        if cap is not None and cap.isOpened():
            count = 1
            cap.release()
    else:
        # 逐一測試每個相機索引
        for i in range(count):
            cap = cv2.VideoCapture(i)
            if cap is not None and cap.isOpened():
                available_cameras.append(i)
                cap.release()
            else:
                # 連續找不到相機時停止搜尋
                if i > 0 and len(available_cameras) == 0:
                    break

    return available_cameras

# ── 搜尋 API ──
def search_weather_location(query: str) -> list[dict]:
    """搜尋城市名稱 (使用 OpenStreetMap Nominatim)"""
    if not query.strip(): return []
    try:
        resp = requests.get(
            "https://nominatim.openstreetmap.org/search",
            params={"q": query, "format": "json", "accept-language": "zh-TW", "limit": 10, "addressdetails": 1},
            headers={"User-Agent": "EntrywaySmartHub/1.0"},
            timeout=5
        ).json()
        
        results = []
        seen_names = set()
        for r in resp:
            addr = r.get("address", {})
            raw_name = r.get("display_name", "")
            # 取出各部分，並過濾掉「臺灣」以節省顯示空間
            parts = [p.strip() for p in raw_name.split(",")]
            parts = [p for p in parts if p not in ("臺灣", "台灣", "Taiwan")]
            full_name = ", ".join(parts) if parts else raw_name
            short_name = parts[0] if parts else raw_name

            country = addr.get("country", "")
            if country in ("臺灣", "台灣", "Taiwan"):
                country = ""
                
            if short_name and short_name not in seen_names:
                seen_names.add(short_name)
                results.append({
                    "name": short_name,
                    "full_name": full_name,
                    "country": country,
                    "lat": float(r.get("lat")),
                    "lon": float(r.get("lon"))
                })
        return results
    except Exception:
        return []

def search_youbike_stations(query: str) -> list[dict]:
    """搜尋 YouBike 站點"""
    if not query.strip(): return []
    try:
        stations = _fetch_all_youbike_stations()
        if not stations:
            return []
        q = query.lower()
        return [
            {
                "sno": s.get("station_no"),
                "sna": s.get("name_tw"),
                "sarea": s.get("district_tw")
            }
            for s in stations if q in s.get("name_tw", "").lower()
        ][:20]
    except Exception:
        return []

# ── 使用者主要位置（GPS 座標）──
def get_home_location() -> dict | None:
    """取得使用者設定的主要位置，回傳 {lat, lng, name} 或 None"""
    from services.database import get_home_location as _db_get
    return _db_get()

def set_home_location(lat: float, lng: float, name: str) -> None:
    """儲存使用者的主要位置"""
    from services.database import set_home_location as _db_set
    _db_set(lat, lng, name)

def search_home_location(query: str) -> list[dict]:
    """搜尋位置以取得 GPS 座標（共用天氣地點搜尋邏輯）"""
    return search_weather_location(query)

def _fetch_nearby_youbike(lat: float, lng: float, limit: int = 6) -> list[dict]:
    try:
        import math
        def _haversine(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
            R = 6_371_000
            phi1, phi2 = math.radians(lat1), math.radians(lat2)
            dphi = math.radians(lat2 - lat1)
            dlambda = math.radians(lng2 - lng1)
            a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
            return 2 * R * math.asin(math.sqrt(a))

        resp = requests.post(
            "https://apis.youbike.com.tw/tw2/parkingInfo",
            data={"lat": lat, "lng": lng, "maxDistance": 1000},
            headers={
                "User-Agent": "Mozilla/5.0",
                "Origin": "https://www.youbike.com.tw",
                "Referer": "https://www.youbike.com.tw/"
            },
            timeout=8,
        )
        resp.raise_for_status()
        data_res = resp.json()

        if data_res.get("retCode") == 1:
            retVal = data_res.get("retVal", [])
            if isinstance(retVal, list):
                stations = retVal
            elif isinstance(retVal, dict):
                stations = retVal.get("data", [])
            else:
                stations = []

            if stations:
                for st in stations:
                    st["_dist"] = _haversine(lat, lng, float(st.get("lat", 0)), float(st.get("lng", 0)))
                
                stations.sort(key=lambda x: x["_dist"])
                top_k = stations[:limit]

                all_stations = _fetch_all_youbike_stations()
                default_yb = []
                for st in top_k:
                    sno = str(st.get("station_no", ""))
                    sna = sno
                    sarea = ""
                    if all_stations:
                        matched = next((s for s in all_stations if str(s.get("station_no", "")) == sno), None)
                        if matched:
                            sna = matched.get("name_tw", sno)
                            sarea = matched.get("district_tw", "")
                    default_yb.append({
                        "sno": sno,
                        "sna": sna,
                        "sarea": sarea
                    })

                return default_yb
    except Exception as e:
        print(f"Error fetching nearby YouBike stations: {e}")
    return []

def init_default_data() -> None:
    """若資料庫沒有天氣與 YouBike 站點，且有設定主要地點，則預設帶入"""
    from services.database import get_setting, set_setting
    if get_setting("has_initialized_defaults", False):
        return

    home_loc = get_home_location()
    if not home_loc:
        return

    # 初始化天氣地點
    w_locs = get_weather_locations()
    if not w_locs:
        set_weather_locations([{
            "name": home_loc["name"],
            "lat": home_loc["lat"],
            "lon": home_loc["lng"]
        }])

    # 初始化 YouBike 站點
    b_locs = get_youbike_stations()
    if not b_locs:
        stations = _fetch_nearby_youbike(home_loc["lat"], home_loc["lng"])
        if stations:
            set_youbike_stations(stations)
    
    set_setting("has_initialized_defaults", True)
