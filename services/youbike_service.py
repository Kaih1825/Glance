"""
services/youbike_service.py
負責抓取 YouBike 2.0 即時站點資訊。
"""
import requests
from services.settings_service import get_youbike_stations

_YOUBIKE_API = "https://apis.youbike.com.tw/tw2/parkingInfo"

def fetch_youbike() -> list[dict]:
    print("SSSS")
    """抓取設定好的 YouBike 站點狀態（包含可借車輛、空位數量，區分 YouBike 2.0 / 2.0e）。"""
    saved = get_youbike_stations()
    
    # 如果資料庫沒有最愛站點，從官方列表抓取前 5 個作為 Demo
    if not saved:
        try:
            resp = requests.get("https://apis.youbike.com.tw/json/station-min-yb2.json", timeout=5).json()
            saved = [
                {
                    "sno": s.get("station_no"),
                    "sna": s.get("name_tw"),
                    "sarea": s.get("district_tw")
                }
                for s in resp[:5]
            ]
        except Exception:
            saved = []

    if not saved:
        return []

    try:
        # 使用 POST 查詢即時狀態
        headers = {
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Origin": "https://www.youbike.com.tw",
            "Referer": "https://www.youbike.com.tw/"
        }
        
        # 建立 station_no[] 串接資料
        payload = [("station_no[]", s["sno"]) for s in saved]
        resp = requests.post(_YOUBIKE_API, data=payload, headers=headers, timeout=8)
        resp.raise_for_status()
        data_res = resp.json()
        
        # 將回傳資料映射成字典方便快速查詢
        status_map = {}
        if data_res.get("retCode") == 1 and "retVal" in data_res:
            for item in data_res["retVal"].get("data", []):
                status_map[item.get("station_no")] = item

        # 整理成 UI 需要的格式
        results = []
        for s in saved:
            sno = s["sno"]
            item = status_map.get(sno, {})
            detail = item.get("available_spaces_detail", {})
            
            results.append({
                "sno": sno,
                "sna": s.get("sna", ""),
                "sarea": s.get("sarea", ""),
                "sbi": int(item.get("available_spaces", 0)), # 總可借車輛數
                "yb2": int(detail.get("yb2", 0)),             # YouBike 2.0 車輛數
                "eyb": int(detail.get("eyb", 0)),             # YouBike 2.0e 電輔車車輛數
                "bemp": int(item.get("empty_spaces", 0)),     # 空車位數
                "tot": int(item.get("parking_spaces", 0)),    # 總車位數
                "act": str(item.get("status", 1)),            # 1 表示正常營運
            })
        return results
        
    except Exception as exc:
        return [{"sna": f"無法取得資料 ({exc})", "sbi": 0, "yb2": 0, "eyb": 0, "bemp": 0, "tot": 0, "act": "0"}]
