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

def get_default_youbike_stations() -> list[dict]:
    """取得預設的 YouBike 站點 (Demo 用，取前5個)"""
    stations = _fetch_all_youbike_stations()
    if not stations:
        return []
    return [
        {
            "sno": s.get("station_no"),
            "sna": s.get("name_tw"),
            "sarea": s.get("district_tw")
        }
        for s in stations[:5]
    ]

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

    if count == 0:
        count = 5
    return [f"相機 {i}" for i in range(count)]

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
            parts = [p for p in parts if p not in ("臺灣", "Taiwan")]
            name = ", ".join(parts) if parts else raw_name
                
            if name and name not in seen_names:
                seen_names.add(name)
                results.append({
                    "name": name,
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
