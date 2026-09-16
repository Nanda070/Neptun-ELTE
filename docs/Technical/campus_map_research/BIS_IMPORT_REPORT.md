# BIS import report (ELTE Building Information System)

**Date:** 2026-09-16  
**Repo path:** `docs/Technical/campus_map_research/`  
**Status:** BIS data **imported** from an authenticated system Google Chrome session (not Cursor IDE browser). No version bump. Cookies / session tokens were **not** committed.

---

## 1. Executive summary

| Item | Result |
|------|--------|
| Unauthenticated `bis.elte.hu` | **Blocked** — redirects to ELTE IdP login |
| Authenticated Chrome (user session) | **Worked** — South 3D + North 2D tabs already open |
| Rooms imported | **Yes** — 1696 South (deli/LD) + 1974 North (eszaki/LE) = **3670** rooms with codes, names, bbox, centroid |
| Floors / buildings | **Yes** — hull polygons, floor list, campus tree via `/api/v2/entities` |
| A→B routing geometry | **Partial** — `routing` feature flag + `routing.route` API exist; scripted calls returned `null` (no path geometry saved) |
| Prior public dump (sarkozigergo + terkeptar) | Still present under `ld_south/`, `le_north/`, `eszaki_route_planner/` |

**Verdict for Neptun ELTE A→B:** Prefer **BIS room centroids + codes** as the searchable node catalog, and **sarkozigergo floor JPGs** (or BIS 2D floor plan view later) as basemaps. Do **not** wait on BIS route polylines until a live UI route can be captured or ELTE grants graph export. North still has the 2018 terkeptar OpenLayers planner as a reference implementation.

---

## 2. Auth barrier (unauthenticated)

Without cookies, every map URL redirects:

1. `https://bis.elte.hu/map/...` → `302` → `/auth/login?redirect=...`
2. `/auth/login` → `302` →  
   **IdP:** `https://idp.elte.hu/auth/saml2/idp/SSOService.php` (SAML2)  
3. Login UI: `https://idp.elte.hu/auth/module.php/eltedbauth/authpage.php`  
   Title: **«Központi bejelentkezés»** (ELTE IIG / Shibboleth-style)

Artifacts (headers redacted): `bis/api/*headers*.txt`, `bis/html/idp_or_login_final.html`.

Cursor IDE browser previously hit this wall with an empty session. **System Chrome** with the user’s faculty login bypassed it.

---

## 3. Capture method (system Chrome)

Open tabs on the machine:

| Tab | URL | Title |
|-----|-----|--------|
| South | `https://bis.elte.hu/map/budapest/lagymanyos/deli?locale=en&viewParadigm=3d` | South Building · ELTE Building Information System |
| North | `https://bis.elte.hu/map/budapest/lagymanyos/eszaki?viewParadigm=2d&locale=en` | North Building · ELTE Building Information System |

Automation used **JXA / AppleScript** `execute … javascript` against those tabs (sync `XMLHttpRequest` with the browser cookie jar). No Chrome remote-debugging port was required. Cookies were never written to the repo.

---

## 4. API surface discovered

Base: **`https://bis.elte.hu/api/v2/`** (tRPC-style batch GET).

| Procedure(s) | Role |
|--------------|------|
| `entities` | Cities, campuses, buildings, floors (+ bbox/hull) |
| `config` | Mapbox theme, labels, search UI strings |
| `features` | Enabled modules: `search`, `vr`, `issue-reporting`, **`routing`** |
| `userProfile` | Logged-in user (saved only as **`userProfile_REDACTED.json`**) |
| `privileges`, `classifications`, `fields`, `orgUnits`, `filter` | Scope tree + room ID groups by primary function |
| `search` | Meilisearch-like hits for rooms / buildings / POIs |
| `rooms.getRoomById` | Full room record (code, name, bbox, centroid, type) |
| `rooms.getRoomByScope` | Room by path e.g. `budapest/lagymanyos/deli/0/LD-0-611-01-14` |
| `routing.route` | Indoor A→B; input shape `[{scope,from,to}, scopePath, fromRef, toRef]` with `point:lng,lat` / `room:id` |
| `vrNodes` | VR hotspot nodes for a room (often empty `[]` in our calls) |
| `onboarding.getCompletedTours` | UI tours |

Payloads use a **compact index-encoded JSON** array (template object at index 0). Decoded copies live under `bis/api/*_expanded.json` and `bis/south|north/rooms_catalog.json`.

Map rendering uses **Mapbox GL** (`api.mapbox.com`) with a public `pk.` token embedded in HTML (client token, not a secret).

---

## 5. What was imported from BIS

### 5.1 South / Déli (LD) — `bis/south/`

| File | Content |
|------|---------|
| `building.json` | Building id=1, slug `deli`, hull + bbox |
| `floors.json` | 10 floors: `00` Basement … `7`, `T` Attic |
| `room_ids.json` | 1696 ids + group counts |
| `rooms_catalog.json` | Full rooms (bbox, centroid, type) |
| `rooms_educational.json` | 849 educational rooms (lighter seed) |
| `filter_building.json` / `filter_floor_*.json` | Classification groups |

**Room types (South):** educational 849, corridor 238, social 237, technical 258, administrative 70, misc 9, unknown 35.

**Codes** look like `LD-{floor}-{number}-…` (e.g. `LD-0-613-01-14`). Neptun-style mapping is still closest to public tables (`LD 0.613`) in `ld_south/rooms.json`.

### 5.2 North / Északi (LE) — `bis/north/`

