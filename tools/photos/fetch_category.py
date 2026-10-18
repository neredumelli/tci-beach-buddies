#!/usr/bin/env python3
"""Download every freely licensed photo in Commons Category:Cockburn Town
(and related Grand Turk categories), recursing into subcategories, for
human review. Output: <out>/<n>.jpg + <out>/files.json"""
import json, os, re, sys, time, urllib.parse, urllib.request

UA = "TCIBeachBuddies/1.0 (offline tourist app; github.com/neredumelli/tci-beach-buddies)"
API = "https://commons.wikimedia.org/w/api.php"
ROOTS = ["Category:Cockburn Town", "Category:Grand Turk Island"]
MAX_DEPTH = 4
OK = ("cc0", "pd", "public domain", "cc by", "cc-by", "cc by-sa", "cc-by-sa")


def get(url, tries=5):
    d = 5
    for a in range(tries):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": UA}), timeout=60) as r:
                return r.read()
        except Exception as e:
            print("retry", a, getattr(e, "code", e), flush=True)
            if a == tries - 1:
                raise
            time.sleep(d)
            d *= 2


def api(**p):
    p.update(format="json", formatversion="2")
    time.sleep(1.0)
    return json.loads(get(API + "?" + urllib.parse.urlencode(p)))


def members(cat, kind):
    out, cont = [], {}
    while True:
        r = api(action="query", list="categorymembers", cmtitle=cat, cmtype=kind, cmlimit=500, **cont)
        out += [m["title"] for m in r["query"]["categorymembers"]]
        if "continue" not in r:
            return out
        cont = {"cmcontinue": r["continue"]["cmcontinue"]}


def strip(h):
    return re.sub(r"<[^>]+>", "", h or "").strip()[:400]


def main(out):
    os.makedirs(out, exist_ok=True)
    seen_cats, files = set(), {}
    queue = [(c, 0, c) for c in ROOTS]
    while queue:
        cat, depth, path = queue.pop(0)
        if cat in seen_cats:
            continue
        seen_cats.add(cat)
        print("cat", depth, cat, flush=True)
        for f in members(cat, "file"):
            files.setdefault(f, path)
        if depth < MAX_DEPTH:
            for sc in members(cat, "subcat"):
                queue.append((sc, depth + 1, path + " > " + sc.replace("Category:", "")))
    titles = list(files)
    print("files", len(titles), "cats", len(seen_cats), flush=True)
    res = []
    for i in range(0, len(titles), 40):
        r = api(action="query", titles="|".join(titles[i:i + 40]), prop="imageinfo",
                iiprop="url|extmetadata|mime|size", iiurlwidth="800")
        for p in r["query"]["pages"]:
            ii = (p.get("imageinfo") or [{}])[0]
            if not ii.get("mime", "").startswith(("image/jpeg", "image/png")):
                continue
            md = ii.get("extmetadata", {})
            lic = strip(md.get("LicenseShortName", {}).get("value", ""))
            res.append(dict(title=p["title"], category=files.get(p["title"], ""), license=lic,
                            licenseOk=lic.lower().startswith(OK),
                            author=strip(md.get("Artist", {}).get("value", "")),
                            description=strip(md.get("ImageDescription", {}).get("value", "")),
                            width=ii.get("width"), height=ii.get("height"),
                            url=ii.get("thumburl"), landing=ii.get("descriptionurl")))
    for n, c in enumerate(res):
        if not c["licenseOk"]:
            continue
        try:
            open(os.path.join(out, f"{n}.jpg"), "wb").write(get(c["url"]))
            c["file"] = f"{n}.jpg"
        except Exception as e:
            print("dl fail", c["title"], e, flush=True)
        time.sleep(0.8)
    json.dump(dict(categories=sorted(seen_cats), files=res), open(os.path.join(out, "files.json"), "w"),
              indent=1, ensure_ascii=False)
    print("done", len(res), flush=True)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "commons-category")
