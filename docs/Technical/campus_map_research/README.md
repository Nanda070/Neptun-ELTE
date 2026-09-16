# Campus map research dump (2026-09-16)

Research material for future **2D A→B** indoor routing (LD/LE) in Neptun ELTE. **Not wired into the app yet.** Mix of public student/dept pages and an authenticated dump of official **BIS** (`bis.elte.hu`). Credit authors / ask ELTE before shipping artwork or geometry.

## Reports

| Doc | Language |
|------|----------|
| [BIS_IMPORT_REPORT.md](./BIS_IMPORT_REPORT.md) | EN — auth, APIs, rooms/floors import, A→B status, inventory, recommended path |
| [BIS_IMPORT_REPORT.ru.md](./BIS_IMPORT_REPORT.ru.md) | RU — same facts |

**BIS import status (2026-09-16):** rooms + floors + entities **imported** via system Google Chrome (logged-in faculty session). Indoor **route polylines** not captured (`routing.route` returned `null` in scripted trials). Cookies/tokens not in git.

## Sources

| URL | What |
|-----|------|
| https://sarkozigergo.web.elte.hu/terkep/ | Index: LD + LE maps + link to North route planner |
| https://sarkozigergo.web.elte.hu/terkep/ld.html | **South / Déli (LD)** — floors −1…7 + room tables |
| https://sarkozigergo.web.elte.hu/terkep/le.html | **North / Északi (LE)** — floor images + tables |
| http://terkeptar.elte.hu/~campusrouting/utvonal/ | **Existing A→B route planner for Északi only** (OpenLayers / QGIS2web, 2018, Eszényi Krisztián) |
| https://bis.elte.hu/ | Official interactive / 3D Building Information System (**ELTE login**) |
| http://kzs737.web.elte.hu/ | Older mirror copied into sarkozigergo for long-term keep |

Map artwork credit on LD page: **Héger Tamás**. Aggregator page: **Sárközi Gergő**.

## Folder layout

```
campus_map_research/
  README.md
  BIS_IMPORT_REPORT.md · BIS_IMPORT_REPORT.ru.md
  ld_south/                 ← public JPG plans + 134-room table (sarkozigergo)
  le_north/                 ← public JPG + room table
  eszaki_route_planner/     ← sample working A→B stack (North / terkeptar)
  bis/                      ← authenticated BIS dump (2026-09-16)
    api/                    entities, filters, rooms, routing trials
    south/ · north/         building, floors, rooms_catalog (+ educational subset)
    html/ · js/ · assets/
```

## BIS (official) — what we have

Captured with **system Chrome** AppleScript/JXA against open `deli` 3D + `eszaki` 2D tabs (not IDE browser).

| Building | Rooms | Floors (BIS) | Key files |
|----------|------:|--------------|-----------|
| South / deli (LD) | **1696** | `00`…`7`, `T` (10) | `bis/south/rooms_catalog.json` |
| North / eszaki (LE) | **1974** | `-4`…`11` (16) | `bis/north/rooms_catalog.json` |

- API: `https://bis.elte.hu/api/v2/` (`entities`, `filter`, `rooms.getRoomById`, `search`, `routing.route`, …).
- Unauthenticated access hits IdP `https://idp.elte.hu/auth/saml2/idp/SSOService.php`.
- A→B: feature enabled; **geometry not dumped** this pass — see import report §6.

## South building (LD) — public extract (`ld_south/`)

- **Floors:** −1 (labeled `00` on maps), 0 (Földszint), 1–7.
- **Corridor numbering schema** (`delitomb_0.jpg`): corridors **1–8**, landmarks: Aréna, Biológiai gyűjtemény, Liftek, Főlépcső, Büfé, Nyugati kapu, Duna side entrances.
- **Room codes** look like `floor-corridorxxx` (e.g. `0-821`, `2-124`). Neptun-style hint in JSON: `LD 0.821`.
- **Types seen:** Tanterem, Eloadó, Laboratórium, Számítógépes labor, Szaktanterem, Tanácsterem, Dolgozó szoba, Déli Hali, Alapítvány, …
- **Notes on page:** `"00"` = −1. floor; floor 1 map typo: shown `1.612–1.606` should be `1.112–1.106`.
- **Named halls** include Bolyai, Fejér Lipót, Rényi, Erdős Pál, Turán Pál, etc. (useful search aliases).
- **Access notes** in labels: `16 után zárt`, `zárt terem`, `nem osztható`, `csak kérésre`.

## North building (LE) — public extract (`le_north/`)

- Floor JPGs −1…7 under `le_north/floors/`.
- Room table → `le_north/rooms.json` (same schema as LD).
- **No `lk.html`** on this site; LK (Kémiai) is usually treated as part of Északi on the LE map.
- BIS North floor list is **wider** (`-4`…`11`) than these JPGs.

## Existing route planner (Északi) — functions found

URL: `http://terkeptar.elte.hu/~campusrouting/utvonal/`

| Feature | Detail |
|---------|--------|
| UI | Start (`Kezdőpont`) + Destination (`Célpont`) + **Tervezés** |
| Layers | Floor switcher −1…7; building outline + room polygons |
| Route | Drawn path + step list; hover highlights segment |
| POI search | Rooms, exits, elevators, stairs, buffets, vending (per help UI) |
| Option | “Tervezés tiltott útvonalakon is” (allow restricted paths) |
| Stack | **OpenLayers 3**, jQuery, **qgis2web** GeoJSON layers (`epulet_*`, `termek_*`) |
| Author | Eszényi Krisztián, ELTE Cartography & Geoinformatics, **2018** |

**Implication for our app:** A→B for LD can copy this *pattern* (2D floors + graph), but **South does not have this planner** on the same site — only static JPG + HTML tables. North already has vector layers we can study (do **not** re-ship without checking license / asking department).

Sample layer files saved under `eszaki_route_planner/layers/` (ground floor + basement). Room GeoJSON features in the sample often have **empty `properties`**; routing logic lives in `eszaki.js` + graph data elsewhere in full layer set.

## Suggested next steps for Neptun ELTE A→B (LD first)

1. Seed searchable nodes from `bis/south/rooms_educational.json` (centroids + `LD-…` codes); cross-check with `ld_south/rooms.json` Neptun hints.
2. Use `ld_south/floors/*.jpg` as basemaps; digitize corridor graph (schema 1–8 + lift/stair hubs).
3. Optionally study North planner UX; ask Cartography dept before reusing their GeoJSON.
4. Optional: second BIS pass after a manual UI route to capture non-null `routing.route` geometry.
5. Entry screen “Map” can open in-app LD picker without Neptun login; deep-link BIS only for users who can authenticate.

## License / honesty

- **BIS:** official ELTE IIG system behind login — research dump only; ask before App Store bundling.
- **sarkozigergo / terkeptar:** third-party; prefer attribution + permission before shipping images/GeoJSON.
- Safe short-term: deep-link / WebView to public URL or BIS with ELTEnet caveat.
- No cookies, session tokens, or personal desktop screenshots in this tree.