| File | Content |
|------|---------|
| `building.json` | Building id=2, slug `eszaki` |
| `floors.json` | 16 floors: `-4`…`-1`, `0`…`11` |
| `rooms_catalog.json` | **1974** rooms |
| `rooms_educational.json` | 639 educational |

North in BIS has **more basement/upper floors** than the public LE JPG set (−1…7).

### 5.3 Shared API dumps — `bis/api/`

- `entities_expanded.json`, `lagymanyos_subset.json`, `config_expanded.json`, `features.json`
- `rooms_all_expanded.json` (all 3670)
- `raw/` — per-scope filter dumps from the bulk session
- `rooms_by_id_raw/` — batched `rooms.getRoomById` responses
- Search samples: `search_*_expanded.json`
- Routing trials: `routing_*` (all geometry results **null** in scripted pass)

### 5.4 HTML / JS / assets

- `bis/html/south_deli_3d.html`, `north_eszaki_2d.html` (PII redacted)
- `bis/js/` — main SPA bundles (for procedure archaeology)
- `bis/assets/icons/*.svg` — room / floor / routing markers

---

## 6. A→B / routing situation

**UI:** BIS advertises routing (feature flag + start/finish icons). User interaction earlier produced Network entries for `routing.route`.

**Scripted import:** Many `routing.route` calls with `room:id` ↔ `room:id` and `point:lng,lat` → `room:id` on South ground floor returned:

```json
[{"result":{"data":"[null]"}}]
```

One invalid trial returned a clear error: *«A route cannot end at a point»* (API is live; geometry missing or graph snap failed).

`vrNodes` for sample rooms returned empty lists.

**Implication:** We do **not** yet have a reusable indoor graph or polyline dump from BIS. Treat routing as **API-confirmed but geometry-not-captured** for this pass. Second pass: trigger a route in the Chrome UI and re-export the successful `routing.route` body, or ask BIS maintainers for graph export.

---

## 7. Already imported earlier (public sources)

Unauthenticated dumps from the prior session remain valuable:

| Path | Source | Useful for |
|------|--------|------------|
| `ld_south/` | sarkozigergo `ld.html` | Floor **JPG** plans + 134 labeled rooms + corridor schema |
| `le_north/` | sarkozigergo `le.html` | Floor JPGs + room table |
| `eszaki_route_planner/` | terkeptar campusrouting | Working **A→B** OpenLayers sample (North only, 2018) |

Credits: maps **Héger Tamás**; aggregator **Sárközi Gergő**; North planner **Eszényi Krisztián** (ELTE Cartography, 2018).

---

## 8. South vs North (comparison)

| | South (LD / deli) | North (LE / eszaki) |
|--|-------------------|---------------------|
| BIS rooms | 1696 | 1974 |
| BIS floors | 10 (`00`…`7`,`T`) | 16 (`-4`…`11`) |
| Public JPG set | Strong (−1…7 + corridor schema) | Strong (−1…7) |
| Public A→B planner | **None** | terkeptar sample |
| BIS A→B geometry | Not captured | Not captured |
| Neptun building code | LD | LE (LK often folded into North) |

---

## 9. File inventory (`campus_map_research/`)

Approximate sizes on disk after this import (~12–14 MiB total):

```
campus_map_research/
  README.md
  BIS_IMPORT_REPORT.md
  BIS_IMPORT_REPORT.ru.md
  ld_south/                 # public JPG + rooms.json
  le_north/
  eszaki_route_planner/     # North A→B sample layers
  bis/
    api/                    # entities, filters, rooms, routing trials
    south/ · north/         # building, floors, room catalogs
    html/ · js/ · assets/
    screenshots/README.md   # note only (no personal desktop shots)
```

---

## 10. Recommended path if BIS routing stays incomplete

1. **Ship search → room pin first:** use `bis/south/rooms_educational.json` (+ North) for codes/names/centroids; deep-link or WebView to BIS for users who have login.
2. **Basemap:** `ld_south/floors/*.jpg` for LD; digitize a corridor graph (schema 1–8) offline.
3. **Study** `eszaki_route_planner/` UX/graph pattern; ask Cartography before reusing GeoJSON.
4. **Optional second BIS pass:** with Chrome still logged in, manually compute a route in the UI, then re-run the AppleScript dump of `routing.route` to capture a non-null geometry sample.
5. **Do not** bundle BIS HTML/JS wholesale into the App Store build without ELTE permission; prefer derived JSON + attribution.

---

## 11. License / honesty notes

- **BIS** is an official ELTE IIG product behind university login. Research dump is for internal Neptun ELTE planning only. Redistribution of floor geometry / room inventories in a public binary needs explicit permission.
- **Mapbox** client token in saved HTML is a public `pk.` style token already exposed to browsers; rotate/replace if embedding Mapbox yourself.
- **sarkozigergo / terkeptar** are third-party student/department pages — attribute and ask before shipping artwork or GeoJSON.
- User profile fields were redacted. Session cookies and desktop screenshots were **not** committed.
- Live ELTE login / full routing graph fidelity was exercised only via the developer’s Chrome session on this date; other accounts may see different privileges.

---

## 12. Second-pass checklist (if needed)

- [~] In system Chrome, open South/North BIS and compute a visible A→B route — **deferred / won't-block Phase A** (MVP graphs are self-digitized).
- [~] Re-run in-tab capture of successful `routing.route` (+ any tile/GeoJSON assets) — **deferred / won't-block Phase A**.
- [~] Export corridor / graph layers if any appear under Network — **deferred / won't-block Phase A**.
- [ ] Crop map-only screenshots into `bis/screenshots/` (no bookmarks bar).
