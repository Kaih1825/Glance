"""
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
