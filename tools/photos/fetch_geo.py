#!/usr/bin/env python3
"""Second-pass photo search for destinations that still have no photo.

Sources (all free licences that allow commercial use + modification):
  1. Wikimedia Commons GEO search: files geotagged within RADIUS m of the
     destination's map position (finds photos whose title never names the place).
  2. Wikimedia Commons full-text search with alternate names.
  3. Openverse (Flickr etc.) with alternate names.

Output for human review (nothing here goes into the app automatically):
  <out>/<poi-id>/<n>.jpg  +  <out>/candidates.json  (licence, author, distance)
"""
import json, math, os, sys, time, urllib.parse, urllib.request

UA = "TCIBeachBuddies/1.0 (offline tourist app; github.com/neredumelli/tci-beach-buddies)"
COMMONS = "https://commons.wikimedia.org/w/api.php"
OPENVERSE = "https://api.openverse.org/v1/images/"
OK_LICENCES = ("cc0", "pd", "public domain", "cc by", "cc-by", "cc by-sa", "cc-by-sa")
RADIUS = 250
PER_POI = 10

NAMES = {
    "pillory-beach": ["Pillory Beach Grand Turk", "Guanahani Beach Grand Turk", "Bohio beach Grand Turk"],
    "boaby-rock-beach": ["Boaby Rock Grand Turk", "Grand Turk south beach"],
    "white-sands-beach": ["White Sands Beach Grand Turk"],
    "hm-prison": ["HM Prison Grand Turk", "Her Majesty's Prison Cockburn Town", "Grand Turk prison"],
    "st-marys": ["St Mary's Church Grand Turk", "St Mary's Pro-Cathedral Cockburn Town", "Anglican Cockburn Town"],
    "waterloo": ["Waterloo Grand Turk", "Governor's residence Grand Turk"],
    "odd-fellows-lodge": ["Odd Fellows Lodge Grand Turk", "Oddfellows Cockburn Town"],
    "victoria-library": ["Victoria Public Library Grand Turk", "library Cockburn Town"],
    "town-salina": ["Town Salina Grand Turk", "salina Cockburn Town", "salt pond Grand Turk"],
    "red-salina": ["Red Salina Grand Turk", "salt pond Grand Turk"],
    "hawks-nest-salina": ["Hawks Nest Salina Grand Turk", "Hawks Nest Grand Turk"],
    "gibbs-cay": ["Gibbs Cay", "Gibbs Cay Turks Caicos", "stingray Grand Turk"],
    "jacks-shack": ["Jack's Shack Grand Turk", "Jacks Shack Turks"],
    "sand-bar": ["Sandbar Grand Turk", "Sand Bar restaurant Grand Turk"],
    "salt-raker-inn": ["Salt Raker Inn", "Saltraker Inn Grand Turk"],
    "shoprite-grocery": ["Shoprite Grand Turk"],
    "ron-jon-surf-shop": ["Ron Jon Surf Shop Grand Turk", "Ron Jon Grand Turk cruise center"],
    "harbor-house": ["Harbor House Grand Turk", "Harbour House Grand Turk"],
    "island-creations": ["Island Creations Grand Turk"],
    "medical-centre": ["Grand Turk Cockburn Town Medical Centre", "Grand Turk hospital"],
    "police-station": ["Grand Turk police station", "Royal Turks and Caicos Police Grand Turk"],
    "post-office": ["Grand Turk post office", "Cockburn Town post office"],
    "scotiabank": ["Scotiabank Grand Turk", "Scotiabank Cockburn Town"],
    "cibc-bank": ["CIBC FirstCaribbean Grand Turk", "FirstCaribbean Cockburn Town"],
    "barbies": ["Barbie's Grand Turk"],
    "freemason-lodge": ["Masonic Lodge Grand Turk", "Freemason Lodge Cockburn Town"],
    "john-glenn-exhibit": ["Friendship 7 Grand Turk", "John Glenn Grand Turk"],
    "graceway-supermarket": ["Graceway Grand Turk"],
    "grace-bay-pharmacy": ["Grace Bay Pharmacy Grand Turk"],
    "clock-tower-park": ["clock tower Grand Turk", "clock tower Cockburn Town"],
}


def get(url, tries=5):
    delay = 6
    for a in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=60) as r:
                return r.read()
        except Exception as e:
            print("retry", a, getattr(e, "code", e), url[:140], flush=True)
            if a == tries - 1:
                raise
            time.sleep(delay)
            delay *= 2


def commons(**params):
    params.update(format="json", formatversion="2")
    time.sleep(1.2)
    return json.loads(get(COMMONS + "?" + urllib.parse.urlencode(params)))


