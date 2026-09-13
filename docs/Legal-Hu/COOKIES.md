# Süti / helyi tárolás tájékoztató — Neptun ELTE

| Meta | |
|------|--|
| **Utolsó frissítés** | 2026. szeptember |
| **Termék** | Neptun ELTE (Android · iOS) |
| **Készítő / tulajdonos** | **Adnan Huseynli (Nanda)** |

---

## Tartalom

1. [Röviden](#1-röviden)
2. [Ez mobilalkalmazás](#2-ez-mobilalkalmazás)
3. [Helyi tárolás](#3-helyi-tárolás)
4. [HTTP cookie / Neptun session](#4-http-cookie--neptun-session)
5. [Webes hivatkozások](#5-webes-hivatkozások)
6. [GitHub](#6-github)
7. [Hogyan törölhetsz](#7-hogyan-törölhetsz)
8. [Kapcsolat](#8-kapcsolat)

---

## 1. Röviden

A Neptun ELTE **natív mobilalkalmazás**, nem weboldal. Nincs first-party cookie banner, és nincs reklámcélú cookie a készítőtől.

A bejelentkezéshez és a Neptun API-hoz **helyi session / beállítások** kellenek; a portállal való kommunikáció során **HTTP cookie jellegű** anyag is előfordulhat — hasonlóan a hivatalos webes klienshez. Ha böngészőben nyitsz meg egy linket, **annak az oldalnak** a sütijei érvényesek.

Index: [docs/README.md](../README.md)#legal · [Adatvédelem](PRIVACY.md).

---

## 2. Ez mobilalkalmazás

A repóban **nincs** `web/` cél. Nincs marketing web UI nyomkövető sütikkel.

| Mechanizmus | Tipikus használat |
|-------------|-------------------|
| `flutter_secure_storage` | jelszó, JWT, device/session cookie |
| `SharedPreferences` | username, beállítások, cache flag-ek |
| OS értesítések | helyi emlékeztetők |

Ez **alkalmazás-tároló**, nem böngészős harmadik féltől származó reklám-süti.

---

## 3. Helyi tárolás

Példák (részletek: [PRIVACY.md](PRIVACY.md)):

- téma, nyelv, betűméret, értesítés kapcsolók;
- órarend / jegyek / fizetések / üzenetek gyorsítótára;
- profilavatár base64 (drawer), ha a Neptun HWEB-ből lekérték;
- bejelentkezési állapot.

A készítő ezt nem adja el hirdetőknek.

---

## 4. HTTP cookie / Neptun session

Az ELTE Neptun portál / HWEB folyamatban a kliens session elemeket használ (JWT, device cookie a dokumentált kódban). Ezek az **eszközödön** kellenek a Neptun API-hoz, nem a készítő kereszt-webhelyes nyomkövetéséhez.

A `neptun.elte.hu` / `hallgatoN.neptun.elte.hu` domaineken a sütiket az **egyetemi szerverek** állíthatják.

---

## 5. Webes hivatkozások

Hibajelentés, kapcsolat, Telegram, Discord, mailto — rendszer böngésző / app. Példa: [https://nanda.is-a.dev](https://nanda.is-a.dev). Az ő sütijük / szabályaik érvényesek.

---

## 6. GitHub

Opcionális nyelv / intézet / téma JSON a **GitHub raw** URL-ekről. A GitHub a saját szabályai szerint láthat szokásos HTTP metaadatokat.

---

## 7. Hogyan törölhetsz

- **Kijelentkezés** az appban — jelszó / token / akadémiai cache (a username megmaradhat);
- **Alkalmazásadatok törlése** az Android / iOS beállításokban;
- **Eltávolítás**.

A külön böngészőben megnyitott oldalak sütijei a böngészőben törlendők.

---

## 8. Kapcsolat

**Adnan Huseynli (Nanda)** — [adnan.huseynli1@gmail.com](mailto:adnan.huseynli1@gmail.com) · Telegram [nanda070](https://t.me/nanda070) · Discord **nandak070** · [https://nanda.is-a.dev](https://nanda.is-a.dev)

Kapcsolódó: [Adatvédelem](PRIVACY.md) · [Feltételek](TERMS.md) · [Licenc](../LICENSE) · [README index](../README.md)

Más nyelvek: [English](../Legal-En/COOKIES.md) · [Русский](../Legal-Ru/COOKIES.md)
