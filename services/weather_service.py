"""
services/weather_service.py
負責向 Open-Meteo API 抓取目前天氣資訊。
"""
import requests
from services.settings_service import get_weather_locations

_WEATHER_API = "https://api.open-meteo.com/v1/forecast"

# 簡單的 WMO 天氣代碼對應表 (Icon Codepoint, 中文描述, 顏色)
_WMO_MAP = {
    0: ("\ue81a", "晴天", "#FFB74D"),       # sunny
    1: ("\ue42d", "大致晴朗", "#B0BEC5"),   # wb_cloudy
    2: ("\ue2bd", "多雲", "#90A4AE"),       # cloud
    3: ("\ue2bd", "陰天", "#78909C"),       # cloud
    45: ("\ue818", "起霧", "#B0BEC5"),      # foggy
    48: ("\ue818", "霧淞", "#B0BEC5"),      # foggy
    51: ("\ue3ea", "微毛毛雨", "#4FC3F7"),  # grain
    53: ("\ue3ea", "毛毛雨", "#4FC3F7"),    # grain
    55: ("\ue3ea", "大毛毛雨", "#4FC3F7"),  # grain
    56: ("\ueb3b", "微凍毛毛雨", "#81D4FA"),# ac_unit
    57: ("\ueb3b", "大凍毛毛雨", "#81D4FA"),# ac_unit
    61: ("\ue798", "小雨", "#29B6F6"),      # water_drop
    63: ("\ue798", "中雨", "#039BE5"),      # water_drop
    65: ("\ue798", "大雨", "#0288D1"),      # water_drop
    66: ("\ueb3b", "微凍雨", "#4DD0E1"),    # ac_unit
    67: ("\ueb3b", "大凍雨", "#00BCD4"),    # ac_unit
    71: ("\ue80f", "小雪", "#E0F7FA"),      # snowing
    73: ("\ue80f", "中雪", "#B2EBF2"),      # snowing
    75: ("\ue80f", "大雪", "#80DEEA"),      # snowing
    77: ("\ue80f", "雪粒", "#4DD0E1"),      # snowing
    80: ("\ue798", "微陣雨", "#29B6F6"),    # water_drop
    81: ("\ue798", "陣雨", "#039BE5"),      # water_drop
    82: ("\ue798", "強陣雨", "#0288D1"),    # water_drop
    85: ("\ue80f", "微陣雪", "#B2EBF2"),    # snowing
    86: ("\ue80f", "強陣雪", "#80DEEA"),    # snowing
    95: ("\uebdb", "雷雨", "#BA68C8"),      # thunderstorm
    96: ("\uebdb", "雷雨伴冰雹", "#9C27B0"), # thunderstorm
    99: ("\uebdb", "強雷雨伴冰雹", "#7B1FA2")# thunderstorm
}
def fetch_weather() -> list[dict]:
    """抓取設定地點的天氣，回傳包含溫度、濕度、風速等資訊的字典列表。"""
    print("Weather")
    locations = get_weather_locations()
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

            print(resp.url)
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
