#!/usr/bin/env python3
"""
Load game artwork and the extra game catalogue into a running shop.

    python3 scripts/seed-media.py https://api.example.com admin@example.com 'password'

Everything goes through the public admin API, exactly as if staff had done it
by hand, so it works against local Docker and production alike. Safe to run
more than once: existing products are updated rather than duplicated, and
banners are only added if one with the same title is missing.

Prices for the games added here are EXAMPLES. Set real prices in the admin
panel before selling.
"""
import json
import mimetypes
import sys
import uuid
from pathlib import Path
from urllib import error, request

MEDIA = Path(__file__).parent / "seed-media"


class Api:
    def __init__(self, base: str):
        self.base = base.rstrip("/") + "/api/v1"
        self.token = None

    def call(self, method: str, path: str, body=None):
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

    def upload(self, file: Path, folder: str) -> str:
        boundary = uuid.uuid4().hex
        mime = mimetypes.guess_type(file.name)[0] or "application/octet-stream"
        body = (
            f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"{file.name}\"\r\n"
            f"Content-Type: {mime}\r\n\r\n"
        ).encode() + file.read_bytes() + f"\r\n--{boundary}--\r\n".encode()
        req = request.Request(f"{self.base}/admin/uploads/image?folder={folder}", data=body, method="POST")
        req.add_header("Content-Type", f"multipart/form-data; boundary={boundary}")
        req.add_header("Authorization", f"Bearer {self.token}")
        with request.urlopen(req, timeout=120) as resp:
            return json.loads(resp.read())["url"]


def player_id(pattern=r"^[0-9]{5,15}$", key="player_id", label="Player ID", label_my="Player ID", placeholder="123456789"):
    return {"key": key, "label": label, "labelMy": label_my, "placeholder": placeholder,
            "inputType": "TEXT" if key != "player_id" else "NUMBER",
            "validationRegex": pattern, "required": True, "sortOrder": 1, "options": []}


# slug -> product definition. Images are file names in scripts/seed-media.
NEW_GAMES = [
    {
        "slug": "genshin-impact", "name": "Genshin Impact", "nameMy": "Genshin Impact", "sortOrder": 5,
        "description": "Genesis Crystals and Blessing of the Welkin Moon, sent to your UID.",
        "descriptionMy": "Genesis Crystals နှင့် Welkin Moon ကို သင့် UID သို့ ပို့ပေးပါသည်။",
        "image": "genshin-impact.jpg",
        "fields": [
            player_id(r"^[0-9]{9,10}$", placeholder="800123456", label="UID", label_my="UID"),
            {"key": "server", "label": "Server", "labelMy": "Server", "inputType": "SELECT",
             "options": ["Asia", "America", "Europe", "TW, HK, MO"], "required": True, "sortOrder": 2},
        ],
        "variants": [
            ("GI-60", "60 Genesis Crystals", None, 3500),
            ("GI-330", "300 + 30 Genesis Crystals", "+30 Bonus", 16500),
            ("GI-1090", "980 + 110 Genesis Crystals", "+110 Bonus", 50000),
            ("GI-2240", "1980 + 260 Genesis Crystals", "+260 Bonus", 99000),
            ("GI-WELKIN", "Blessing of the Welkin Moon", "Best value", 16500),
        ],
    },
    {
        "slug": "wild-rift", "name": "League of Legends: Wild Rift", "nameMy": "Wild Rift", "sortOrder": 6,
        "description": "Wild Cores delivered to your Riot ID.",
        "descriptionMy": "Wild Cores ကို သင့် Riot ID သို့ ပို့ပေးပါသည်။",
        "image": "wild-rift.jpg",
        "fields": [player_id(r"^.{3,16}#[A-Za-z0-9]{2,5}$", key="riot_id", label="Riot ID",
                             label_my="Riot ID", placeholder="Name#TAG")],
        "variants": [
            ("WR-425", "425 Wild Cores", None, 8500),
            ("WR-1000", "1000 Wild Cores", "+75 Bonus", 19500),
            ("WR-2100", "2100 Wild Cores", "+200 Bonus", 39000),
        ],
    },
    {
        "slug": "honor-of-kings", "name": "Honor of Kings", "nameMy": "Honor of Kings", "sortOrder": 7,
        "description": "Tokens for Honor of Kings, sent to your Player ID.",
        "descriptionMy": "Honor of Kings Tokens ကို သင့် Player ID သို့ ပို့ပေးပါသည်။",
        "image": "honor-of-kings.jpg",
        "fields": [player_id()],
        "variants": [
            ("HOK-80", "80 Tokens", None, 3800),
            ("HOK-400", "400 Tokens", "+16 Bonus", 17500),
            ("HOK-800", "800 Tokens", "+40 Bonus", 34000),
        ],
    },
    {
        "slug": "clash-of-clans", "name": "Clash of Clans", "nameMy": "Clash of Clans", "sortOrder": 8,
        "description": "Gems and the Gold Pass for your village.",
        "descriptionMy": "သင့်ရွာအတွက် Gems နှင့် Gold Pass။",
        "image": "clash-of-clans.jpg",
        "fields": [player_id(r"^#?[0-9A-Za-z]{6,12}$", key="player_tag", label="Player Tag",
                             label_my="Player Tag", placeholder="#2PP9QUV0")],
        "variants": [
            ("COC-500", "500 Gems", None, 20000),
            ("COC-1200", "1200 Gems", None, 45000),
            ("COC-GOLD", "Gold Pass", "Monthly", 22000),
        ],
    },
    {
        "slug": "cod-mobile", "name": "Call of Duty: Mobile", "nameMy": "COD Mobile", "sortOrder": 9,
        "description": "CoD Points delivered to your Player ID.",
        "descriptionMy": "CoD Points ကို သင့် Player ID သို့ ပို့ပေးပါသည်။",
        "image": "cod-mobile.jpg",
        "fields": [player_id()],
        "variants": [
            ("COD-80", "80 CP", None, 4500),
            ("COD-420", "420 CP", "+20 Bonus", 21000),
            ("COD-880", "880 CP", "+80 Bonus", 42000),
        ],
    },
    {
        "slug": "blood-strike", "name": "Blood Strike", "nameMy": "Blood Strike", "sortOrder": 10,
        "description": "Golds and the Strike Pass for Blood Strike.",
        "descriptionMy": "Blood Strike အတွက် Golds နှင့် Strike Pass။",
        "image": "blood-strike.jpg",
        "fields": [player_id()],
        "variants": [
            ("BS-100", "100 Golds", None, 4500),
            ("BS-550", "500 + 50 Golds", "+50 Bonus", 21000),
            ("BS-PASS", "Strike Pass", "Season", 18000),
        ],
    },
]

