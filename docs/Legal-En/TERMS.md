# Terms of Use — Neptun ELTE

| Meta | |
|------|--|
| **Last updated** | September 2026 |
| **Product** | Neptun ELTE (Android · iOS) |
| **Creator / owner** | **Adnan Huseynli (Nanda)** |

> Companion to the [Privacy Policy](PRIVACY.md). Product overview and Legal index: [docs/README.md](../README.md).

---

## Contents

1. [Agreement](#1-agreement)
2. [What the software provides](#2-what-the-software-provides)
3. [Unofficial status](#3-unofficial-status)
4. [Eligibility and accounts](#4-eligibility-and-accounts)
5. [Acceptable use](#5-acceptable-use)
6. [Credentials, 2FA, and device security](#6-credentials-2fa-and-device-security)
7. [Availability, accuracy, and honesty limits](#7-availability-accuracy-and-honesty-limits)
8. [No warranty](#8-no-warranty)
9. [Limitation of liability](#9-limitation-of-liability)
10. [Indemnity (reasonable)](#10-indemnity-reasonable)
11. [Intellectual property](#11-intellectual-property)
12. [Open-source license](#12-open-source-license)
13. [Third-party services](#13-third-party-services)
14. [Updates and changes to the app](#14-updates-and-changes-to-the-app)
15. [Termination](#15-termination)
16. [Governing notes](#16-governing-notes)
17. [Contact](#17-contact)

---

## 1. Agreement

By installing, accessing, or using **Neptun ELTE**, you agree to these Terms and the [Privacy Policy](PRIVACY.md). If you do not agree, do not use the app.

Translations (same intent): [Русский](../Legal-Ru/TERMS.md) · [Magyar](../Legal-Hu/TERMS.md).

---

## 2. What the software provides

Neptun ELTE is an unofficial **Flutter** mobile client that helps you use **ELTE Neptun** on Android and iOS, including:

- timetable / calendar;
- markbook (subjects, credits, grades);
- messages;
- payments / fees;
- registration and study periods;
- settings (theme, language, local reminders).

| Scope item | Value |
|------------|--------|
| Institute | **ELTE only** — portal `https://neptun.elte.hu` |
| Not in product | Multi-university Neptun browser; official university branding |
| Backend | **No** first-party app server |
| Notifications | **Local** only |

Technical detail: [docs/Technical/TECHNICAL.md](../Technical/TECHNICAL.md).

---

## 3. Unofficial status

You acknowledge that:

- the app is **not** published by ELTE, SDA Informatika, or an official Neptun operator;
- it is **not** endorsed by those organisations unless they state otherwise;
- you must **not** present it as an official university application;
- university regulations, Neptun terms, and applicable law still apply to your Neptun account.

---

## 4. Eligibility and accounts

- You should already have legitimate Neptun access (typically as an ELTE student or authorised user).
- You may only use credentials you are authorised to use.
- The creator does not create Neptun accounts for you.

---

## 5. Acceptable use

You agree **not** to:

- share others’ credentials or attempt unauthorised access;
- attack, overload, or scrape Neptun in a harmful way;
- circumvent security controls for unlawful purposes;
- use the app to violate university rules or law;
- reverse-engineer solely to harm others or enable fraud;
- redistribute modified builds that impersonate official ELTE software.

The creator may stop distributing builds at any time.

---

## 6. Credentials, 2FA, and device security

| Topic | Your responsibility |
|-------|---------------------|
| Neptun ID / password / 2FA | Keep them secret; enable device lock |
| Authenticator apps | Protect them; do not share TOTP codes |
| Network | Prefer trusted networks (see Privacy TLS note) |
| Storage | Secrets are stored **locally**; creator has no login server |

Login flow (portal → 2FA → OuterLogin / `hallgatoN` JWT) is described in Technical docs and Privacy.

---

## 7. Availability, accuracy, and honesty limits

- Neptun may be slow, refuse load (“student web is full”), or change APIs without notice.
- Cached data can be **stale**. Verify critical deadlines in official Neptun.
- Some server-side labels (e.g. payment statuses) may remain **Hungarian**.
- Features marked thin or incomplete in Technical docs may not match the full website.
- Email OTP may be thinner in-app than on the live web (TOTP is the primary path).

---

## 8. No warranty

THE APP IS PROVIDED **“AS IS”** AND **“AS AVAILABLE”**, WITHOUT WARRANTIES OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, NON-INFRINGEMENT, OR UNINTERRUPTED / ERROR-FREE OPERATION.

Campus TLS workarounds and unofficial clients carry residual risk.

---

## 9. Limitation of liability

To the maximum extent permitted by law, **Adnan Huseynli (Nanda)** and contributors are not liable for indirect, incidental, special, consequential, exemplary, or punitive damages, or for lost grades, missed deadlines, failed payments, account lockouts, disciplinary outcomes, or data loss arising from use of (or inability to use) the app.

Your sole remedy for dissatisfaction is to stop using and uninstall the app.

Nothing here excludes liability that cannot be excluded under applicable law (e.g. mandatory consumer protections).

---

## 10. Indemnity (reasonable)

If you misuse the app or violate these Terms or university rules in a way that causes claims against the creator, you agree to defend and indemnify the creator against those claims to the extent allowed by law — excluding claims arising solely from the creator’s wilful misconduct.

---

## 11. Intellectual property

- App code and Neptun ELTE project branding belong to the creator / licensors under the project license.
- “Neptun”, ELTE marks, and university content belong to their respective owners.
- Using this client grants **no** rights to those third-party marks.

---

## 12. Open-source license

Source distribution is under the **GNU Lesser General Public License v3** (LGPL-3.0-only) — see [`docs/LICENSE`](../LICENSE) (mirrored at repo root). These Terms govern **use of the distributed app as a product** and do not replace the LGPL for code contribution/redistribution.

Historical contributors may be credited; product identity in non-Legal docs is **Nanda**. Legal owner named above.

---

## 13. Third-party services

ELTE Neptun, GitHub raw files, Apple/Google platforms, and any site you open are subject to **their** terms. The creator is not responsible for third-party outages, policy changes, or data practices.

Cookie / local-storage behaviour: [COOKIES.md](COOKIES.md).

---

## 14. Updates and changes to the app

Builds may change features, drop platforms, or break when Neptun changes. Optional language packs update from GitHub `main` when fetched — older installed packs may lag until re-download.

---

## 15. Termination

You may stop using the app anytime (logout / uninstall). Access may stop if Neptun changes, certificates fail, stores remove the app, or distribution ends. Provisions that by nature should survive (disclaimer, liability limits, IP) survive termination.

---

## 16. Governing notes

These Terms are written for an independent unofficial client. Mandatory local consumer or privacy law may give you rights that prevail over conflicting text. Prefer resolving questions by contacting the creator first.

---

## 17. Contact

**Adnan Huseynli (Nanda)**

- Email: [adnan.huseynli1@gmail.com](mailto:adnan.huseynli1@gmail.com)
- Telegram: [nanda070](https://t.me/nanda070)
- Discord: **nandak070**
- Web: [https://nanda.is-a.dev](https://nanda.is-a.dev)
- GitHub: [Nanda070](https://github.com/Nanda070)

### See also

- [Privacy Policy](PRIVACY.md)
- [Cookie & local storage](COOKIES.md)
- [Product README / Legal index](../README.md)
- [Technical documentation](../Technical/TECHNICAL.md)
