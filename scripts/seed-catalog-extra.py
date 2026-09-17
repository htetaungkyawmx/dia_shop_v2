#!/usr/bin/env python3
"""
A second, larger pass over the catalogue: more titles in every section.

    python3 scripts/seed-catalog-extra.py <api> <email> 'password'

Idempotent - a slug that exists is skipped - and products are created ACTIVE so
they show at once. Every price is an EXAMPLE; set real ones in the admin panel.
"""
import json, sys
from urllib import error, request

# (slug, display name, [(sku, package name, example price)])
GAMES = [
    ("roblox", "Roblox", [("RBX-80", "80 Robux", 4500), ("RBX-400", "400 Robux", 21000), ("RBX-800", "800 Robux", 41000)]),
    ("zenless-zone-zero", "Zenless Zone Zero", [("ZZZ-60", "60 Monochrome", 4200), ("ZZZ-300", "300 Monochrome", 20500), ("ZZZ-980", "980 Monochrome", 63000)]),
    ("tower-of-fantasy", "Tower of Fantasy", [("TOF-60", "60 Tanium", 4200), ("TOF-300", "300 Tanium", 20500), ("TOF-980", "980 Tanium", 63000)]),
    ("pokemon-unite", "Pokemon UNITE", [("PU-60", "60 Aeos Gems", 4200), ("PU-300", "300 Aeos Gems", 20500), ("PU-980", "980 Aeos Gems", 63000)]),
    ("brawl-stars", "Brawl Stars", [("BS-30", "30 Gems", 4000), ("BS-170", "170 Gems", 20000), ("BS-360", "360 Gems", 41000)]),
    ("summoners-war", "Summoners War", [("SW-60", "60 Crystals", 4200), ("SW-300", "300 Crystals", 20500), ("SW-980", "980 Crystals", 63000)]),
    ("afk-journey", "AFK Journey", [("AFK-60", "60 Diamonds", 4200), ("AFK-300", "300 Diamonds", 20500), ("AFK-980", "980 Diamonds", 63000)]),
    ("black-clover-m", "Black Clover M", [("BCM-60", "60 Crystals", 4200), ("BCM-300", "300 Crystals", 20500), ("BCM-980", "980 Crystals", 63000)]),
    ("one-punch-man-world", "One Punch Man: World", [("OPM-60", "60 Gems", 4200), ("OPM-300", "300 Gems", 20500), ("OPM-980", "980 Gems", 63000)]),
    ("t3-arena", "T3 Arena", [("T3-60", "60 Crystals", 4200), ("T3-300", "300 Crystals", 20500)]),
    ("punishing-gray-raven", "Punishing: Gray Raven", [("PGR-60", "60 Rainbow Cards", 4200), ("PGR-300", "300 Rainbow Cards", 20500), ("PGR-980", "980 Rainbow Cards", 63000)]),
    ("teamfight-tactics", "Teamfight Tactics", [("TFT-575", "575 RP", 17000), ("TFT-1275", "1275 RP", 37000), ("TFT-2800", "2800 RP", 80000)]),
    ("blockman-go", "Blockman GO", [("BMG-100", "100 Gcubes", 4500), ("BMG-500", "500 Gcubes", 21000), ("BMG-1000", "1000 Gcubes", 41000)]),
    ("maplestory-m", "MapleStory M", [("MSM-60", "60 Crystals", 4200), ("MSM-300", "300 Crystals", 20500)]),
    ("ragnarok-x", "Ragnarok X", [("ROX-60", "60 Crystals", 4200), ("ROX-300", "300 Crystals", 20500)]),
    ("lords-mobile", "Lords Mobile", [("LM-60", "60 Gems", 4200), ("LM-300", "300 Gems", 20500), ("LM-980", "980 Gems", 63000)]),
    ("rise-of-kingdoms", "Rise of Kingdoms", [("ROK-60", "60 Gems", 4200), ("ROK-300", "300 Gems", 20500), ("ROK-980", "980 Gems", 63000)]),
    ("last-war-survival", "Last War: Survival", [("LWS-60", "60 Diamonds", 4200), ("LWS-300", "300 Diamonds", 20500)]),
    ("puzzles-and-survival", "Puzzles & Survival", [("PAS-60", "60 Diamonds", 4200), ("PAS-300", "300 Diamonds", 20500)]),
    ("eggy-party", "Eggy Party", [("EP-60", "60 Eggy Coins", 4200), ("EP-300", "300 Eggy Coins", 20500)]),
    ("sausage-man", "Sausage Man", [("SM-60", "60 Candy", 4200), ("SM-300", "300 Candy", 20500)]),
    ("metal-slug-awakening", "Metal Slug: Awakening", [("MSA-60", "60 Diamonds", 4200), ("MSA-300", "300 Diamonds", 20500)]),
    ("modern-strike-online", "Modern Strike Online", [("MSO-60", "60 Gold", 4200), ("MSO-300", "300 Gold", 20500)]),
    ("standoff-2", "Standoff 2", [("SO2-60", "60 Gold", 4200), ("SO2-300", "300 Gold", 20500)]),
    ("dragon-raja", "Dragon Raja", [("DR-60", "60 Diamonds", 4200), ("DR-300", "300 Diamonds", 20500)]),
    ("tarisland", "Tarisland", [("TL-60", "60 Crystals", 4200), ("TL-300", "300 Crystals", 20500)]),
    ("lineage-w", "Lineage W", [("LW-60", "60 Diamonds", 4200), ("LW-300", "300 Diamonds", 20500)]),
    ("garena-undawn", "Garena Undawn", [("GU-60", "60 Gold", 4200), ("GU-300", "300 Gold", 20500)]),
    ("super-sus", "Super Sus", [("SS-60", "60 Gold", 4200), ("SS-300", "300 Gold", 20500)]),
    ("stumble-guys", "Stumble Guys", [("SG-60", "60 Gems", 4200), ("SG-300", "300 Gems", 20500)]),
    ("marvel-snap", "MARVEL SNAP", [("MS-60", "60 Gold", 4200), ("MS-300", "300 Gold", 20500)]),
    ("growtopia", "Growtopia", [("GT-60", "60 Gems", 4200), ("GT-300", "300 Gems", 20500)]),
]

