#!/usr/bin/env python3
"""
Broaden the catalogue with more titles, so each section has enough to page
through.

    python3 scripts/seed-more-games.py <api> <email> 'password'

Idempotent: a product whose slug exists is skipped. Products are created ACTIVE
so they appear straight away, with EXAMPLE prices - set your real prices in the
admin panel before you push traffic at them.
"""
import json, sys
from urllib import error, request

GAMES = [
    ("honkai-star-rail", "Honkai: Star Rail", [("HSR-60", "60 Oneiric Shard", 4000),
        ("HSR-300", "300 + 30 Oneiric Shard", 19000), ("HSR-980", "980 + 110 Oneiric Shard", 60000),
        ("HSR-EXPRESS", "Express Supply Pass", 16500)]),
    ("arena-breakout", "Arena Breakout", [("AB-60", "60 Bonds", 4200),
        ("AB-300", "300 Bonds", 20000), ("AB-980", "980 Bonds", 62000)]),
    ("delta-force", "Delta Force", [("DF-60", "60 Delta Coins", 4200),
        ("DF-300", "300 Delta Coins", 20000), ("DF-980", "980 Delta Coins", 62000)]),
    ("identity-v", "Identity V", [("IDV-60", "60 Echoes", 4000),
        ("IDV-300", "300 Echoes", 19500), ("IDV-980", "980 Echoes", 61000)]),
    ("state-of-survival", "State of Survival", [("SOS-60", "60 Biocaps", 4200),
        ("SOS-300", "300 Biocaps", 20500), ("SOS-980", "980 Biocaps", 63000)]),
    ("farlight-84", "Farlight 84", [("FL-60", "60 Diamonds", 4200),
        ("FL-300", "300 Diamonds", 20500), ("FL-980", "980 Diamonds", 63000)]),
    ("lifeafter", "LifeAfter", [("LA-60", "60 Credits", 4200),
        ("LA-300", "300 Credits", 20500), ("LA-980", "980 Credits", 63000)]),
    ("solo-leveling-arise", "Solo Leveling: Arise", [("SLA-60", "60 Essence Stones", 4200),
        ("SLA-300", "300 Essence Stones", 20500), ("SLA-980", "980 Essence Stones", 63000)]),
    ("once-human", "Once Human", [("OH-60", "60 Starchrom", 4200),
        ("OH-300", "300 Starchrom", 20500), ("OH-980", "980 Starchrom", 63000)]),
    ("valorant", "Valorant", [("VAL-475", "475 VP", 15000),
        ("VAL-1000", "1000 VP", 30000), ("VAL-2050", "2050 VP", 60000)]),
    ("clash-royale", "Clash Royale", [("CR-500", "500 Gems", 20000),
        ("CR-1200", "1200 Gems", 45000), ("CR-PASS", "Pass Royale", 22000)]),
    ("free-fire-max", "Free Fire MAX", [("FFM-100", "100 Diamonds", 4500),
        ("FFM-310", "310 Diamonds", 13000), ("FFM-520", "520 Diamonds", 21000)]),
    ("whiteout-survival", "Whiteout Survival", [("WS-60", "60 Gems", 4200),
        ("WS-300", "300 Gems", 20500), ("WS-980", "980 Gems", 63000)]),
    ("wuthering-waves", "Wuthering Waves", [("WW-60", "60 Lunite", 4200),
        ("WW-300", "300 Lunite", 20500), ("WW-980", "980 Lunite", 63000)]),
    ("ragnarok-origin", "Ragnarok Origin", [("RO-60", "60 Nyan Berries", 4200),
        ("RO-300", "300 Nyan Berries", 20500), ("RO-980", "980 Nyan Berries", 63000)]),
    ("eafc-mobile", "EA SPORTS FC Mobile", [("FC-100", "100 FC Points", 5000),
        ("FC-500", "500 FC Points", 24000), ("FC-1050", "1050 FC Points", 48000)]),
]

