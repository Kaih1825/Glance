"""
services/youbike_service.py
負責抓取 YouBike 2.0 即時站點資訊。
"""
import requests
from services.settings_service import get_youbike_stations

_YOUBIKE_API = "https://tcgbusfs.blob.core.windows.net/dotapp/youbike/v2/youbike_immediate.json"

def fetch_youbike() -> list[dict]:
    """抓取設定好的 YouBike 站點狀態（包含可借車輛、空位數量）。"""
    saved = get_youbike_stations()
    try:
        resp = requests.get(_YOUBIKE_API, timeout=8)
        resp.raise_for_status()
        all_stations = resp.json()

        if saved:
            # 過濾出使用者設定的站點
            saved_snos = {s["sno"] for s in saved}
            filtered = [s for s in all_stations if s.get("sno") in saved_snos]
        else:
            # 如果沒有設定，隨機(按名稱排序)取前 5 個作為 Demo
            filtered = sorted(all_stations, key=lambda s: s.get("sna", ""))[:5]

        # 整理成 UI 需要的格式
        return [{
            "sno": s.get("sno", ""),
            "sna": s.get("sna", ""),
            "sarea": s.get("sarea", ""),
            "sbi": int(s.get("sbi", 0)),    # 可借車輛數
            "bemp": int(s.get("bemp", 0)),  # 空車位數
            "tot": int(s.get("tot", 0)),    # 總車位數
            "act": s.get("act", "1"),       # 1 表示正常營運
        } for s in filtered]
        
    except Exception as exc:
        return [{"sna": f"無法取得資料 ({exc})", "sbi": 0, "bemp": 0, "tot": 0, "act": "0"}]
