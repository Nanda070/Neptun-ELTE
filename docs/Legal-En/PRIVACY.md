# Privacy Policy — Neptun ELTE

| Meta | |
|------|--|
| **Last updated** | September 2026 |
| **Product** | Neptun ELTE (Android · iOS) |
| **Creator / owner** | **Adnan Huseynli (Nanda)** |
| **Scope** | This client app only — not ELTE’s or SDA’s servers |

> Written to match **what the software actually does**. Not a copy-paste GDPR template. Where something is untested or thin in the code, we say so.

---

## Contents

1. [Purpose of this policy](#1-purpose-of-this-policy)
2. [Who is responsible](#2-who-is-responsible)
3. [What Neptun ELTE is](#3-what-neptun-elte-is)
4. [How login and APIs work (data flow)](#4-how-login-and-apis-work-data-flow)
5. [Categories of data on your device](#5-categories-of-data-on-your-device)
6. [Why we process / store that data](#6-why-we-process--store-that-data)
7. [Third parties](#7-third-parties)
8. [What this project does *not* operate](#8-what-this-project-does-not-operate)
9. [Security measures and known risks](#9-security-measures-and-known-risks)
10. [Retention, logout, uninstall](#10-retention-logout-uninstall)
11. [Your choices and rights](#11-your-choices-and-rights)
12. [International transfers (practical view)](#12-international-transfers-practical-view)
13. [Children](#13-children)
14. [Changes to this policy](#14-changes-to-this-policy)
15. [Contact](#15-contact)

---

## 1. Purpose of this policy

This document explains:

- what information the **Neptun ELTE** mobile app stores or transmits;
- **where** that information goes (your phone, ELTE Neptun, GitHub, sites you open);
- what the **creator does not** collect on a private backend (because there is none);
- how you can reduce or remove local data;
- how to reach **Adnan Huseynli (Nanda)** about the *client*.

University academic records remain under **ELTE / Neptun** rules. For those systems, follow ELTE’s own privacy notices and student administration channels.

---

## 2. Who is responsible

| Role | Party |
|------|--------|
| Unofficial app creator / owner | **Adnan Huseynli (Nanda)** |
| Neptun platform / institute data | ELTE · SDA Informatika (and related operators) — **not** this app’s author |
| Optional config hosting | GitHub (public raw files for this repo) |
| Device OS / app stores | Apple, Google, etc., if you install through them |

**Not** an official ELTE or SDA product. Do not treat this policy as ELTE’s privacy notice.

### Contact details

| Channel | Value |
|---------|--------|
| Email | [adnan.huseynli1@gmail.com](mailto:adnan.huseynli1@gmail.com) |
| Telegram | [nanda070](https://t.me/nanda070) |
| Discord | nandak070 |
| Web | [https://nanda.is-a.dev](https://nanda.is-a.dev) |
| GitHub | [Nanda070](https://github.com/Nanda070) |

---

## 3. What Neptun ELTE is

Neptun ELTE is a **Flutter** mobile client that helps students (and similar Neptun users) view:

- timetable / calendar;
- markbook (subjects, credits, grades);
- Neptun messages;
- payments / fees;
- registration and study periods;
- settings (theme, language, local notifications, etc.).

### Product facts (honest)

| Fact | Detail |
|------|--------|
| Hub | **ELTE only** — `https://neptun.elte.hu` |
| Not used | Multi-university picker; Obuda/BME-style `/ujhallgato` |
| After login | Portal may bridge **Student web** to `hallgato1`…`hallgatoN.neptun.elte.hu` (load-balanced nodes) |
| App backend | **None** — no first-party API server owned by the creator |
| Push server | **None** — reminders are **local** notifications |
| Languages | EN (default) + HU built-in; RU / TR may download from GitHub |
| Themes | Light / Dark (persisted) |

More architecture detail: [Technical documentation](../Technical/TECHNICAL.md).

---

## 4. How login and APIs work (data flow)

Understanding the flow clarifies **who sees your credentials**.

### High-level path

1. You enter **Neptun ID** + **password** in the app.
2. The app talks to the **ELTE portal** (`neptun.elte.hu`) in a way comparable to the website (form login + antiforgery; **2FA** when required).
3. **2FA:** typically a **6-digit TOTP** from an authenticator app. Email OTP (`XXX-XXXXXX`) exists on the live web; the app UI focuses on TOTP (email path may be thin / incomplete).
4. After portal auth, the client follows the **ToNeptunHWeb → OuterLogin** bridge and obtains a **JWT** (`accessToken` / refresh material as implemented).
5. Student REST calls use that session against Neptun hosts (portal / assigned **hallgatoN** as documented in the technical docs).
6. Responses (timetable, grades, …) are shown in the UI and may be **cached locally**.

### What the creator’s servers receive

**Nothing.** There is no creator-operated login or grade API. Credentials and academic JSON go between **your device** and **ELTE/Neptun** (plus optional public GitHub fetches below).

```
Device
  ├─ flutter_secure_storage / SharedPreferences (local only)
  ├─ HTTPS → neptun.elte.hu (portal login / 2FA)
  ├─ HTTPS → hallgatoN.neptun.elte.hu (student APIs after bridge)
  └─ HTTPS → raw.githubusercontent.com/… (optional language / config JSON)
```

---

## 5. Categories of data on your device

The creator does **not** run a cloud database of your Neptun account. The following lives primarily **on the phone**.

### 5.1 Credentials and session (sensitive)

Stored with **`flutter_secure_storage`** (platform keychain / keystore style storage), including as implemented:

- Neptun **password**;
- **JWT** access and refresh tokens (when issued);
- Neptun-related **device / session cookie** material the client needs to keep calling APIs.

### 5.2 Account identifiers and settings

Typically **`SharedPreferences`** (and related local prefs):

- **Username** (Neptun code) — often kept after logout for form prefill;
- institute URL / “modern API” flags;
- theme (Light / Dark), language code, font scale;
- notification toggles, haptics, week offset, calendar display filters;
- cache validity flags.

### 5.3 Academic cache (local copies of Neptun data)

Cached payloads so the UI can show last-known information when offline or between refreshes, for example:

- calendar / timetable;
- markbook / subjects;
- payments / transactions;
- periods;
- mail / messages;
- term list / selected term.

This is **not** a full offline product — freshness depends on successful sync with Neptun.

### 5.4 Notifications metadata

Local schedules for:

| Type | Typical timing (as documented) |
|------|--------------------------------|
| Classes | 10 min, 5 min, at start |
| Exams | roughly two weeks ahead |
| Payments | daily until paid |
| Periods | day before and start day |

No remote push inbox is operated by the creator.

### 5.5 Optional GitHub downloads

Public files from the project repo’s `main` branch via raw GitHub URLs, e.g.:

- `universityNameUrlPairs.json` (currently a **single** ELTE entry);
- `Languages/supportedLanguages.json` and language JSON packs (e.g. RU, TR);
- `Themes/supportedThemes.json` (catalog; UI offers built-in Light/Dark).

### 5.6 Data you send when opening links

If you open bug-report or contact links (e.g. [nanda.is-a.dev](https://nanda.is-a.dev), Telegram, Discord, email), those destinations process whatever you submit under **their** policies.

### 5.7 What we do not intentionally collect

As of the documented codebase:

- no in-app advertising ID harvest for ads;
- no first-party analytics SDK checked into the repo;
- no creator “user account” separate from Neptun.

OS vendors or stores may still collect install/crash metrics if you use their distribution channels — outside this policy’s control.

---

## 6. Why we process / store that data

| Data | Purpose |
|------|---------|
| Credentials / tokens | Authenticate to ELTE Neptun and keep a session |
| Cached academic data | Show timetable, grades, fees, messages without re-fetching every frame |
| Settings | Remember theme, language, notification preferences |
| Local notifications | Remind you of classes, exams, payments, periods |
| GitHub JSON | Update language packs / institute list without shipping a new binary |

Legal / practical basis in plain language: **you choose to use an unofficial client**; storage is **necessary to provide that client** on your device; Neptun traffic is necessary to talk to the university system you already use.

---

## 7. Third parties

### 7.1 ELTE Neptun (primary)

| Item | Detail |
|------|--------|
| Domains | `neptun.elte.hu`, `hallgatoN.neptun.elte.hu`, related Neptun hosts |
| Data | Login, 2FA, JWT, academic API responses |
| Controller | University / Neptun operators — see **their** notices |
| App role | Thin client that sends requests **you** initiate |

The creator cannot delete or correct grades on Neptun servers. Use official ELTE channels for that.

### 7.2 GitHub

| Item | Detail |
|------|--------|
| Purpose | Host public config / language JSON |
| Typical metadata | IP, User-Agent, request path (standard HTTP to GitHub) |
| Policy | [GitHub Privacy Statement](https://docs.github.com/en/site-policy/privacy-policies/github-privacy-statement) |

### 7.3 Sites and apps you open

Examples: personal site, Telegram, Discord, `mailto:`. Each has its own terms and cookies once the system browser / app opens.

### 7.4 Apple / Google / device makers

If you install via App Store, Play, sideload, or enterprise profiles, those platforms’ rules apply to distribution, permissions, and any store analytics.

---

## 8. What this project does *not* operate

- First-party backend / database for Neptun credentials or grades  
- Creator-owned push notification service  
- In-repo advertising network  
- Documented first-party analytics pipeline  

Historical notes (donate buttons, obsolete version gates, etc.) may appear as **removed** in the technical docs — they are not active product surfaces.

---

## 9. Security measures and known risks

### Measures

- Sensitive secrets intended for **platform secure storage** (`flutter_secure_storage`).
- Logout clears password / tokens / academic cache (username may remain).
- TLS is used for HTTPS endpoints in normal operation.

### Known / accepted risks (honest)

| Topic | Note |
|-------|------|
| Certificate callback | The HTTP stack may accept **any** TLS certificate to work around broken campus certs → residual **MITM** risk. Prefer trusted networks when logging in. |
| Unofficial client | APIs can change; “student web full” and similar outages are outside the creator’s control. |
| Device security | If someone unlocks your phone, local storage may be accessible depending on OS settings. Use a lock screen. |
| 2FA | Protect authenticator apps; do not share codes. |

---

## 10. Retention, logout, uninstall

| Action | Effect |
|--------|--------|
| Stay logged in | Session + cache remain until cleared or expired by Neptun |
| Logout (`dataWipe`-style) | Clears password, tokens, academic cache; **may keep username** for prefill |
| Clear app data (OS) | Removes local prefs / secure storage for the app |
| Uninstall | Removes app storage (subject to OS behaviour) |
| Neptun servers | Retain data per **ELTE** policy — independent of this app |

---

## 11. Your choices and rights

### Practical controls in the app / OS

- Do not install or use the app if you disagree with this policy or with Neptun’s rules.
- Change language, theme, and notification settings.
- Logout; clear storage; uninstall.
- Prefer official Neptun web/apps for critical actions if you distrust any unofficial client.

### Rights under EU/EEA-style privacy law (practical mapping)

Where GDPR or similar laws apply to **processing by the app creator**, note the special situation:

| Right | Practical answer for this client |
|-------|----------------------------------|
| Access / copy | Local data is on **your device**; creator has no cloud copy of your Neptun grades |
| Erasure | Logout + clear app data + uninstall removes the client’s local copy |
| Restriction / objection | Stop using the app |
| Portability | Export is not a product feature; Neptun web may offer official exports |
| University data | Exercise rights toward **ELTE / Neptun**, not via this unofficial client |

Contact the creator (below) for questions about the **client**. For academic records, contact the university.

---

## 12. International transfers (practical view)

- Your device ↔ ELTE hosts: as configured by the university (typically Hungary / their infrastructure).
- Optional GitHub raw fetches: may involve GitHub’s global CDN/infrastructure.
- The creator does not operate a separate transfer pipeline for your credentials.

---

## 13. Children

Intended for users who already have Neptun access (typically university students / staff). **Not** directed at children under 16. Do not use the app to handle a child’s Neptun account without proper authority and university rules.

---

## 14. Changes to this policy

Updates are published in this repository under `docs/Legal-En/PRIVACY.md`. The **Last updated** date will change when material edits land. Review before relying on a newer build.

Translations: [Русский](../Legal-Ru/PRIVACY.md) · [Magyar](../Legal-Hu/PRIVACY.md)

---

## 15. Contact

**Adnan Huseynli (Nanda)**

- Email: [adnan.huseynli1@gmail.com](mailto:adnan.huseynli1@gmail.com)
- Telegram: [nanda070](https://t.me/nanda070)
- Discord: **nandak070**
- Web: [https://nanda.is-a.dev](https://nanda.is-a.dev)
- GitHub: [Nanda070](https://github.com/Nanda070)

### See also

- [Terms of Use](TERMS.md)
- [Cookie & local storage policy](COOKIES.md)
- [License](../LICENSE)
- [Technical documentation](../Technical/TECHNICAL.md)
- [Product README / Legal index](../README.md)
