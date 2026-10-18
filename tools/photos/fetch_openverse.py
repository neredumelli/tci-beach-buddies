#!/usr/bin/env python3
"""Search Openverse (CC-licensed images from Flickr etc.) for destinations that
still have no photo. Only licences allowing commercial use + modification
(CC0, PDM, CC BY, CC BY-SA). Output for human review:
photo-candidates/<poi-id>/<n>.jpg + candidates.json"""
import json, os, sys, time, urllib.parse, urllib.request

UA = "TCIBeachBuddies/1.0 (offline tourist app; github.com/neredumelli/tci-beach-buddies)"
API = "https://api.openverse.org/v1/images/"
QUERIES = {
    "governors-beach": ["Governor's Beach Grand Turk", "Governors Beach Turks Caicos"],
    "pillory-beach": ["Pillory Beach Grand Turk"],
    "boaby-rock-beach": ["Boaby Rock Grand Turk"],
    "white-sands-beach": ["White Sands Beach Grand Turk"],
    "hm-prison": ["Her Majesty's Prison Grand Turk", "prison Grand Turk"],
    "st-marys": ["St Mary's Grand Turk church", "Cockburn Town church"],
    "st-thomas": ["St Thomas church Grand Turk"],
    "waterloo": ["Waterloo Grand Turk governor"],
    "odd-fellows-lodge": ["Odd Fellows Lodge Grand Turk"],
    "victoria-library": ["Victoria Public Library Grand Turk"],
    "town-salina": ["salina Grand Turk", "salt pond Cockburn Town"],
    "red-salina": ["Red Salina Grand Turk"],
    "hawks-nest-salina": ["Hawks Nest Grand Turk"],
    "gibbs-cay": ["Gibbs Cay", "Gibbs Cay stingrays"],
    "jacks-shack": ["Jack's Shack Grand Turk"],
    "sand-bar": ["Sand Bar Grand Turk"],
    "salt-raker-inn": ["Salt Raker Inn Grand Turk"],
    "bohio": ["Bohio Grand Turk"],
    "shoprite-grocery": ["Shoprite Grand Turk"],
    "ron-jon-surf-shop": ["Ron Jon Surf Shop Grand Turk"],
    "harbor-house": ["Harbor House Grand Turk"],
    "island-creations": ["Island Creations Grand Turk"],
    "medical-centre": ["Cockburn Town Medical Centre", "Grand Turk hospital"],
    "police-station": ["Grand Turk police station"],
    "post-office": ["Grand Turk post office", "Philatelic Bureau Grand Turk"],
    "scotiabank": ["Scotiabank Grand Turk"],
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
            url = API + "?" + urllib.parse.urlencode(dict(q=q, license_type="commercial,modification", page_size=8))
            try:
                for r in json.loads(get(url)).get("results", []):
                    if r["id"] in seen:
                        continue
                    seen.add(r["id"])
                    cands.append(dict(id=r["id"], title=r.get("title") or "", creator=r.get("creator") or "",
                                      license=f"{r.get('license','').upper()} {r.get('license_version') or ''}".strip(),
                                      landing=r.get("foreign_landing_url"), url=r.get("url"),
                                      tags=[t.get("name") for t in (r.get("tags") or [])][:15],
                                      source=r.get("source"), query=q))
            except Exception as e:
                print("search failed", pid, q, e)
            time.sleep(4)
        cands = cands[:5]
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