EXISTING_ART = {
    "mlbb": {"image": "mlbb.jpg", "banner": "header-mlbb.jpg"},
    "magic-chess": {"image": "magic-chess.jpg", "banner": "banner-magic-chess.jpg"},
}

BANNERS = [
    {"title": "Magic Chess: Go Go", "file": "banner-magic-chess.jpg", "linkType": "PRODUCT", "linkValue": "magic-chess"},
    {"title": "Mobile Legends: Bang Bang", "file": "banner-mlbb.jpg", "linkType": "PRODUCT", "linkValue": "mlbb"},
]


def product_body(p: dict) -> dict:
    """Round-trips an AdminProductResponse into a ProductUpsertRequest."""
    return {
        "categoryId": p["categoryId"], "slug": p["slug"], "name": p["name"], "nameMy": p.get("nameMy"),
        "description": p.get("description"), "descriptionMy": p.get("descriptionMy"),
        "imageUrl": p.get("imageUrl"), "bannerUrl": p.get("bannerUrl"),
        "instructions": p.get("instructions"), "instructionsMy": p.get("instructionsMy"),
        "fulfillmentType": p["fulfillmentType"], "featured": p["featured"],
        "sortOrder": p["sortOrder"], "active": p["active"],
        # Keep field ids, otherwise each field is deleted and re-inserted under
        # the same key and trips the (product_id, field_key) unique constraint.
        "fields": [{**{k: f.get(k) for k in ("id", "key", "label", "labelMy", "placeholder", "helpText",
                                              "inputType", "validationRegex", "required")},
                    "options": f.get("options") or [], "sortOrder": i} for i, f in enumerate(p.get("fields", []))],
    }


def main():
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    api = Api(sys.argv[1])
    api.token = api.call("POST", "/auth/login", {"email": sys.argv[2], "password": sys.argv[3]})["accessToken"]
    print("signed in")

    products = {p["slug"]: p for p in api.call("GET", "/admin/products?size=100")["items"]}
    games = next(c for c in api.call("GET", "/admin/categories") if c["slug"] == "mobile-games")
    uploaded = {}

    def url_for(name: str, folder="catalog") -> str:
        if name not in uploaded:
            uploaded[name] = api.upload(MEDIA / name, folder)
        return uploaded[name]

    for slug, art in EXISTING_ART.items():
        p = products.get(slug)
        if not p:
            print(f"  skip {slug}: not in catalog")
            continue
        if p.get("imageUrl") and p.get("bannerUrl"):
            print(f"  {slug}: already has artwork")
            continue
        body = product_body(p)
        body["imageUrl"] = body["imageUrl"] or url_for(art["image"])
        body["bannerUrl"] = body["bannerUrl"] or url_for(art["banner"], "banners")
        api.call("PUT", f"/admin/products/{p['id']}", body)
        print(f"  {slug}: artwork added")

    for game in NEW_GAMES:
        if game["slug"] in products:
            print(f"  {game['slug']}: already exists")
            continue
        created = api.call("POST", "/admin/products", {
            "categoryId": games["id"], "slug": game["slug"], "name": game["name"], "nameMy": game["nameMy"],
            "description": game["description"], "descriptionMy": game["descriptionMy"],
            "imageUrl": url_for(game["image"]), "fulfillmentType": "MANUAL",
            "featured": True, "sortOrder": game["sortOrder"], "active": True, "fields": game["fields"],
        })
        for i, (sku, name, bonus, price) in enumerate(game["variants"], start=1):
            api.call("POST", f"/admin/products/{created['id']}/variants", {
                "sku": sku, "name": name, "nameMy": name, "bonusText": bonus, "price": price,
                "costPrice": 0, "stockType": "UNLIMITED", "lowStockThreshold": 5, "maxPerOrder": 10,
                "popularity": 80 - i * 5, "sortOrder": i, "active": True,
            })
        print(f"  {game['slug']}: created with {len(game['variants'])} packages")

    banners = api.call("GET", "/admin/banners")
    for b in banners:
        if "placehold.co" in (b.get("imageUrl") or ""):
            api.call("DELETE", f"/admin/banners/{b['id']}")
            print(f"  removed placeholder banner: {b.get('title')}")
    titles = {b.get("title") for b in banners}
    for i, banner in enumerate(BANNERS, start=1):
        if banner["title"] in titles:
            continue
        api.call("POST", "/admin/banners", {
            "title": banner["title"], "imageUrl": url_for(banner["file"], "banners"),
            "linkType": banner["linkType"], "linkValue": banner["linkValue"], "sortOrder": i, "active": True,
        })
        print(f"  banner added: {banner['title']}")
    print("done")


if __name__ == "__main__":
    main()
