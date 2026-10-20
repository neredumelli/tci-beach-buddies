#!/usr/bin/env python3
"""Search Openverse (CC-licensed images from Flickr etc.) for destinations that
still have no photo. Only licences allowing commercial use + modification
(CC0, PDM, CC BY, CC BY-SA). Output for human review:
photo-candidates/<poi-id>/<n>.jpg + candidates.json"""
import json, os, sys, time, urllib.parse, urllib.request

UA = "TCIBeachBuddies/1.0 (offline tourist app; github.com/neredumelli/tci-beach-buddies)"
API = "https://api.openverse.org/v1/images/"
QUERIES = {
    # Round 2 (20 Oct 2026): only the 27 places that still have no licensed photo,
    # with broader wording. "_general" catches untitled street/beach shots.
    "pillory-beach": ["Pillory Beach Grand Turk", "Pillory Beach", "Guanahani Beach Grand Turk", "beach Cockburn Town Grand Turk"],
    "white-sands-beach": ["White Sands Beach Grand Turk", "Grand Turk beach north"],
    "hm-prison": ["Her Majesty's Prison Grand Turk", "HM Prison Grand Turk", "Grand Turk prison museum", "old prison Turks Caicos"],
    "waterloo": ["Waterloo Grand Turk", "Governor's residence Grand Turk", "Government House Grand Turk"],
    "odd-fellows-lodge": ["Odd Fellows Lodge Grand Turk", "Oddfellows Turks Caicos"],
    "freemason-lodge": ["Masonic Lodge Grand Turk", "Freemason Grand Turk"],
    "victoria-library": ["Victoria Public Library Grand Turk", "library Cockburn Town", "Grand Turk library"],
    "town-salina": ["Town Salina Grand Turk", "salina Cockburn Town", "salt pond Grand Turk", "salt flats Grand Turk", "Grand Turk salt"],
    "red-salina": ["Red Salina Grand Turk", "pink salt pond Grand Turk"],
    "hawks-nest-salina": ["Hawks Nest Salina", "Hawks Nest Grand Turk"],
    "gibbs-cay": ["Gibbs Cay", "Gibbs Cay Grand Turk", "stingray Grand Turk", "Gibb's Cay"],
    "clock-tower-park": ["clock tower Grand Turk", "Cockburn Town clock", "Grand Turk park"],
    "sand-bar": ["Sand Bar Grand Turk", "Sandbar restaurant Grand Turk", "bar Duke Street Grand Turk"],
    "salt-raker-inn": ["Salt Raker Inn", "Saltraker Grand Turk"],
    "barbies": ["Barbie's Grand Turk", "restaurant Cockburn Town"],
    "shoprite-grocery": ["Shoprite Grand Turk", "grocery Grand Turk"],
    "graceway-supermarket": ["Graceway Grand Turk", "supermarket Grand Turk"],
    "ron-jon-surf-shop": ["Ron Jon Grand Turk", "Grand Turk cruise center shops"],
    "harbor-house": ["Harbor House Grand Turk", "Grand Turk cruise center shopping"],
    "island-creations": ["Island Creations Grand Turk", "Grand Turk craft market"],
    "cockburn-town-liquors": ["Grand Turk Liquors", "liquor store Grand Turk"],
    "grace-bay-pharmacy": ["pharmacy Grand Turk"],
    "medical-centre": ["Cockburn Town Medical Centre", "Grand Turk hospital", "Grand Turk medical"],
    "police-station": ["Grand Turk police station", "Royal Turks and Caicos Islands Police Grand Turk"],
    "post-office": ["Grand Turk post office", "Philatelic Bureau Grand Turk", "post office Cockburn Town"],
    "scotiabank": ["Scotiabank Grand Turk", "bank Cockburn Town"],
    "cibc-bank": ["CIBC Grand Turk", "FirstCaribbean Grand Turk", "bank Front Street Grand Turk"],
    "_general": ["Front Street Grand Turk", "Duke Street Grand Turk", "Cockburn Town Grand Turk", "Cockburn Town", "Grand Turk Turks and Caicos", "Grand Turk island"],
}

def get(url, tries=4):
    delay = 5
    for a in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=60) as r:
                return r.read()
        except Exception as e:
            print("retry", a, getattr(e, "code", e), url[:120])
            if a == tries - 1:
                raise
            time.sleep(delay)
            delay *= 2

def main(out):
    os.makedirs(out, exist_ok=True)
    res = {}
    for pid, qs in QUERIES.items():
        seen, cands = set(), []
        for q in qs:
            url = API + "?" + urllib.parse.urlencode(dict(q=q, license_type="commercial,modification", page_size=20))
            try:
                for r in json.loads(get(url)).get("results", []):
                    if r["id"] in seen:
                        continue
                    blob = " ".join([r.get("title") or ""] + [t.get("name") or "" for t in (r.get("tags") or [])]).lower()
                    if not any(k in blob for k in ("grand turk", "grandturk", "cockburn", "turks", "caicos", "gibbs")):
                        continue  # off-island noise (e.g. Grand Turk pubs in England)
                    seen.add(r["id"])
                    cands.append(dict(id=r["id"], title=r.get("title") or "", creator=r.get("creator") or "",
                                      license=f"{r.get('license','').upper()} {r.get('license_version') or ''}".strip(),
                                      landing=r.get("foreign_landing_url"), url=r.get("url"),
                                      tags=[t.get("name") for t in (r.get("tags") or [])][:15],
                                      source=r.get("source"), query=q))
            except Exception as e:
                print("search failed", pid, q, e)
            time.sleep(4)
        cands = cands[:(12 if pid == "_general" else 6)]
        os.makedirs(os.path.join(out, pid), exist_ok=True)
        for i, c in enumerate(cands):
            try:
                data = get(c["url"])
                fn = f"{pid}/{i}.jpg"
                open(os.path.join(out, fn), "wb").write(data)
                c["file"] = fn
            except Exception as e:
                print("download failed", c["url"], e)
            time.sleep(1.5)
        res[pid] = cands
        print(pid, len(cands))
    json.dump(res, open(os.path.join(out, "candidates.json"), "w"), indent=1, ensure_ascii=False)

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "photo-candidates")
