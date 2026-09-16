#!/usr/bin/env python3
"""
Bring each game's package list up to date with the current in-game SKUs.

    python3 scripts/update-catalog.py https://api.hk-game-shop.store admin@example.com 'password'

Additive and idempotent: it only ADDS packages whose SKU is missing, and never
touches a package you already have, so your existing prices are safe.

IMPORTANT - every package added here is created INACTIVE (hidden from the shop)
with an EXAMPLE price. Nothing new appears to customers until you open it in the
admin panel, set your real price (your reseller cost + your margin), and switch
Active on. Prices move with the USD exchange rate, so always price from your
current Smile.one / UniPin cost, not from these examples.
"""
import json
import sys
from urllib import error, request

# Rough example unit prices (MMK per unit) just to prefill the field. REPLACE.
# slug -> list of (sku, name, bonus_text, diamonds_or_price, kind)
#   kind "d" -> price is auto-estimated from the unit rate below (per diamond/UC)
#   kind "flat" -> the number IS the example price (passes / memberships)
RATES = {"mlbb": 72, "magic-chess": 70, "pubg-mobile": 62, "free-fire": 44}

CATALOG = {
    "mlbb": [
        ("MLBB-112",  "112 Diamonds",  "+11 Bonus", 112,   "d"),
        ("MLBB-223",  "223 Diamonds",  "+22 Bonus", 223,   "d"),
        ("MLBB-343",  "343 Diamonds",  "+34 Bonus", 343,   "d"),
        ("MLBB-429",  "429 Diamonds",  "+42 Bonus", 429,   "d"),
        ("MLBB-514",  "514 Diamonds",  "+51 Bonus", 514,   "d"),
        ("MLBB-1412", "1412 Diamonds", "+141 Bonus",1412,  "d"),
        ("MLBB-2195", "2195 Diamonds", "+219 Bonus",2195,  "d"),
        ("MLBB-3688", "3688 Diamonds", "+368 Bonus",3688,  "d"),
        ("MLBB-5532", "5532 Diamonds", "+553 Bonus",5532,  "d"),
        ("MLBB-SVP",  "Super Value Pass", "Monthly value", 12000, "flat"),
        ("MLBB-STAR", "Starlight Member", "Monthly",       33000, "flat"),
        ("MLBB-STARP","Starlight Member Plus", "Monthly",  66000, "flat"),
    ],
    "pubg-mobile": [
        ("PUBG-985",  "985 UC",  "+110 Bonus", 985,  "d"),
        ("PUBG-1320", "1320 UC", "+140 Bonus", 1320, "d"),
        ("PUBG-2460", "2460 UC", "+460 Bonus", 2460, "d"),
        ("PUBG-6480", "6480 UC", "+680 Bonus", 6480, "d"),
    ],
    "free-fire": [
        ("FF-210",   "210 Diamonds",  "+10 Bonus", 210,  "d"),
        ("FF-2200",  "2200 Diamonds", "+200 Bonus",2200, "d"),
        ("FF-5600",  "5600 Diamonds", "+600 Bonus",5600, "d"),
        ("FF-MONTHLY","Monthly Membership", "30 days", 25000, "flat"),
        ("FF-LEVELUP","Level Up Pass",      "Season",  9000,  "flat"),
    ],
    "magic-chess": [
        ("MCGG-250", "250 Diamonds", "+25 Bonus", 250, "d"),
        ("MCGG-500", "500 Diamonds", "+50 Bonus", 500, "d"),
        ("MCGG-TWL", "Twilight Pass","Limited",   38000,"flat"),
    ],
}


class Api:
    def __init__(self, base):
        self.base = base.rstrip("/") + "/api/v1"
        self.token = None

    def call(self, method, path, body=None):
        data = None if body is None else json.dumps(body).encode()
        req = request.Request(self.base + path, data=data, method=method)
        req.add_header("Accept", "application/json")
        if data is not None:
            req.add_header("Content-Type", "application/json")
        if self.token:
            req.add_header("Authorization", f"Bearer {self.token}")
        try:
            with request.urlopen(req, timeout=60) as resp:
                raw = resp.read()
                return json.loads(raw) if raw else None
        except error.HTTPError as e:
            raise SystemExit(f"{method} {path} failed: {e.code} {e.read().decode()[:300]}")


def price_for(slug, number, kind):
    if kind == "flat":
        return number
    rate = RATES.get(slug, 70)
    return int(round(number * rate / 500.0)) * 500  # round to nearest 500


def main():
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    api = Api(sys.argv[1])
    api.token = api.call("POST", "/auth/login",
                         {"email": sys.argv[2], "password": sys.argv[3]})["accessToken"]
    print("signed in")

    products = {p["slug"]: p for p in api.call("GET", "/admin/products?size=100")["items"]}
    added = 0
    for slug, packs in CATALOG.items():
        p = products.get(slug)
        if not p:
            print(f"  skip {slug}: not in catalog")
            continue
        detail = api.call("GET", f"/admin/products/{p['id']}")
        have = {v["sku"] for v in detail.get("variants", [])}
        base_sort = max((v.get("sortOrder", 0) for v in detail.get("variants", [])), default=0)
        for i, (sku, name, bonus, number, kind) in enumerate(packs, start=1):
            if sku in have:
                continue
            price = price_for(slug, number, kind)
            api.call("POST", f"/admin/products/{p['id']}/variants", {
                "sku": sku, "name": name, "nameMy": name, "bonusText": bonus,
                "price": price, "compareAtPrice": None,
                "costPrice": int(price * 0.85),
                "stockType": "UNLIMITED", "lowStockThreshold": 5, "maxPerOrder": 10,
                "popularity": 50, "sortOrder": base_sort + i,
                "active": False,   # hidden until staff set a real price and enable it
            })
            print(f"  {slug}: + {sku}  ({name}) example {price:,} MMK [INACTIVE]")
            added += 1
    print(f"done - {added} package(s) added, all inactive. "
          f"Set real prices and switch them Active in the admin panel.")


if __name__ == "__main__":
    main()
