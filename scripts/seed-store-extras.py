#!/usr/bin/env python3
"""
Round out the storefront with more gift cards, vouchers and premium apps.

    python3 scripts/seed-store-extras.py https://api.hk-game-shop.store admin@example.com 'password'

Idempotent and additive: a product whose slug already exists is skipped.
Everything is created INACTIVE with EXAMPLE prices, so nothing reaches the shop
until you set a real price and switch it Active in the admin panel.

Delivery model per product:
  - CODE_DELIVERY + CODE_POOL variants  -> instant, once you upload codes
    (buy the codes from Razer/UniPin/Moogold and paste them under Stock).
  - MANUAL + UNLIMITED variants          -> your team delivers the account.
"""
import json
import sys
from urllib import error, request

# (slug, name, nameMy, category, fulfillment, description, [(sku,name,priceMMK), ...])
CODE = "CODE_DELIVERY"
MAN = "MANUAL"

PRODUCTS = [
    # ---- Gift cards (instant code pool) ----
    ("razer-gold", "Razer Gold PIN", "Razer Gold", "gift-cards", CODE,
     "Razer Gold PIN codes, delivered instantly.",
     [("RAZER-10", "Razer Gold $10", 52000), ("RAZER-20", "Razer Gold $20", 103000),
      ("RAZER-50", "Razer Gold $50", 255000)]),
    ("apple-itunes", "App Store & iTunes Gift Card", "App Store & iTunes", "gift-cards", CODE,
     "Apple App Store & iTunes gift codes.",
     [("ITUNES-10", "iTunes $10", 52000), ("ITUNES-25", "iTunes $25", 128000),
      ("ITUNES-50", "iTunes $50", 255000)]),
    ("playstation", "PlayStation Store Card", "PlayStation Store", "gift-cards", CODE,
     "PlayStation Network wallet codes.",
     [("PSN-10", "PSN $10", 52000), ("PSN-25", "PSN $25", 128000),
      ("PSN-50", "PSN $50", 255000)]),
    # ---- Vouchers (instant code pool) ----
    ("garena-shells", "Garena Shells", "Garena Shells", "vouchers", CODE,
     "Garena Shells for Free Fire and other Garena games.",
     [("GARENA-110", "110 Shells", 8000), ("GARENA-330", "330 Shells", 22000),
      ("GARENA-660", "660 Shells", 43000)]),
    ("unipin-voucher", "UniPin Voucher", "UniPin Voucher", "vouchers", CODE,
     "UniPin credits usable across many games.",
     [("UNIPIN-50", "UniPin 50 Credits", 5000), ("UNIPIN-100", "UniPin 100 Credits", 9500),
      ("UNIPIN-300", "UniPin 300 Credits", 28000)]),
    # ---- Premium apps (account, manual) ----
    ("youtube-premium", "YouTube Premium", "YouTube Premium", "premium-apps", MAN,
     "YouTube Premium upgrade for your own account.",
     [("YT-1M", "1 Month", 9000), ("YT-3M", "3 Months", 25000), ("YT-6M", "6 Months", 47000)]),
    ("disney-plus", "Disney+ Premium", "Disney+ Premium", "premium-apps", MAN,
     "Disney+ Premium plans.",
     [("DISNEY-1M", "1 Month", 15000), ("DISNEY-3M", "3 Months", 41000)]),
    ("canva-pro", "Canva Pro", "Canva Pro", "premium-apps", MAN,
     "Canva Pro for your own account.",
     [("CANVA-1M", "1 Month", 12000), ("CANVA-1Y", "1 Year", 95000)]),
    ("amazon-prime", "Amazon Prime Video", "Amazon Prime Video", "premium-apps", MAN,
     "Amazon Prime Video subscription.",
     [("PRIME-1M", "1 Month", 14000), ("PRIME-3M", "3 Months", 38000)]),
]


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


def main():
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    api = Api(sys.argv[1])
    api.token = api.call("POST", "/auth/login",
                         {"email": sys.argv[2], "password": sys.argv[3]})["accessToken"]
    print("signed in")

    cats = {c["slug"]: c["id"] for c in api.call("GET", "/admin/categories")}
    have = {p["slug"] for p in api.call("GET", "/admin/products?size=200")["items"]}
    added = 0

    for slug, name, nameMy, cat, fulfil, desc, variants in PRODUCTS:
        if slug in have:
            print(f"  {slug}: already exists")
            continue
        if cat not in cats:
            print(f"  skip {slug}: category {cat} missing")
            continue
        product = api.call("POST", "/admin/products", {
            "categoryId": cats[cat], "slug": slug, "name": name, "nameMy": nameMy,
            "description": desc, "fulfillmentType": fulfil,
            "featured": False, "sortOrder": 50, "active": False, "fields": [],
        })
        stock = "CODE_POOL" if fulfil == CODE else "UNLIMITED"
        for i, (sku, vname, price) in enumerate(variants, start=1):
            api.call("POST", f"/admin/products/{product['id']}/variants", {
                "sku": sku, "name": vname, "nameMy": vname, "price": price,
                "costPrice": int(price * 0.9), "stockType": stock,
                "lowStockThreshold": 5, "maxPerOrder": 10, "popularity": 40,
                "sortOrder": i, "active": False,
            })
        kind = "code pool (instant)" if fulfil == CODE else "manual account"
        print(f"  + {slug}: {len(variants)} packages, {kind} [INACTIVE]")
        added += 1

    print(f"done - {added} product(s) added, all inactive. Set prices, add codes "
          f"(for gift cards) and switch Active when ready.")


if __name__ == "__main__":
    main()
