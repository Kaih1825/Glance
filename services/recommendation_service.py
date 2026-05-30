"""
services/recommendation_service.py
負責根據使用者的 GPS 位置，推薦附近可借車最多（分數最高）的 YouBike 站點。

評分公式：
  D   = Haversine(user, station) × 1.3   (公尺，含曼哈頓係數)
  S   = min(available_spaces, 5) × 10
  λ   = -0.0011 (涼爽) 或 -0.0035 (大熱/下雨)
  得分 = S × e^(λ × D)
"""
import math
import requests
from services.settings_service import _fetch_all_youbike_stations

_NEARBY_API = "https://apis.youbike.com.tw/tw2/parkingInfo"
_WEATHER_API = "https://api.open-meteo.com/v1/forecast"

# WMO 代碼 ≥ 51 視為下雨；溫度 > 29 視為大熱天
_RAINY_CODES = {51, 53, 55, 61, 63, 65, 71, 73, 75, 77, 80, 81, 82, 85, 86, 95, 96, 99}

_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    ),
    "Origin": "https://www.youbike.com.tw",
    "Referer": "https://www.youbike.com.tw/",
}


def _haversine(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """利用半正矢公式計算兩點間的直線距離（公尺）"""
    R = 6_371_000  # 地球半徑（公尺）
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lng2 - lng1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return 2 * R * math.asin(math.sqrt(a))


def _get_weather_at(lat: float, lng: float) -> tuple[int, float]:
    """
    取得指定座標的當前天氣代碼與氣溫。
    回傳 (wmo_code, temperature_celsius)；若失敗則回傳 (0, 25.0)。
    """
    try:
        resp = requests.get(
            _WEATHER_API,
            params={
                "latitude": lat,
                "longitude": lng,
                "current": "temperature_2m,weathercode",
                "timezone": "Asia/Taipei",
            },
            timeout=5,
        )
        resp.raise_for_status()
        current = resp.json().get("current", {})
        return int(current.get("weathercode", 0)), float(current.get("temperature_2m", 25.0))
    except Exception as e:
        print(f"[recommendation_service] 取得天氣失敗: {e}")
        return 0, 25.0


def _compute_lambda(wmo_code: int, temperature: float) -> float:
    """根據天氣決定 lambda 係數"""
    is_rainy = wmo_code in _RAINY_CODES
    is_hot = temperature > 29.0
    return -0.0035 if (is_rainy or is_hot) else -0.0011


def _score_station(station: dict, user_lat: float, user_lng: float, lam: float) -> float:
    """計算單一站點得分"""
    try:
        s_lat = float(station.get("lat", 0))
        s_lng = float(station.get("lng", 0))
        bikes = int(station.get("available_spaces", 0))
        status = station.get("status", 1)

        if str(status) != "1" and status != 1:  # 站點停用
            return -1.0

        straight_dist = _haversine(user_lat, user_lng, s_lat, s_lng)
        D = straight_dist * 1.3  # 曼哈頓係數
        S = min(bikes, 5) * 10
        return S * math.exp(lam * D)
    except Exception:
        return -1.0


def fetch_recommendation(lat: float, lng: float) -> dict | None:
    """
    取得附近最推薦的 YouBike 站點。

    回傳格式：
    {
        "sno": str,
        "sna": str,
        "sarea": str,
        "bikes": int,       # 可借車輛數
        "yb2": int,
        "eyb": int,
        "bemp": int,
        "distance_m": float,  # 步行距離（公尺，含 1.3 係數）
        "score": float,
        "lambda": float,
        "is_hot_rainy": bool,
        "weather_code": int,
        "temperature": float,
    }
    若無可用站點則回傳 None。
    """
    print("Recommendation")
    # 1. 取得天氣
    wmo_code, temperature = _get_weather_at(lat, lng)
    lam = _compute_lambda(wmo_code, temperature)
    is_hot_rainy = (lam == -0.0035)

    # 2. 取得附近站點（API 需使用 POST 傳遞 form data）
    try:
        resp = requests.post(
            _NEARBY_API,
            data={"lat": lat, "lng": lng, "maxDistance": 2000},
            headers=_HEADERS,
            timeout=8,
        )
        resp.raise_for_status()
        data_res = resp.json()
    except Exception as e:
        print(f"[recommendation_service] 取得附近站點失敗: {e}")
        return None

    # API 回傳格式：{"retCode":1,"retVal":[...]}
    if data_res.get("retCode") != 1:
        return None

    retVal = data_res.get("retVal", [])
    # retVal 可能是 list 或 dict
    if isinstance(retVal, list):
        stations = retVal
    elif isinstance(retVal, dict):
        stations = retVal.get("data", [])
    else:
        stations = []

    # print(stations)
    if not stations:
        return None

    # 3. 計算每站分數
    best = None
    best_score = -1.0

    for st in stations:
        score = _score_station(st, lat, lng, lam)
        if score > best_score:
            best_score = score
            best = st

    if best is None or best_score <= 0:
        return None

    # 4. 反查站名與行政區（API 不回傳站名，需從官方全局站點列表反查）
    sno = str(best.get("station_no", ""))
    sna = sno
    sarea = ""
    try:
        all_stations = _fetch_all_youbike_stations()
        matched = next((s for s in all_stations if str(s.get("station_no", "")) == sno), None)
        if matched:
            sna = matched.get("name_tw", sno)
            sarea = matched.get("district_tw", "")
    except Exception:
        pass

    s_lat = float(best.get("lat", 0))
    s_lng = float(best.get("lng", 0))
    straight_dist = _haversine(lat, lng, s_lat, s_lng)
    walking_dist = straight_dist * 1.3

    detail = best.get("available_spaces_detail", {})

    return {
        "sno": sno,
        "sna": sna,
        "sarea": sarea,
        "bikes": int(best.get("available_spaces", 0)),
        "yb2": int(detail.get("yb2", 0)),
        "eyb": int(detail.get("eyb", 0)),
        "bemp": int(best.get("empty_spaces", 0)),
        "distance_m": round(walking_dist, 1),
        "score": round(best_score, 3),
        "lambda": lam,
        "is_hot_rainy": is_hot_rainy,
        "weather_code": wmo_code,
        "temperature": round(temperature, 1),
    }