CARDS = [
    ("roblox-gift-card", "Roblox Gift Card", "gift-cards", [("RBXGC-10", "Roblox $10", 52000), ("RBXGC-25", "Roblox $25", 128000)]),
    ("spotify-gift-card", "Spotify Gift Card", "gift-cards", [("SPGC-10", "Spotify $10", 52000), ("SPGC-30", "Spotify $30", 155000)]),
    ("nintendo-eshop", "Nintendo eShop Card", "gift-cards", [("NIN-10", "Nintendo $10", 52000), ("NIN-35", "Nintendo $35", 180000)]),
    ("riot-points", "Riot Points Card", "gift-cards", [("RP-10", "Riot $10", 52000), ("RP-25", "Riot $25", 128000)]),
    ("discord-nitro", "Discord Nitro", "gift-cards", [("DN-1M", "Nitro 1 Month", 16000), ("DN-1Y", "Nitro 1 Year", 160000)]),
    ("crunchyroll", "Crunchyroll Premium", "premium-apps", [("CR-1M", "1 Month", 12000), ("CR-3M", "3 Months", 33000)]),
    ("viu-premium", "Viu Premium", "premium-apps", [("VIU-1M", "1 Month", 8000), ("VIU-3M", "3 Months", 22000)]),
    ("wetv-vip", "WeTV VIP", "premium-apps", [("WETV-1M", "1 Month", 8000), ("WETV-3M", "3 Months", 22000)]),
    ("iqiyi-vip", "iQIYI VIP", "premium-apps", [("IQ-1M", "1 Month", 8500), ("IQ-3M", "3 Months", 23000)]),
    ("hbo-max", "HBO Max", "premium-apps", [("HBO-1M", "1 Month", 15000), ("HBO-3M", "3 Months", 41000)]),
    ("apple-music", "Apple Music", "premium-apps", [("AM-1M", "1 Month", 11000), ("AM-3M", "3 Months", 30000)]),
    ("telegram-premium", "Telegram Premium", "premium-apps", [("TG-1M", "1 Month", 12000), ("TG-1Y", "1 Year", 110000)]),
    ("duolingo-super", "Duolingo Super", "premium-apps", [("DUO-1M", "1 Month", 13000), ("DUO-1Y", "1 Year", 120000)]),
    ("grammarly-premium", "Grammarly Premium", "premium-apps", [("GR-1M", "1 Month", 18000), ("GR-1Y", "1 Year", 170000)]),
    ("likee-diamonds", "Likee Diamonds", "vouchers", [("LK-100", "100 Diamonds", 9000), ("LK-500", "500 Diamonds", 43000)]),
    ("poppo-live", "Poppo Live Coins", "vouchers", [("PP-100", "100 Coins", 9000), ("PP-500", "500 Coins", 43000)]),
    ("starmaker", "StarMaker Coins", "vouchers", [("STM-100", "100 Coins", 9000), ("STM-500", "500 Coins", 43000)]),
    ("chamet", "Chamet Diamonds", "vouchers", [("CH-100", "100 Diamonds", 9000), ("CH-500", "500 Diamonds", 43000)]),
    ("imo-diamonds", "imo Diamonds", "vouchers", [("IMO-100", "100 Diamonds", 9000), ("IMO-500", "500 Diamonds", 43000)]),
    ("hago-coins", "Hago Coins", "vouchers", [("HG-100", "100 Coins", 9000), ("HG-500", "500 Coins", 43000)]),
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
        "fulfillmentType": "MANUAL", "featured": True, "sortOrder": 70,
        "active": True, "fields": fields,
    })
    for i, (sku, vname, price) in enumerate(variants, start=1):
        call(base, "POST", f"/admin/products/{product['id']}/variants", tok, {
            "sku": sku, "name": vname, "nameMy": vname, "price": price,
            "costPrice": int(price * 0.88), "stockType": "UNLIMITED",
            "lowStockThreshold": 5, "maxPerOrder": 10, "popularity": 40,
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
    have = {p["slug"] for p in call(base, "GET", "/admin/products?size=400", tok)["items"]}

    player_id = [{"key": "player_id", "label": "Player ID", "labelMy": "Player ID",
                  "placeholder": "123456789", "inputType": "NUMBER",
                  "validationRegex": r"^[0-9]{5,15}$", "required": True,
                  "sortOrder": 1, "options": []}]
    added = 0
    for slug, name, variants in GAMES:
        if slug in have:
            continue
        create(base, tok, cats, slug, name, "mobile-games", variants, player_id)
        print(f"  + {name}"); added += 1
    for slug, name, category, variants in CARDS:
        if slug in have:
            continue
        create(base, tok, cats, slug, name, category, variants, [])
        print(f"  + {name}"); added += 1
    print(f"done - {added} product(s) added. Prices are EXAMPLES.")


if __name__ == "__main__":
    main()
