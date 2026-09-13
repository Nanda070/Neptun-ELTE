# Cookie & local storage policy — Neptun ELTE

| Meta | |
|------|--|
| **Last updated** | September 2026 |
| **Product** | Neptun ELTE (Android · iOS) |
| **Creator / owner** | **Adnan Huseynli (Nanda)** |

> Honest companion to [Privacy](PRIVACY.md). Legal index: [docs/README.md](../README.md#legal).

---

## Contents

1. [Short version](#1-short-version)
2. [Why this document exists](#2-why-this-document-exists)
3. [This is a mobile app, not a website](#3-this-is-a-mobile-app-not-a-website)
4. [Local storage technologies](#4-local-storage-technologies)
5. [What is stored locally (summary)](#5-what-is-stored-locally-summary)
6. [HTTP cookies and Neptun session material](#6-http-cookies-and-neptun-session-material)
7. [Web links and third-party cookies](#7-web-links-and-third-party-cookies)
8. [GitHub and CDN requests](#8-github-and-cdn-requests)
9. [Advertising and analytics cookies](#9-advertising-and-analytics-cookies)
10. [How to clear data](#10-how-to-clear-data)
11. [Changes](#11-changes)
12. [Contact](#12-contact)

---

## 1. Short version

| Question | Answer |
|----------|--------|
| Does the app show a cookie banner? | **No** — it is not a first-party website |
| Does the creator set ad cookies? | **No** |
| Does the app store login/session data? | **Yes** — on your device (secure storage + prefs) |
| Does Neptun use cookies/session? | **Yes** — on ELTE domains during login/API use |
| If I open a link in a browser? | **That site’s** cookies apply |

Translations: [Русский](../Legal-Ru/COOKIES.md) · [Magyar](../Legal-Hu/COOKIES.md).

---

## 2. Why this document exists

App stores and users often expect a “cookie policy”. For Neptun ELTE the accurate story is:

- **local app storage** for settings and secrets;
- **HTTP session artefacts** when talking to Neptun (similar class of technology to the official web client);
- **third-party cookies only** if *you* open an external URL in a browser.

---

## 3. This is a mobile app, not a website

- There is **no `web/`** target in this repository.
- You are not visiting an in-app marketing site that drops tracking cookies.
- UI is Flutter on Android / iOS.

---

## 4. Local storage technologies

| Mechanism | Typical use |
|-----------|-------------|
| `flutter_secure_storage` | Password, JWT tokens, device/session cookie material |
| `SharedPreferences` | Username, settings, cache flags, non-secret prefs |
| App file / cache areas | Cached academic payloads as implemented |
| OS notification store | Local reminder schedules |

These are **application storage**, not browser third-party advertising cookies.

---

## 5. What is stored locally (summary)

See the Privacy Policy for full categories. Examples:

- theme (Light / Dark), language, font scale, notification toggles;
- cached timetable, grades, payments, messages, periods;
- login state and institute URL flags.

The creator does **not** sell this for advertising.

---

## 6. HTTP cookies and Neptun session material

When authenticating to ELTE Neptun, the client participates in the portal / HWEB flow documented in Technical docs:

- portal login / 2FA on `neptun.elte.hu`;
- OuterLogin / JWT on assigned `hallgatoN.neptun.elte.hu`;
- session artefacts such as a **device cookie** tied to the username (as implemented).

| Who controls cookies on Neptun domains? | **ELTE / Neptun servers** |
| Why does the app keep session material? | So **your device** can call student APIs |
| Does the creator use them for cross-site ads? | **No** |

---

## 7. Web links and third-party cookies

The app can open URLs via the system (`url_launcher`), for example:

- bug reports / site: [https://nanda.is-a.dev](https://nanda.is-a.dev);
- Telegram / Discord / `mailto:`.

Once a browser or other app opens:

1. that destination may set cookies or similar identifiers;
2. **their** privacy / cookie notices apply;
3. Neptun ELTE does not control those cookies.

---

## 8. GitHub and CDN requests

Optional language / institute / theme JSON is fetched from **GitHub raw** URLs for this project. GitHub may process standard HTTP metadata (IP, User-Agent) under GitHub’s policies. There is no separate cookie-consent UI for that fetch inside the app.

---

## 9. Advertising and analytics cookies

As of the documented codebase:

- no first-party advertising network inside the app;
- no in-repo analytics SDK that drops web-style tracking cookies;
- store / OS telemetry (if any) follows Apple / Google rules when you use their distribution.

---

## 10. How to clear data

| Action | Effect |
|--------|--------|
| Logout in app | Clears password / tokens / academic cache; username may remain for prefill |
| Clear app storage (OS settings) | Removes prefs / secure storage for the app |
| Uninstall | Removes app data (subject to OS) |
| Browser cookies for sites you opened | Clear in that browser |

---

## 11. Changes

Updates live in `docs/Legal-En/COOKIES.md`. Material edits update the **Last updated** date.

---

## 12. Contact

**Adnan Huseynli (Nanda)** — [adnan.huseynli1@gmail.com](mailto:adnan.huseynli1@gmail.com) · Telegram [nanda070](https://t.me/nanda070) · Discord **nandak070** · [https://nanda.is-a.dev](https://nanda.is-a.dev)

### See also

- [Privacy Policy](PRIVACY.md)
- [Terms of Use](TERMS.md)
- [LGPL-3.0 License](../LICENSE)
- [Product README / Legal index](../README.md)
- [Technical documentation](../Technical/TECHNICAL.md)
