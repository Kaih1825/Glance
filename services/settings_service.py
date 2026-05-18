"""
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
