#!/usr/bin/env python3
import json
import sys
import urllib.parse
import urllib.request


def run_query(city: str, country: str):
    city = (city or "").strip()
    country = (country or "").strip()
    if not city:
        return []

    query = city if not country else f"{city}, {country}"
    params = {
        "name": query,
        "count": "12",
        "language": "zh",
        "format": "json",
    }
    url = "https://geocoding-api.open-meteo.com/v1/search?" + urllib.parse.urlencode(params)

    req = urllib.request.Request(url, headers={"User-Agent": "quickshell-weather-geocode/1.0"})
    with urllib.request.urlopen(req, timeout=5) as resp:
        payload = resp.read().decode("utf-8", errors="ignore")
    data = json.loads(payload)

    results = []
    for item in data.get("results", []) or []:
        name = (item.get("name") or "").strip()
        admin1 = (item.get("admin1") or "").strip()
        country_name = (item.get("country") or "").strip()
        lat = item.get("latitude")
        lon = item.get("longitude")
        if lat is None or lon is None:
            continue

        parts = [p for p in [name, admin1, country_name] if p]
        label = ", ".join(parts) if parts else name
        results.append(
            {
                "name": name,
                "label": label,
                "country": country_name,
                "admin1": admin1,
                "latitude": float(lat),
                "longitude": float(lon),
            }
        )

    return results


def main():
    city = sys.argv[1] if len(sys.argv) > 1 else ""
    country = sys.argv[2] if len(sys.argv) > 2 else ""
    try:
        print(json.dumps(run_query(city, country), ensure_ascii=False))
    except Exception:
        print("[]")


if __name__ == "__main__":
    main()
