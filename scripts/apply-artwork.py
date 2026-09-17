#!/usr/bin/env python3
"""
Generate a clean branded card (and a wide banner) for every product and upload
them, so the whole store looks consistent. Original artwork only - a gradient,
a glow and a drawn gem/coin/gift/play icon plus the product name. No third-party
game art is downloaded or hosted.

    python3 scripts/apply-artwork.py https://api.hk-game-shop.store admin@mail.com 'password'

Options:
    --only-generate DIR   just write the images into DIR, upload nothing (preview)
    --only slug1,slug2     limit to these product slugs
    --no-banner            product images only, skip the wide banners
    --overwrite            replace artwork even if the product already has an image

Needs Pillow:  pip install pillow
"""
import json
import sys
import tempfile
import uuid
import os
from urllib import error, request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import artwork_gen as art


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


def upload(base, tok, path, folder):
    boundary = uuid.uuid4().hex
    body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; "
            f"filename=\"{os.path.basename(path)}\"\r\nContent-Type: image/png\r\n\r\n"
            ).encode() + open(path, "rb").read() + f"\r\n--{boundary}--\r\n".encode()
    r = request.Request(f"{base}/admin/uploads/image?folder={folder}", data=body, method="POST")
    r.add_header("Content-Type", f"multipart/form-data; boundary={boundary}")
    r.add_header("Authorization", "Bearer " + tok)
    with request.urlopen(r, timeout=120) as x:
        return json.loads(x.read())["url"]


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    flags = sys.argv[1:]
    if len(args) < 3 and "--only-generate" not in " ".join(flags):
        raise SystemExit(__doc__)

    only = None
    for f in flags:
        if f.startswith("--only="):
            only = set(f.split("=", 1)[1].split(","))
    gen_dir = None
    if "--only-generate" in flags:
        gen_dir = flags[flags.index("--only-generate") + 1]
        os.makedirs(gen_dir, exist_ok=True)
    want_banner = "--no-banner" not in flags
    overwrite = "--overwrite" in flags

    api, email, password = args[0], args[1], args[2]
    base = api.rstrip("/") + "/api/v1"
    tok = call(base, "POST", "/auth/login", body={"email": email, "password": password})["accessToken"]
    print("signed in")

    cat_slug = {c["id"]: c["slug"] for c in call(base, "GET", "/admin/categories", tok)}
    products = call(base, "GET", "/admin/products?size=200", tok)["items"]
    tmp = tempfile.mkdtemp()
    done = 0

    for p in products:
        slug = p["slug"]
        if only and slug not in only:
            continue
        cat = cat_slug.get(p.get("categoryId"), "mobile-games")
        card = os.path.join(gen_dir or tmp, f"{slug}.png")
        art.make_card(p["name"], cat, slug, card)
        banner = os.path.join(gen_dir or tmp, f"{slug}-banner.png")
        if want_banner:
            art.make_banner(p["name"], cat, slug, banner)

        if gen_dir:
            print(f"  generated {slug}")
            done += 1
            continue

        detail = call(base, "GET", f"/admin/products/{p['id']}", tok)
        if detail.get("imageUrl") and not overwrite:
            print(f"  {slug}: already has an image (use --overwrite to replace)")
            continue
        image_url = upload(base, tok, card, "catalog")
        banner_url = detail.get("bannerUrl")
        if want_banner:
            banner_url = upload(base, tok, banner, "banners")

        body = {
            "categoryId": detail["categoryId"], "slug": detail["slug"], "name": detail["name"],
            "nameMy": detail.get("nameMy"), "description": detail.get("description"),
            "descriptionMy": detail.get("descriptionMy"), "imageUrl": image_url,
            "bannerUrl": banner_url, "instructions": detail.get("instructions"),
            "instructionsMy": detail.get("instructionsMy"), "fulfillmentType": detail["fulfillmentType"],
            "featured": detail["featured"], "sortOrder": detail["sortOrder"], "active": detail["active"],
            "supplierGame": detail.get("supplierGame"),
            "fields": [{**{k: f.get(k) for k in ("id", "key", "label", "labelMy", "placeholder",
                                                 "helpText", "inputType", "validationRegex", "required")},
                        "options": f.get("options") or [], "sortOrder": i}
                       for i, f in enumerate(detail.get("fields", []))],
        }
        call(base, "PUT", f"/admin/products/{p['id']}", tok, body)
        print(f"  ✓ {slug}: artwork uploaded")
        done += 1

    print(f"done - {done} product(s) processed"
          + (f", images written to {gen_dir}" if gen_dir else ""))


if __name__ == "__main__":
    main()
