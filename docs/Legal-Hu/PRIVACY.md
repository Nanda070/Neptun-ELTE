# Adatvédelmi tájékoztató — Neptun ELTE

| Meta | |
|------|--|
| **Utolsó frissítés** | 2026. szeptember |
| **Termék** | Neptun ELTE (Android · iOS) |
| **Készítő / tulajdonos** | **Adnan Huseynli (Nanda)** |
| **Hatály** | Csak ez a kliens — nem az ELTE / SDA szerverei |

> A szöveg azt írja le, **amit a szoftver ténylegesen csinál** — nem üres jogi sablon.

---

## Tartalom

1. [A tájékoztató célja](#1-a-tájékoztató-célja)
2. [Ki a felelős](#2-ki-a-felelős)
3. [Mi a Neptun ELTE](#3-mi-a-neptun-elte)
4. [Bejelentkezés és adatfolyam](#4-bejelentkezés-és-adatfolyam)
5. [Az eszközön tárolt adatok](#5-az-eszközön-tárolt-adatok)
6. [Miért tároljuk](#6-miért-tároljuk)
7. [Harmadik felek](#7-harmadik-felek)
8. [Amit a projekt nem üzemeltet](#8-amit-a-projekt-nem-üzemeltet)
9. [Biztonság és ismert kockázatok](#9-biztonság-és-ismert-kockázatok)
10. [Megőrzés, kijelentkezés, törlés](#10-megőrzés-kijelentkezés-törlés)
11. [Választási lehetőségek és jogok](#11-választási-lehetőségek-és-jogok)
12. [Nemzetközi továbbítás (gyakorlati nézet)](#12-nemzetközi-továbbítás-gyakorlati-nézet)
13. [Gyermekek](#13-gyermekek)
14. [Változások](#14-változások)
15. [Kapcsolat](#15-kapcsolat)

---

## 1. A tájékoztató célja

Elmagyarázza:

- milyen információkat tárol vagy továbbít a **Neptun ELTE** mobilalkalmazás;
- **hová** kerülnek (telefonod, ELTE Neptun, GitHub, általad megnyitott oldalak);
- mit **nem** gyűjt a készítő saját háttérszerveren (nincs ilyen);
- hogyan csökkentheted vagy törölheted a helyi adatokat;
- hogyan éred el **Adnan Huseynli (Nanda)**-t a *klienssel* kapcsolatban.

Az egyetemi tanulmányi adatok az **ELTE / Neptun** szabályai alá tartoznak.

---

## 2. Ki a felelős

| Szerep | Fél |
|--------|-----|
| Nem hivatalos app készítő / tulajdonos | **Adnan Huseynli (Nanda)** |
| Neptun platform / intézményi adatok | ELTE · SDA Informatika — **nem** az app szerzője |
| Opcionális konfiguráció | GitHub (nyilvános raw fájlok) |
| OS / áruházak | Apple, Google stb. |

### Kapcsolat

| Csatorna | Érték |
|----------|--------|
| Email | [adnan.huseynli1@gmail.com](mailto:adnan.huseynli1@gmail.com) |
| Telegram | [nanda070](https://t.me/nanda070) |
| Discord | nandak070 |
| Web | [https://nanda.is-a.dev](https://nanda.is-a.dev) |
| GitHub | [Nanda070](https://github.com/Nanda070) |

---

## 3. Mi a Neptun ELTE

**Flutter** kliens az **ELTE Neptun**hoz: órarend, tárgyak/jegyek, üzenetek, fizetések, időszakok, beállítások.

| Tény | Részlet |
|------|---------|
| Hub | **csak ELTE** — `https://neptun.elte.hu` |
| Bejelentkezés után | HWEB: `hallgato1`…`hallgatoN.neptun.elte.hu` |
| Saját backend | **Nincs** |
| Push szerver | **Nincs** — helyi értesítések |
| Nyelvek | EN (alap) + HU beépítve; RU / TR GitHubról + bundled asset merge |
| Témák | Light / Dark |

Részletek: [technikai dokumentáció](../Technical/TECHNICAL.md) · index: [docs/README.md](../README.md).

---

## 4. Bejelentkezés és adatfolyam

1. Neptun azonosító + jelszó az appban.
2. ELTE portál (`neptun.elte.hu`) — webeshez hasonló belépés + **2FA** (elsősorban TOTP).
3. ToNeptunHWeb → OuterLogin → **JWT**.
4. Student REST a Neptun hosztokon; válaszok **helyi gyorsítótárba** kerülhetnek.

A készítő szerverei **semmit** nem kapnak — nincs saját login/grade API.

```
Eszköz
  ├─ flutter_secure_storage / SharedPreferences (helyi)
  ├─ HTTPS → neptun.elte.hu
  ├─ HTTPS → hallgatoN.neptun.elte.hu
  └─ HTTPS → raw.githubusercontent.com (opcionális JSON)
```

---

## 5. Az eszközön tárolt adatok

### Érzékeny session (`flutter_secure_storage`)

- jelszó;
- JWT access / refresh;
- eszköz / session cookie jellegű anyag;
- **ELTE IIG / Caesar felhasználónév + jelszó** a campus térképhez (hivatalos BIS WebView, `bis.elte.hu`), ha a felhasználó menti (Beállítások **BIS IIG bejelentkezés mentése**, alapból **be**, ha nincs beállítva; a lap checkbox alapból be). A kapcsoló kikapcsolása, a térkép menü törlése vagy teljes adatwipe törli. **Nincs 2FA** ezen az IdP-folyamon. Sosem SharedPreferences plaintextben és sosem gitben.

### Beállítások (`SharedPreferences`)

- felhasználónév (előtöltéshez kijelentkezés után is megmaradhat);
- intézet URL / API flag-ek;
- téma, nyelv, betűméret, értesítések, hét eltolás stb.

### Akadémiai gyorsítótár

Órarend, leckekönyv, fizetések, időszakok, üzenetek, félévlista, **profilavatár** (base64 JPEG a Neptun HWEB `UserInfo` / `GetUserAvatar` válaszából, drawerhez) — nem teljes offline termék.

### Értesítések

Helyi: órák, vizsgák, fizetések, időszakok.

### Opcionális GitHub letöltések

`universityNameUrlPairs.json`, nyelvi packok, téma katalógus meta.

---

## 6. Miért tároljuk

| Adat | Cél |
|------|-----|
| Hitelesítés / tokenek | Belépés és session az ELTE Neptunhoz |
| Gyorsítótár | UI megjelenítés offline / frissítések között |
| Beállítások | Téma, nyelv, értesítések |
| GitHub JSON | Nyelv/intézet frissítés új bináris nélkül |

---

## 7. Harmadik felek

### ELTE Neptun

`neptun.elte.hu`, `hallgatoN…` — login, 2FA, JWT, tanulmányi API. Adatkezelő: egyetem / Neptun üzemeltetők.

### GitHub

Nyilvános config / nyelv JSON; szokásos HTTP metaadatok.

### Általad megnyitott oldalak

pl. [nanda.is-a.dev](https://nanda.is-a.dev), Telegram, Discord — az ő szabályaik.

### Apple / Google

Telepítés / jogosultságok / áruházi analitika az ő feltételeik szerint.

---

## 8. Amit a projekt nem üzemeltet

- saját backend a jelszavakhoz / jegyekhez;
- készítői push szolgáltatás;
- in-repo hirdetési hálózat;
- dokumentált first-party analitikai pipeline.

---

## 9. Biztonság és ismert kockázatok

- Érzékeny adatok: platform secure storage.
- A HTTP kliens **bármely** TLS tanúsítványt elfogadhat (campus cert hack) → **MITM** kockázat; megbízható hálózat ajánlott.
- Kijelentkezés / session wipe: a **JWT mindig törlődik**; a felhasználónév megmaradhat előtöltéshez.
- **Jelszó kijelentkezéskor:** alapból törlődik. Ha a Beállításokban be van kapcsolva a **Jelszó megjegyzése ezen az eszközön** (alapból **ki**, **1.5.7** / kézi logout **1.5.10**), a jelszó **megmaradhat** secure storage-ban előtöltéshez (**2FA továbbra is kézi**). A kapcsoló kikapcsolása törli a jelszót.
- **Campus térkép IIG adatok (1.9.0+):** opcionális ELTE IIG felhasználónév + jelszó mentés a BIS WebView térképhez. Csak `flutter_secure_storage`. Törlődik a **BIS IIG bejelentkezés mentése** kikapcsolásakor, a térkép menüből vagy teljes wipe-nál. A WebView cookie-k (`bis.elte.hu` / `idp.elte.hu`) a rendszer cookie store-jában maradhatnak törlésig.
- Opcionális **háttér hallgató keep-alive** (Beállítások, alapból **ki**, **1.5.7+**): WorkManager / Background Fetch, ~**45 perc**, best-effort `GetNewTokens` — nem tracking/hirdetés.
- Nem hivatalos kliens — saját felelősségre.

---

## 10. Megőrzés, kijelentkezés, törlés

| Művelet | Hatás |
|---------|--------|
| Kijelentkezés / session wipe | **JWT mindig törlődik**; academic cache a wipe útvonalakon; username megmaradhat |
| Jelszó kijelentkezéskor | Alapból törlés; **megmaradhat**, ha a „jelszó megjegyzése” opt-in be van kapcsolva |
| Háttér keep-alive (opcionális) | Csak ha a felhasználó bekapcsolta; ~45 perc best-effort token refresh |
| App adat törlés (OS) | helyi tároló ürítése |
| Eltávolítás | app adatok törlés (OS szerint) |
| Neptun szerverek | ELTE megőrzési szabályai |

---

## 11. Választási lehetőségek és jogok

- Ne használd, ha nem fogadod el.
- Beállítások / kijelentkezés / törlés / uninstall.
- GDPR-szerű jogok a **kliens** helyi adataihoz: az adatok a **telefonodon** vannak; a készítőnek nincs felhőbeli Neptun-másolata.
- Tanulmányi adatok javítása: **ELTE / Neptun** hivatalos csatornái.

---

## 12. Nemzetközi továbbítás (gyakorlati nézet)

Eszköz ↔ ELTE hosztok az egyetem infrastruktúrája szerint; GitHub raw a GitHub CDN-jén keresztül mehet. A készítőnek nincs külön továbbítási csővezetéke a hitelesítőidhez.

---

## 13. Gyermekek

Neptun-hozzáféréssel rendelkező egyetemi felhasználóknak készült; **nem** 16 év alatti gyermekeknek.

---

## 14. Változások

Frissítések: `docs/Legal-Hu/PRIVACY.md`. Más nyelvek: [English](../Legal-En/PRIVACY.md) · [Русский](../Legal-Ru/PRIVACY.md). Index: [docs/README.md](../README.md).

---

## 15. Kapcsolat

**Adnan Huseynli (Nanda)** — [adnan.huseynli1@gmail.com](mailto:adnan.huseynli1@gmail.com) · Telegram [nanda070](https://t.me/nanda070) · Discord **nandak070** · [https://nanda.is-a.dev](https://nanda.is-a.dev) · GitHub [Nanda070](https://github.com/Nanda070)

Kapcsolódó: [Felhasználási feltételek](TERMS.md) · [Süti tájékoztató](COOKIES.md) · [Licenc](../LICENSE) · [Termék README](../README.md)
