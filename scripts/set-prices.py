#!/usr/bin/env python3
"""
Apply the HK price list to MLBB diamonds, PUBG UC and the Weekly Pass in bulk.

    python3 scripts/set-prices.py https://api.hk-game-shop.store admin@mail.com 'password'

Matches each package by the number in its name (e.g. "325 UC" -> 325) and sets
the selling price from the tables below. Packages not in a table are left as
they are. Review/adjust any price in the admin panel afterwards.
"""
import json, re, sys
from urllib import error, request

# amount -> price (MMK), from the HK GAME SHOP price lists
MLBB = {86:5200,172:10400,257:15600,343:20800,429:26000,514:31200,600:36400,
        706:41600,792:46800,878:52000,963:57200,1049:62400,1135:67600,1220:72800,
        1412:83200,1584:93600,1669:98800,1755:104000,1841:109200,2195:124800,
        2281:130000,2538:145600,2901:166400,3158:182000,3688:208000,4394:249600,
        4566:260000,5100:291200,5532:312000,6055:343200,6752:384800,7376:416000,
        8433:478400,9288:520000}
PUBG = {60:4100,120:8200,180:12300,325:20000,385:24000,660:40000,720:44000,
        985:60000,1800:99500,2460:139500,3850:189000,4510:236000,5650:295500,
        8100:368000,9900:477000,11950:574000,16200:756000}
WEEKLY = 6400  # Global weekly pass

TABLES = {"mlbb": MLBB, "pubg-mobile": PUBG}


def call(base, method, path, tok=None, body=None):
    data = None if body is None else json.dumps(body).encode()
    r = request.Request(base + path, data=data, method=method)
    r.add_header("Accept", "application/json")
    if data is not None: r.add_header("Content-Type", "application/json")
    if tok: r.add_header("Authorization", "Bearer " + tok)
    try:
        with request.urlopen(r, timeout=60) as x:
            raw = x.read(); return json.loads(raw) if raw else None
    except error.HTTPError as e:
        raise SystemExit(f"{method} {path} failed: {e.code} {e.read().decode()[:200]}")


def main():
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    base = sys.argv[1].rstrip("/") + "/api/v1"
    tok = call(base, "POST", "/auth/login", body={"email": sys.argv[2], "password": sys.argv[3]})["accessToken"]
    print("signed in")
    products = {p["slug"]: p for p in call(base, "GET", "/admin/products?size=200", tok)["items"]}
    changed = 0
    for slug, table in TABLES.items():
        p = products.get(slug)
        if not p:
            print(f"  skip {slug}: not found"); continue
        detail = call(base, "GET", f"/admin/products/{p['id']}", tok)
        for v in detail.get("variants", []):
            name = v["name"]
            price = None
            if re.search(r"weekly", name, re.I):
                price = WEEKLY
            else:
                m = re.match(r"\s*([0-9][0-9,]*)", name)
                if m:
                    price = table.get(int(m.group(1).replace(",", "")))
            if price is None or price == v["price"]:
                continue
            vb = {k: v.get(k) for k in ("sku","name","nameMy","bonusText","description",
                  "compareAtPrice","costPrice","imageUrl","stockType","stockQuantity",
                  "lowStockThreshold","maxPerOrder","popularity","sortOrder","active",
                  "supplier","supplierProductId")}
            vb["price"] = price
            vb["compareAtPrice"] = None
            call(base, "PUT", f"/admin/variants/{v['id']}", tok, vb)
            print(f"  {slug}: {name} -> {price:,} Ks")
            changed += 1
    print(f"done - {changed} price(s) updated")


if __name__ == "__main__":
    main()
