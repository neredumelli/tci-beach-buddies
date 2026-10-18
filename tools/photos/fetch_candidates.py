#!/usr/bin/env python3
"""Fetch freely-licensed photo CANDIDATES for each destination from Wikimedia
Commons (runs in CI, which has internet). A human/Claude reviews them and
selects which become app assets (tools/photos/selection.json).

Output: photo-candidates/<poi-id>/<n>.jpg + photo-candidates/candidates.json
"""
import json, os, re, sys, time, urllib.parse, urllib.request

UA = "TCIBeachBuddies/1.0 (offline tourist app; contact neredumelli via GitHub) python-urllib"
API = "https://commons.wikimedia.org/w/api.php"
OK_LICENSES = re.compile(r"^(cc[- ]?by(-sa)?[- ]?[0-9.]*|cc0|public domain|pd.*)$", re.I)

QUERIES = {
    "grand-turk-cruise-center": ["Grand Turk Cruise Center", "Grand Turk cruise terminal"],
    "governors-beach": ["Governor's Beach Grand Turk", "Governors Beach Grand Turk"],
    "pillory-beach": ["Pillory Beach Grand Turk"],
    "osprey-beach": ["Osprey Beach Hotel Grand Turk", "Cockburn Town beach Grand Turk"],
    "boaby-rock-beach": ["Boaby Rock Grand Turk"],
    "white-sands-beach": ["White Sands Beach Grand Turk"],
    "cockburn-town": ["Cockburn Town Grand Turk", "Cockburn Town Turks and Caicos"],
    "grand-turk-lighthouse": ["Grand Turk Lighthouse"],
    "front-street": ["Front Street Cockburn Town", "Front Street Grand Turk"],
    "national-museum": ["Turks and Caicos National Museum", "Guinep House Grand Turk"],
    "hm-prison": ["Her Majesty's Prison Grand Turk", "Grand Turk prison"],
    "st-marys": ["St. Mary's Pro-Cathedral Grand Turk", "St Mary's church Grand Turk"],
    "st-thomas": ["St Thomas Anglican Church Grand Turk"],
    "columbus-landfall": ["Columbus Landfall National Park Grand Turk", "Columbus landfall Grand Turk"],
    "waterloo": ["Waterloo Government House Grand Turk", "Governor's residence Grand Turk"],
    "odd-fellows-lodge": ["Odd Fellows Lodge Grand Turk"],
    "victoria-library": ["Victoria Public Library Grand Turk"],
    "town-salina": ["Town Salina Grand Turk", "salina Grand Turk"],
    "red-salina": ["Red Salina Grand Turk", "salt pond Grand Turk"],
    "hawks-nest-salina": ["Hawks Nest Grand Turk"],
    "north-creek": ["North Creek Grand Turk"],
    "gibbs-cay": ["Gibbs Cay", "Gibbs Cay stingray"],
    "jags-mccartney-airport": ["JAGS McCartney International Airport", "Grand Turk airport"],
    "margaritaville": ["Margaritaville Grand Turk"],
    "jacks-shack": ["Jack's Shack Grand Turk"],
    "sand-bar": ["Sand Bar Grand Turk Duke Street"],
    "salt-raker-inn": ["Salt Raker Inn Grand Turk"],
    "bohio": ["Bohio Grand Turk"],
    "shoprite-grocery": ["Grand Turk grocery"],
    "ron-jon-surf-shop": ["Ron Jon Surf Shop Grand Turk"],
    "harbor-house": ["Harbor House Grand Turk"],
    "island-creations": ["Grand Turk art gallery"],
    "medical-centre": ["Grand Turk hospital", "Cockburn Town Medical Centre"],
    "police-station": ["Grand Turk police station"],
    "post-office": ["Grand Turk post office", "Cockburn Town post office"],
    "scotiabank": ["Scotiabank Grand Turk"],
    "_generic_beach": ["Grand Turk beach", "Grand Turk Island beach"],
    "_generic_island": ["Grand Turk Island", "Grand Turk Turks and Caicos"],
}

LOG = []

def get(url, tries=5):
    delay = 3.0
    for attempt in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept-Encoding": "identity"})
            with urllib.request.urlopen(req, timeout=60) as r:
                return r.read()
        except Exception as e:
            LOG.append(f"{type(e).__name__} {getattr(e, 'code', '')} attempt {attempt + 1}: {url[:140]}")
            if attempt == tries - 1:
                raise
            time.sleep(delay)
            delay *= 2

def strip_html(s):
    return re.sub(r"<[^>]+>", "", s or "").strip()

def search(q):
    params = dict(action="query", format="json", generator="search", gsrsearch=q, gsrnamespace="6",
                  gsrlimit="10", prop="imageinfo", iiprop="url|mime|size|extmetadata", iiurlwidth="960")
    data = json.loads(get(API + "?" + urllib.parse.urlencode(params)))
    pages = (data.get("query") or {}).get("pages") or {}
    out = []
    for p in sorted(pages.values(), key=lambda p: p.get("index", 99)):
        ii = (p.get("imageinfo") or [{}])[0]
        if ii.get("mime") not in ("image/jpeg", "image/png"):
            continue
        md = ii.get("extmetadata") or {}
        lic = strip_html((md.get("LicenseShortName") or {}).get("value"))
        if not OK_LICENSES.match(lic.replace("_", " ")):
            continue
        if ii.get("width", 0) < 640:
            continue
        out.append(dict(
            title=p["title"], page=ii.get("descriptionurl"), thumb=ii.get("thumburl"),
            width=ii.get("width"), height=ii.get("height"), license=lic,
            licenseUrl=strip_html((md.get("LicenseUrl") or {}).get("value")),
            author=strip_html((md.get("Artist") or {}).get("value"))[:200],
            description=strip_html((md.get("ImageDescription") or {}).get("value"))[:300],
            query=q,
        ))
    return out

def main(outdir):
    os.makedirs(outdir, exist_ok=True)
    result = {}
    for pid, qs in QUERIES.items():
        seen, cands = set(), []
        for q in qs:
            try:
                for c in search(q):
                    if c["title"] not in seen:
                        seen.add(c["title"]); cands.append(c)
            except Exception as e:
                LOG.append(f"search failed {pid} {q}: {e}")
            time.sleep(2.0)
        cands = cands[:4]
        os.makedirs(os.path.join(outdir, pid), exist_ok=True)
        for i, c in enumerate(cands):
            fn = os.path.join(outdir, pid, f"{i}.jpg")
            try:
                with open(fn, "wb") as f:
                    f.write(get(c["thumb"]))
                c["file"] = f"{pid}/{i}.jpg"
            except Exception as e:
                print("download failed", c["thumb"], e)
            time.sleep(1.5)
        result[pid] = cands
        print(pid, len(cands))
    with open(os.path.join(outdir, "log.txt"), "w") as f:
        f.write("\n".join(LOG))
    with open(os.path.join(outdir, "candidates.json"), "w") as f:
        json.dump(result, f, indent=1, ensure_ascii=False)

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "photo-candidates")
