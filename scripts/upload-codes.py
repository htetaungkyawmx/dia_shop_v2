#!/usr/bin/env python3
"""
Bulk-upload gift-card / voucher codes into a package, and (optionally) switch it
on. Buy a batch of codes from your supplier, paste them into a text file (one
code per line), and load them all at once.

    python3 scripts/upload-codes.py <api> <email> <password> <product-slug> <variant-sku> <codes.txt> [--secret PIN] [--activate]

Example:
    python3 scripts/upload-codes.py https://api.hk-game-shop.store you@mail.com 'pass' \
        razer-gold RAZER-10 razer10.txt --activate

Blank lines and lines starting with # are ignored. Duplicate codes already in
the pool are skipped by the server. With --activate the package and its product
are switched Active after the codes land, so it starts selling immediately.
"""
import json
import sys
from urllib import error, request


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


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    flags = [a for a in sys.argv[1:] if a.startswith("--")]
    if len(args) < 6:
        raise SystemExit(__doc__)
    api, email, password, slug, sku, codes_file = args[:6]
    secret = None
    for f in flags:
        if f.startswith("--secret="):
            secret = f.split("=", 1)[1]
    activate = "--activate" in flags
    base = api.rstrip("/") + "/api/v1"

    try:
        with open(codes_file, encoding="utf-8") as fh:
            codes = [ln.strip() for ln in fh
                     if ln.strip() and not ln.strip().startswith("#")]
    except FileNotFoundError:
        raise SystemExit(
            f"\nNo such file: {codes_file}\n\n"
            "This command is only needed AFTER you have bought real gift-card\n"
            "codes from a supplier. Until then the product sells by hand and\n"
            "there is nothing to run.\n\n"
            "When you do have codes, put one per line in a text file, e.g.\n"
            f"    printf '%s\\n' CODE-ONE CODE-TWO > {codes_file}\n"
            "then run this command again.\n")
    if not codes:
        raise SystemExit(f"{codes_file} is empty - put one code per line.")

    tok = call(base, "POST", "/auth/login", body={"email": email, "password": password})["accessToken"]
    print("signed in")

    products = {p["slug"]: p for p in call(base, "GET", "/admin/products?size=200", tok)["items"]}
    p = products.get(slug)
    if not p:
        raise SystemExit(f"Product '{slug}' not found.")
    detail = call(base, "GET", f"/admin/products/{p['id']}", tok)
    variant = next((v for v in detail.get("variants", []) if v["sku"] == sku), None)
    if not variant:
        raise SystemExit(f"Package '{sku}' not found in {slug}.")
    if variant["stockType"] != "CODE_POOL":
        raise SystemExit(f"Package {sku} is '{variant['stockType']}', not CODE_POOL — codes only load into a code pool.")

    body = {"codes": codes}
    if secret:
        body["secret"] = secret
    res = call(base, "POST", f"/admin/variants/{variant['id']}/stock/codes", tok, body)
    print(f"  uploaded: {res['added']} added, {res['skippedDuplicates']} duplicates skipped, "
          f"{res['availableNow']} now in stock")

    if activate:
        # Round-trip the product and this variant with active=true.
        pbody = {
            "categoryId": detail["categoryId"], "slug": detail["slug"], "name": detail["name"],
            "nameMy": detail.get("nameMy"), "description": detail.get("description"),
            "descriptionMy": detail.get("descriptionMy"), "imageUrl": detail.get("imageUrl"),
            "bannerUrl": detail.get("bannerUrl"), "instructions": detail.get("instructions"),
            "instructionsMy": detail.get("instructionsMy"), "fulfillmentType": detail["fulfillmentType"],
            "featured": detail["featured"], "sortOrder": detail["sortOrder"], "active": True,
            "supplierGame": detail.get("supplierGame"),
            "fields": [{**{k: f.get(k) for k in ("id", "key", "label", "labelMy", "placeholder",
                                                 "helpText", "inputType", "validationRegex", "required")},
                        "options": f.get("options") or [], "sortOrder": i}
                       for i, f in enumerate(detail.get("fields", []))],
        }
        call(base, "PUT", f"/admin/products/{p['id']}", tok, pbody)
        vb = {k: variant.get(k) for k in ("sku", "name", "nameMy", "bonusText", "description",
                                          "price", "compareAtPrice", "costPrice", "imageUrl",
                                          "stockType", "stockQuantity", "lowStockThreshold",
                                          "maxPerOrder", "popularity", "sortOrder",
                                          "supplier", "supplierProductId")}
        vb["active"] = True
        call(base, "PUT", f"/admin/variants/{variant['id']}", tok, vb)
        print(f"  ✓ {slug} / {sku} is now ACTIVE and selling")
    else:
        print("  (not activated — switch it on in the admin panel when ready)")
    print("done")


if __name__ == "__main__":
    main()
