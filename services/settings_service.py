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
    data = get_setting("youbike_stations", [])[:2]
    if not data:
        return []
    
    # 兼容舊格式：如果存的是完整的字典列表，直接回傳
    if isinstance(data[0], dict):
        return data
        
    # 如果是新格式（只存 ID 列表），向官方站點清單 API 查詢完整資訊
    try:
        resp = requests.get("https://apis.youbike.com.tw/json/station-min-yb2.json", timeout=5).json()
        stations_map = {
            s.get("station_no"): {
                "sno": s.get("station_no"),
                "sna": s.get("name_tw"),
                "sarea": s.get("district_tw")
            }
            for s in resp
        }
        return [stations_map[sno] for sno in data if sno in stations_map]
    except Exception:
        # 發生錯誤時的降級處理，至少保留 sno 資訊
        return [{"sno": sno, "sna": sno, "sarea": ""} for sno in data]

def set_youbike_stations(stations: list[dict]):
    # 只儲存站點 ID (sno)
    sno_list = [s.get("sno") for s in stations if s.get("sno")]
    set_setting("youbike_stations", sno_list[:2])

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
            city_or_county = addr.get("city") or addr.get("county") or addr.get("state") or ""
            district = addr.get("suburb") or addr.get("town") or addr.get("village") or addr.get("city_district") or addr.get("district") or ""
            
            # 建立乾淨的名稱
            if city_or_county and district:
                if district in city_or_county:
                    name = city_or_county
                elif city_or_county in district:
                    name = district
                else:
                    name = f"{city_or_county}{district}"
            else:
                name = city_or_county or district or r.get("display_name").split(",")[0]
            
            # 若非台灣地區則標記國家
            country = addr.get("country", "")
            if country and country != "臺灣":
                name = f"{name} ({country})"
                
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
        stations = requests.get("https://apis.youbike.com.tw/json/station-min-yb2.json", timeout=5).json()
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