def hav(a, b):
    R = 6371000.0
    la1, lo1, la2, lo2 = map(math.radians, (a[0], a[1], b[0], b[1]))
    h = math.sin((la2 - la1) / 2) ** 2 + math.cos(la1) * math.cos(la2) * math.sin((lo2 - lo1) / 2) ** 2
    return 2 * R * math.asin(math.sqrt(h))


def strip(html):
    import re
    return re.sub(r"<[^>]+>", "", html or "").strip()[:300]


def commons_info(titles):
    if not titles:
        return []
    out = []
    for i in range(0, len(titles), 40):
        r = commons(action="query", titles="|".join(titles[i:i + 40]), prop="imageinfo|coordinates",
                    iiprop="url|extmetadata|mime", iiurlwidth="640")
        for p in r.get("query", {}).get("pages", []):
            ii = (p.get("imageinfo") or [{}])[0]
            if not ii.get("mime", "").startswith("image/jpeg") and not ii.get("mime", "").startswith("image/png"):
                continue
            md = ii.get("extmetadata", {})
            lic = strip(md.get("LicenseShortName", {}).get("value", ""))
            if not lic.lower().startswith(OK_LICENCES):
                continue
            co = (p.get("coordinates") or [None])[0]
            out.append(dict(source="commons", title=p["title"], url=ii.get("thumburl"),
                            landing=ii.get("descriptionurl"), license=lic,
                            creator=strip(md.get("Artist", {}).get("value", "")),
                            description=strip(md.get("ImageDescription", {}).get("value", "")),
                            coord=[co["lat"], co["lon"]] if co else None))
    return out


def openverse(q):
    url = OPENVERSE + "?" + urllib.parse.urlencode(dict(q=q, license_type="commercial,modification", page_size=10))
    time.sleep(4)
    res = []
    for r in json.loads(get(url)).get("results", []):
        res.append(dict(source="openverse:" + str(r.get("source")), title=r.get("title") or "", url=r.get("url"),
                        landing=r.get("foreign_landing_url"),
                        license=f"{(r.get('license') or '').upper()} {r.get('license_version') or ''}".strip(),
                        creator=r.get("creator") or "",
                        description=", ".join(t.get("name") for t in (r.get("tags") or [])[:15]), coord=None))
    return res


def main(out):
    os.makedirs(out, exist_ok=True)
    pois = {p["id"]: p for p in json.load(open("assets/pois/pois.json"))["pois"]}
    have = json.load(open("assets/photos/credits.json"))
    result = {}
    for pid, names in NAMES.items():
        if pid in have:
            continue
        p = pois.get(pid)
        here = None
        if p and p.get("locationSource") != "register-unverified":
            lon, lat = p["display"]
            here = (lat, lon)
        cands, seen = [], set()

        def add(items, why):
            for c in items:
                key = c["landing"] or c["url"]
                if not c["url"] or key in seen:
                    continue
                seen.add(key)
                c["why"] = why
                c["distanceM"] = round(hav(here, c["coord"])) if (here and c.get("coord")) else None
                cands.append(c)

        try:
            if here:
                g = commons(action="query", list="geosearch", gscoord=f"{here[0]}|{here[1]}",
                            gsradius=RADIUS, gsnamespace=6, gslimit=30)
                titles = [x["title"] for x in g.get("query", {}).get("geosearch", [])]
                add(sorted(commons_info(titles), key=lambda c: c.get("coord") and hav(here, c["coord"]) or 1e9),
                    f"geotagged within {RADIUS} m")
            for q in names:
                s = commons(action="query", list="search", srsearch=q, srnamespace=6, srlimit=10)
                add(commons_info([x["title"] for x in s.get("query", {}).get("search", [])]), "commons: " + q)
            for q in names[:2]:
                add(openverse(q), "openverse: " + q)
        except Exception as e:
            print("search failed", pid, e, flush=True)

        cands = cands[:PER_POI]
        os.makedirs(os.path.join(out, pid), exist_ok=True)
        for i, c in enumerate(cands):
            try:
                open(os.path.join(out, pid, f"{i}.jpg"), "wb").write(get(c["url"]))
                c["file"] = f"{pid}/{i}.jpg"
            except Exception as e:
                print("download failed", c["url"], e, flush=True)
            time.sleep(1.0)
        result[pid] = cands
        print(pid, len(cands), flush=True)
        json.dump(result, open(os.path.join(out, "candidates.json"), "w"), indent=1, ensure_ascii=False)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "photo-candidates")
