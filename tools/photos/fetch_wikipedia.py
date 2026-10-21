#!/usr/bin/env python3
"""Download the photos used on Wikipedia articles about Grand Turk, with
their Wikimedia Commons licence details, for human review.

Output: <out>/<n>-<name>.jpg + candidates.json (title, author, licence, url).
Only files whose licence allows commercial use + modification are kept."""
import html, json, os, re, sys, time, urllib.parse, urllib.request

UA = "TCIBeachBuddies/1.0 (offline tourist app; github.com/neredumelli/tci-beach-buddies)"
ARTICLES = ["Grand_Turk_Island", "Cockburn_Town", "Grand_Turk_Lighthouse", "Turks_and_Caicos_National_Museum",
            "Gibbs_Cay", "Her_Majesty's_Prison_(Turks_and_Caicos_Islands)"]
OK = re.compile(r"^(cc0|public domain|pd|cc by(-sa)? [1-4]\.0)", re.I)


def get(url):
    for a in range(4):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=60) as r:
                return r.read()
        except Exception as e:
            print("retry", a, e, url[:100])
            time.sleep(4 * (a + 1))
    raise RuntimeError(url)


def api(site, **q):
    q.update(format="json", formatversion="2")
    return json.loads(get(f"https://{site}/w/api.php?" + urllib.parse.urlencode(q)))


def strip(s):
    return html.unescape(re.sub(r"<[^>]+>", "", s or "")).strip()


def main(out):
    os.makedirs(out, exist_ok=True)
    titles = []
    for a in ARTICLES:
        try:
            d = api("en.wikipedia.org", action="query", prop="images", titles=a, imlimit="100")
            for p in d["query"]["pages"]:
                for im in p.get("images", []):
                    t = im["title"]
                    if re.search(r"\.(jpe?g|png)$", t, re.I) and t not in titles:
                        titles.append(t)
        except Exception as e:
            print("article failed", a, e)
        time.sleep(1)
    res = []
    for i, t in enumerate(titles):
        try:
            d = api("commons.wikimedia.org", action="query", prop="imageinfo", titles=t,
                    iiprop="url|extmetadata|size", iiurlwidth="1600")
            pg = d["query"]["pages"][0]
            if "imageinfo" not in pg:
                continue
            ii = pg["imageinfo"][0]
            md = ii.get("extmetadata", {})
            lic = strip(md.get("LicenseShortName", {}).get("value"))
            c = dict(title=t, license=lic, author=strip(md.get("Artist", {}).get("value")),
                     description=strip(md.get("ImageDescription", {}).get("value"))[:300],
                     url=ii.get("descriptionurl"), width=ii.get("width"), height=ii.get("height"))
            c["usable"] = bool(OK.match(lic)) and "nc" not in lic.lower() and "nd" not in lic.lower()
            if c["usable"]:
                name = re.sub(r"[^A-Za-z0-9]+", "-", t[5:].rsplit(".", 1)[0])[:60]
                fn = f"{i:02d}-{name}.jpg"
                open(os.path.join(out, fn), "wb").write(get(ii.get("thumburl") or ii["url"]))
                c["file"] = fn
            res.append(c)
            print(t, lic, c.get("file"))
        except Exception as e:
            print("file failed", t, e)
        time.sleep(1)
    json.dump(res, open(os.path.join(out, "candidates.json"), "w"), indent=1, ensure_ascii=False)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "photo-wikipedia")