CARDS = [
    ("amazon-gift-card", "Amazon Gift Card", "gift-cards",
     [("AMZ-10", "Amazon $10", 52000), ("AMZ-25", "Amazon $25", 128000),
      ("AMZ-50", "Amazon $50", 255000)]),
    ("netflix-gift-card", "Netflix Gift Card", "gift-cards",
     [("NFGC-15", "Netflix $15", 78000), ("NFGC-30", "Netflix $30", 155000)]),
    ("xbox-gift-card", "Xbox Gift Card", "gift-cards",
     [("XBOX-10", "Xbox $10", 52000), ("XBOX-25", "Xbox $25", 128000)]),
    ("bigo-live", "Bigo Live Diamonds", "vouchers",
     [("BIGO-100", "100 Diamonds", 9000), ("BIGO-500", "500 Diamonds", 43000)]),
    ("mico-live", "Mico Live Coins", "vouchers",
     [("MICO-100", "100 Coins", 9000), ("MICO-500", "500 Coins", 43000)]),
    ("tiktok-coins", "TikTok Coins", "vouchers",
     [("TT-100", "100 Coins", 9500), ("TT-500", "500 Coins", 46000)]),
]


def call(base, method, path, tok=None, body=None):
    data = None if body is None else json.dumps(body).encode()
    r = request.Request(base + path, data=data, method=method)
    r.add_header("Accept", "application/json")
    if data is not None:
        r.add_header("Content-Type", "application/json")
    if tok:
        r.add_header("Authorization", "Bearer " + tok)
    try:
        with request.urlopen(r, timeout=60) as x:
            raw = x.read()
            return json.loads(raw) if raw else None
    except error.HTTPError as e:
        raise SystemExit(f"{method} {path} failed: {e.code} {e.read().decode()[:300]}")


def create(base, tok, cats, slug, name, category, variants, fields):
    product = call(base, "POST", "/admin/products", tok, {
        "categoryId": cats[category], "slug": slug, "name": name, "nameMy": name,
        "description": f"{name} top-up delivered to your account.",
        "fulfillmentType": "MANUAL", "featured": True, "sortOrder": 60,
        "active": True, "fields": fields,
    })
    for i, (sku, vname, price) in enumerate(variants, start=1):
        call(base, "POST", f"/admin/products/{product['id']}/variants", tok, {
            "sku": sku, "name": vname, "nameMy": vname, "price": price,
            "costPrice": int(price * 0.88), "stockType": "UNLIMITED",
            "lowStockThreshold": 5, "maxPerOrder": 10, "popularity": 50,
            "sortOrder": i, "active": True,
        })


def main():
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    base = sys.argv[1].rstrip("/") + "/api/v1"
    tok = call(base, "POST", "/auth/login",
               body={"email": sys.argv[2], "password": sys.argv[3]})["accessToken"]
    print("signed in")
    cats = {c["slug"]: c["id"] for c in call(base, "GET", "/admin/categories", tok)}
    have = {p["slug"] for p in call(base, "GET", "/admin/products?size=300", tok)["items"]}

    player_id = [{"key": "player_id", "label": "Player ID", "labelMy": "Player ID",
                  "placeholder": "123456789", "inputType": "NUMBER",
                  "validationRegex": r"^[0-9]{5,15}$", "required": True,
                  "sortOrder": 1, "options": []}]
    added = 0
    for slug, name, variants in GAMES:
        if slug in have:
            print(f"  {slug}: already exists"); continue
        create(base, tok, cats, slug, name, "mobile-games", variants, player_id)
        print(f"  + {name} ({len(variants)} packages)"); added += 1
    for slug, name, category, variants in CARDS:
        if slug in have:
            print(f"  {slug}: already exists"); continue
        create(base, tok, cats, slug, name, category, variants, [])
        print(f"  + {name} ({len(variants)} packages)"); added += 1
    print(f"done - {added} product(s) added. Prices are EXAMPLES - set real ones.")


if __name__ == "__main__":
    main()
