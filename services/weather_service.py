"""
services/weather_service.py
負責向 Open-Meteo API 抓取目前天氣資訊。
"""
import requests
from services.settings_service import get_weather_locations

_WEATHER_API = "https://api.open-meteo.com/v1/forecast"

# 簡單的 WMO 天氣代碼對應表 (Icon Codepoint, 中文描述, 顏色)
_WMO_MAP = {
    0: ("\ue430", "晴天", "#FFB74D"),       # wb_sunny
    1: ("\ue42d", "大致晴朗", "#B0BEC5"), # wb_cloudy
    2: ("\ue2c2", "多雲", "#90A4AE"),       # cloud
    3: ("\ue2c2", "陰天", "#78909C"),       # cloud
    45: ("\ue2c2", "起霧", "#B0BEC5"),      # fog / cloud
    51: ("\ue3e5", "毛毛雨", "#4FC3F7"),    # grain
    61: ("\ue3e5", "小雨", "#29B6F6"),       # grain
    63: ("\ue3e5", "中雨", "#039BE5"),       # grain
    65: ("\ue3e5", "大雨", "#0288D1"),       # grain
    80: ("\ue3e5", "陣雨", "#29B6F6"),       # grain
    95: ("\ue3e7", "雷雨", "#BA68C8")        # flash_on / thunderstorm
}

# 預設地點（當使用者沒有設定時使用）
_DEFAULT_LOCATIONS = [{"name": "臺北", "lat": 25.04, "lon": 121.51, "country": "台灣"}]

def fetch_weather() -> list[dict]:
    """抓取設定地點的天氣，回傳包含溫度、濕度、風速等資訊的字典列表。"""
    print("Weather")
    locations = get_weather_locations() or _DEFAULT_LOCATIONS
    results = []
    
    for loc in locations: # 抓取所有設定的地點
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
            icon, condition, color = _WMO_MAP.get(code, ("\ue8e3", "未知", "#E57373"))
            
            results.append({
                "name": loc["name"],
                "temp": round(data.get("temperature_2m", 0), 1),
                "feels_like": round(data.get("apparent_temperature", 0), 1),
                "icon": icon,
                "iconColor": color,
                "condition": condition,
                "humidity": int(data.get("relativehumidity_2m", 0)),
                "wind_speed": round(data.get("windspeed_10m", 0), 1),
            })
        except Exception as e:
            print(e)
            # 發生錯誤時給予預設佔位內容
            results.append({
                "name": loc.get("name", "未知地點"),
                "temp": "--", "feels_like": "--",
                "icon": "\ue887", "iconColor": "#E57373", "condition": "無法取得資料",
                "humidity": "--", "wind_speed": "--",
            })
            
    return results
