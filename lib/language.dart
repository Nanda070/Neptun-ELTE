import 'dart:async';
import 'dart:io';
import 'dart:convert' as conv;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neptun2/storage.dart';
import 'API/api_coms.dart';
import 'Misc/popup.dart';
import 'Pages/startup_page.dart';
class AppStrings{
  static bool _hasInit = false;
  static late final String _defaultLocale;

  static List<String> _supportedLanguages = ['en', 'hu'];
  static List<String> _supportedLanguagesFlags = ['🇺🇸/🇬🇧', '🇭🇺'];
  static final Map<String, LanguagePack> _languages = {};

  static List<String> _downloadedSupportedLanguages = [];
  static List<String> _downloadedSupportedLanguagesFlags = [];
  static final Map<String, LanguagePack> _downloadedLanguages = {};

  /// Shipped with the binary so missing keys in GitHub/cache packs do not fall back to EN.
  static final Map<String, Map<String, dynamic>> _bundledLangJson = {};
  static const Map<String, String> _bundledLangAssets = {
    'ru': 'Languages/LangExtentions/Russian.json',
    'tr': 'Languages/LangExtentions/Turkish.json',
  };

  /// Call once before [initialize] so cached RU/TR packs can merge in missing keys.
  static Future<void> loadBundledLanguagePacks() async {
    for (final entry in _bundledLangAssets.entries) {
      try {
        final raw = await rootBundle.loadString(entry.value);
        final decoded = conv.json.decode(raw);
        if (decoded is Map) {
          _bundledLangJson[entry.key] = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        // Asset missing or invalid — network/cache packs still work with EN fallback.
      }
    }
  }

  static Map<String, dynamic> _mergeWithBundled(String countryId, Map<String, dynamic> lang) {
    final bundled = _bundledLangJson[countryId];
    if (bundled == null || bundled.isEmpty) {
      return lang;
    }
    final merged = Map<String, dynamic>.from(bundled);
    lang.forEach((key, value) {
      if (value != null && value.toString().trim().isNotEmpty) {
        merged[key] = value;
      }
    });
    return merged;
  }

  static void initialize(){
    if(_hasInit){
      return;
    }
    _defaultLocale = Platform.localeName.split('_')[0].toLowerCase();
    _languages.addAll({_supportedLanguages[1]: LanguagePack(
      language_flag: '🇭🇺',
      rootpage_setupPage_SelectLoginTypeHeader: 'ELTE Neptun hub — csak az Eötvös Loránd Tudományegyetem',
      rootpage_setupPage_InstitutesSelection: 'Belépés az ELTE Neptunba',
      rootpage_setupPage_InstitutesSelectionDescription: 'Neptun-kód és jelszó. Az ELTE-n a jelszó után kétlépcsős azonosítás kötelező.',
      rootpage_setupPage_UrlLogin: 'Neptun URL',
      rootpage_setupPage_UrlLoginDescription: 'Ha nincs az iskolád a listában, akkor az egyetemed neptun URL-jét használva is be tudsz lépni. Nem minden egyetemmel működik!',
      rootpage_setupPage_AppProblemReporting: 'Probléma van az appal?\nÍrd meg nekem! 👉',
      instituteSelection_setupPage_LoadingText: 'Betöltés...',
      instituteSelection_setupPage_NoNetwork: 'Nincs internet...',
      instituteSelection_setupPage_SelectValidInstitute: 'Válassz ki egy érvényes egyetemet! 😡',
      instituteSelection_setupPage_SelectInstitute: 'Válassz intézményt',
      instituteSelection_setupPage_Search: 'Keresés',
      instituteSelection_setupPage_SearchNotFound: 'Nincs találat...',
      instituteSelection_setupPage_InstituteCantFindHelpText: 'Nem találod az iskolád a listában?',
      instituteSelection_setupPage_InstituteCantFindHelpTextDescription: 'A fenti listában szereplő elemek manuálisan lettek felvéve! 😅 Így előfordulhat, hogy egyes iskolák nincsenek benne a listában.\nJelentkezz be URL használatával, ha nem találod a sulid. 😉',
      any_setupPage_GoBack: 'Vissza',
      any_setupPage_ProceedLogin: 'Tovább',
      urlLogin_setupPage_InvalidUrl: 'Írj be egy érvényes neptun URL-t! 😡',
      urlLogin_setupPage_LoginViaURlHeader: 'Belépés URL-el',
      urlLogin_setupPage_InstituteNeptunUrl: 'Egyetem neptun URL-je',
      urlLogin_setupPage_InstituteNeptunUrlInvalid: 'Ez nem egy jó neptun URL! 😡\n\nValami ilyesmit másolj ide:\nhttps://neptun-ws01.uni-pannon.hu/hallgato/login.aspx 🤫',
      urlLogin_setupPage_WhereIsURLHelper: 'Hol találom meg az URL-t?',
      urlLogin_setupPage_WhereIsURLHelperDescription: 'Keresd meg weben az egyetemed neptun weboldalát és másold be ide a fenti linket. 🔗\n\nPld: https://neptun-ws01.uni-pannon.hu/hallgato/login.aspx',
      loginPage_setupPage_InvalidCredentials: 'Érvényes adatokat adj meg! 😡',
      loginPage_setupPage_LoginHeaderText: 'Jelentkezz be',
      loginPage_setupPage_ActivityCacheInvalidHelper: 'HIBA! Lépj egyet vissza!',
      loginPage_setupPage_NeptunCode: 'Neptun kód',
      loginPage_setupPage_Password: 'Jelszó',
      loginPage_setupPage_InvalidCredentialsEntered: 'Hibás felhasználónév vagy jelszó!',
      loginPage_setupPage_2faWarning: 'Ha két lépcsős azonosítás van a fiókodon, nem fogsz tudni bejelenzkezni!',
      loginPage_setupPage_2faWarningDescription: '❌ A Neptun2 a régi Neptun mobilapp API-jait használja, amiben nem volt 2 lépcsős azonosítás. Így, ha a fiókod 2 lépcsős azonosítással van védve, a Neptun2 nem fog tudni bejelentkeztetni.\n\n🤓 Viszont, ha kikapcsolod, hiba nélkül tudod használni a Neptun2-t.\nKikapcsolni a webes neptunban, a "Saját Adatok/Beállítások"-ban tudod.',
      loginPage_setupPage_LogInButton: 'Belépés',
      loginPage_setupPage_LoginInProgress: 'Bejelentkezés...',
      loginPage_setupPage_LoginInProgressSlow: 'Neptun szervereivel lehet problémák vannak...',
      loginPage_setupPage_StudentWebFull: 'A hallgatói web tele van. Próbáld újra később.',
      loginPage_setupPage_2faInvalidCode: 'Hibás vagy lejárt 2FA kód. Próbáld újra.',
      loginPage_setupPage_ConnectingStudentWeb: 'Csatlakozás a hallgatói webhez…',
      auth_sessionExpired_PleaseSignIn: 'A munkamenet lejárt — jelentkezz be újra',
      cache_showingFromCache: 'Gyorsítótárból · frissítés függőben',
      api_monthJan_Universal: 'január',
      api_monthFeb_Universal: 'február',
      api_monthMar_Universal: 'március',
      api_monthApr_Universal: 'április',
      api_monthMay_Universal: 'május',
      api_monthJun_Universal: 'június',
      api_monthJul_Universal: 'július',
      api_monthAug_Universal: 'augusztus',
      api_monthSep_Universal: 'szeptember',
      api_monthOkt_Universal: 'október',
      api_monthNov_Universal: 'november',
      api_monthDec_Universal: 'december',
      api_dayMon_Universal: 'Hétfő',
      api_dayTue_Universal: 'Kedd',
      api_dayWed_Universal: 'Szerda',
      api_dayThu_Universal: 'Csütörtök',
      api_dayFri_Universal: 'Péntek',
      api_daySat_Universal: 'Szombat',
      api_daySun_Universal: 'Vasárnap',
      api_loadingScreenHintFriendly1_Universal: 'Elfüstölne a telefonod, ha gyorsabb lenne...',
      api_loadingScreenHintFriendly2_Universal: 'Még mindíg, jobb mint a nem létező Neptun mobilapp...',
      api_loadingScreenHintFriendly3_Universal: 'Már bármelyik milleniumban betölthet...',
      api_loadingScreenHintFriendly4_Universal: 'Áramszünet van az SDA Informatikánál...',
      api_loadingScreenHintFriendly5_Universal: 'Az SDA Informatika egy nagyon jó cég...',
      api_loadingScreenHintFriendly6_Universal: 'Tudtad? A "Neptun 2" alapja csupán 1 hét alatt készült...',
      api_loadingScreenHintFriendly7_Universal: 'Túl lassú? Panaszkodj az SDA Informatikának...',
      api_loadingScreenHint1_Universal: 'Úgy dolgoznak a Neptun szerverek, mint egy átlagos államilag finanszírozott útépítés...',
      api_loadingScreenHint2_Universal: 'Megvárjuk, amíg az SDA Informatika főnöke kávéba fullad...',
      api_loadingScreenHint3_Universal: 'Légy türelmes, egy patkány miatt zárlatos lett az egyik szerver...',
      api_loadingScreenHint4_Universal: 'Előbb hiszem el, hogy az Északi-sarkon is vannak pingvinek, minthogy a Neptun szervereire pénzt költöttek...',
      api_loadingScreenHint5_Universal: 'Neptun szerverei olyan megbízhatóak, bankolni is lehet rajtuk...',
      api_loadingScreenHint6_Universal: 'SDA jelentése: Sok Dagadt Analfabéta. Egy normális mobilappot nem sikerült összehoziuk...',
      api_loadingScreenHint7_Universal: 'Fogadni merek, mire ezt elolvasod, még mindíg a Neptun szervereire vársz...',
      api_loadingScreenHintFriendlyMini1_Universal: 'Egy pillanat...',
      api_loadingScreenHintFriendlyMini2_Universal: 'Alakul a molekula...',
      api_loadingScreenHintFriendlyMini3_Universal: 'Csak szépen lassan...',
      api_loadingScreenHintFriendlyMini4_Universal: 'Tölt valamit nagyon...',
      api_loadingScreenHintMini1_Universal: 'Na, megvan?...',
      api_loadingScreenHintMini2_Universal: 'Várjál! Nem megy ez ilyen gyorsan...',
      api_loadingScreenHintMini3_Universal: 'Nem emlékszel mit olvastál? Szedj B6 vitamint!...',
      api_noData_Universal: 'Nincs Adat',
      view_header_Calendar: 'Órarend',
      view_header_Messages: 'Üzenetek',
      view_header_Payments: 'Befizetendők',
      view_header_Periods: 'Időszakok',
      view_header_Subjects: 'Tárgyak',
      topheader_calendar_greetMessage_1to6: 'Boldog hajnalt! 🍼',
      topheader_calendar_greetMessage_6to9: 'Jó reggelt! ☕',
      topheader_calendar_greetMessage_9to13: 'Szép napot! 🍷',
      topheader_calendar_greetMessage_13to17: 'Kellemes délutánt! 🥂',
      topheader_calendar_greetMessage_17to21: 'Szép estét! 🍻',
      topheader_calendar_greetMessage_21to1: 'Jó éjszakát! 🍹',
      topheader_subjects_CreditsInSemester: 'Kredited ebben a félévben: %0🎖️',
      topheader_subjects_CreditsHeader: 'Félév: %0 · Összesen (teljesített): %1🎖️',
      topheader_payments_TotalMoneySpent: '%0Ft-ot költöttél az egyetemre 💸',
      topheader_periods_ActiveText: 'Aktuális',
      topheader_periods_ExpiredText: 'Lejárt',
      topheader_periods_FutureText: 'Jövőbeli',
      topheader_periods_MainHeader: '%0 %1, %2 %3, %4 %5 🗓️',
      topheader_messages_UnreadMessages: '%0 olvasatlan üzeneted van 💌',
      topmenu_Greet: 'Szia %0! 👋',
      topmenu_LoginPlace: 'Ide vagy bejelentkezve: 🔗\n%0',
      topmenu_buttons_Settings: '⚙ Beállítások',
      topmenu_buttons_SupportDev: '🎁 Fejlesztés támogatása',
      topmenu_buttons_Bugreport: '🐞 Hibabejelentés',
      topmenu_buttons_Logout: '🚪 Kijelentkezés',
      topmenu_buttons_LogoutSuccessToast: 'Sikeresen kijelentkeztél! 🚪',
      topmenu_buttons_Contacts: 'Kapcsolatok',
      topmenu_SemesterSelectorTitle: 'Félév',
      topmenu_SemesterToast: 'Félév átváltva: %0',
      topmenu_AccountBalance: 'Gyűjtőszámla egyenleg',
      topmenu_UnreadMessagesBadge: '%0 új üzenet',
      topmenu_NoUnreadMessages: 'Nincs új üzenet',
      topmenu_MessagesTitle: 'Üzenetek',
      topmenu_PaymentsTitle: 'Pénzügyek',
      calendarPage_FreeDay: '🥳Szabadnap!🥳',
      calendarPage_weekNav_ClassesThisWeekFull: 'Óráid ezen a héten: %0 %1. - %2 %3.',
      calendarPage_weekNav_ClassesThisWeekOneDay: 'Órád ezen a héten: %0 %1. (%2)',
      calendarPage_weekNav_ClassesThisWeekEmpty: 'Üres ez a heted! 🥳',
      calendarPage_weekNav_ClassesThisWeekLoading: 'Gondolkodunk... 🤔',
      calendarPage_weekNav_StudyWeek: '%0. oktatási hét',
      markbookPage_AverageDisplay: 'Átlagod: %0 %1',
      markbookPage_AverageScholarshipDisplay: '/30 (ösztöndíj): %0 %1',
      markbookPage_AppComputedNote: 'App-számítás — nem hivatalos Neptun KKI/GPA',
      markbookPage_NoGrades: 'nincs jegyed',
      markbookPage_Empty: '🤪Nincs Tantárgyad🤪',
      markbookPage_CompletedLine: 'Elvégezve',
      paymentPage_Empty: '😇Nem Tartozol😇',
      paymentPage_MoneyDisplay: '%0Ft',
      paymentPage_PaymentDeadlineTime: '(%0 nap van hátra)',
      paymentPage_PaymentMissedTime: '(%0 nappal lekésve)',
      payment_currencyHuf: 'Ft',
      payment_unknownTransaction: 'Ismeretlen tranzakció',
      payment_unknownStatus: 'Ismeretlen státusz',
      notif_payment_BodyNoDeadline: '%0 tartozásod van. Fizesd be! (Nincs határidő)',
      notif_payment_BodyWithDeadline: '%0 tartozásod van. Fizetési határidő: %1!',
      periodPage_Empty: '🤩Szünet Van🤩',
      periodPage_Expired: 'Lejárt: ',
      periodPage_Starts: 'Kezdődik: ',
      periodPage_ActiveDays: '(%0 nap van hátra)',
      periodPage_StartDays: '(%0 nap múlva)',
      periodPage_ExpiredDays: '(%0 napja)',
      messagePage_SentBy: 'Küldte: %0',
      messagePage_Empty: '😥Nincs Üzeneted😥',
      mail_search_Hint: 'Üzenetek keresése...',
      mail_filter_UnreadOnly: 'Olvasatlan',
      mail_filter_NoMatches: 'Nincs találat',
      whatsChanged_Header: 'Mi változott',
      whatsChanged_NewMessages: '%0 új üzenet',
      whatsChanged_GradeChanges: '%0 jegyváltozás',
      popup_case0_GhostGradeHeader: '👻 Szellemjegy 👻',
      popup_case0_SelectGrade: 'Válassz jegyet...',
      popup_caseAll_OkButton: 'Ok',
      popup_case1_SettingsHeader: '⚙ Beállítások ⚙',
      popup_case1_settingOption1_FamilyFriendlyLoadingText: 'Szókimondó betöltőszövegek',
      popup_case1_settingOption1_FamilyFriendlyLoadingTextDescription: 'Ha bekapcsolod, lecseréli a betöltő szövegeket szókimondóra.',
      popup_case1_settingOption2_ExamNotifications: 'Vizsga értesítők',
      popup_case1_settingOption2_ExamNotificationsDescription: 'Vizsgaértesítő értesítéseket küld neked a vizsga előtti 2 hétben. Hasznos, ha szereted halogatni a tanulást, vagy szimplán feledékeny vagy.',
      popup_case1_settingOption3_ClassNotifications: 'Órák előtti értesítések',
      popup_case1_settingOption3_ClassNotificationsDescription: 'Órák kezdete előtt 10 percel; 5 percel; és a kezdetük időpontjában, küld neked értesítést, hogy ne késd le őket. Hasznos, ha tudni akarod milyen órád lesz, anélkül, hogy a telódon lecsekkolnád. (pl: Okosórád van, és értesítésként látod a kövi órádat.)',
      popup_case1_settingOption4_PaymentNotifications: 'Befizetés értesítők',
      popup_case1_settingOption4_PaymentNotificationsDescription: 'Ha van befizetnivalód, értesíteni fog az app, minden nap, amíg nem fizeted be. Hasznos, ha feledékeny vagy, vagy nem szeretnéd lekésni a határidőt.',
      popup_case1_settingOption5_PeriodsNotifications: 'Időszak értesítők',
      popup_case1_settingOption5_PeriodsNotificationsDescription: 'Ha valamilyen új időszak lesz, értesíteni fog az app, az adott időszak előtt 1 nappal, és aznap fogsz értesítést kapni. Hasznos, ha nem akarsz lemaradni az adott időszakokról. (pl: tárgyfelvételi időszak)',
      popup_case1_settingOption6_AppHaptics: 'App haptika',
      popup_case1_settingOption6_AppHapticsDescription: 'Beállíthatod, hogy kapj haptikai visszajelzést az appban történő dolgokról. (Rezgés)',
      popup_case1_settingOption7_WeekOffset: 'Tanulmányi hét eltolás',
      popup_case1_settingOption7_WeekOffsetDescription: 'Ha nem jól írja ki az app az aktuális heted, itt át tudod állítani!',
      popup_case1_settingOption7_WeekOffsetAuto: 'Auto',
      popup_case1_settingBottomText_InstallOrigin: '%0 - Telepítve innen: ',
      popup_case1_settingBottomText_InstallOrigin3rdParty: 'Csomagtelepítő',
      popup_case1_settingBottomText_InstallOriginGPlay: 'Play Áruház',
      popup_case2_RateAppPopup: '⭐ Értékeld Az Appot! ⭐',
      popup_case2_RateAppPopupDescription: 'Tetszik az app? Esetleg nem? Értékeld a Play Áruházban!\n10 másodpercet vesz igénybe, és ezzel információt nyújthatsz nekem, és másoknak.',
      popup_case2_RateButton: 'Értékelem',
      popup_case3_MessagesHeader: '💌 Üzenet 💌',
      clickableText_OnCopy: 'Másolva! 📋',
      popup_case4_SubjectInfo: '📢 Óra Infó 📢',
      popup_case4_TeachedBy: 'Tanítja:',
      popup_case4_5_SubjectCode: 'Tárgykód:',
      popup_case4_5_SubjectLocation: 'Helyszín:',
      popup_case4_SubjectStartTime: 'Órakezdés:',
      popup_case5_ExamInfo: '⚠️ Vizsga Infó ⚠️',
      popup_case5_ExamStartTime: 'Vizsgaidőpont:',
      popup_case6_AccountError: '🤷 Probléma van a fiókoddal 🤷',
      popup_case6_AccountErrorDescription: 'Úgy tűnik nem tudjuk lekérni az adatokat a neptunodból.\nKérlek jelentkezz ki, majd vissza.',
      popup_case6_AccountErrorLogoutButton: 'Kijelentkezés',
      popup_case1_settingOption8_LangaugeSelection: 'App nyelv',
      popup_case1_settingOption8_LangaugeSelectionDescription: 'Válaszd ki milyen nyelven szóljon hozzád az app.',
      popup_case7_ObsolteAppVersion: '🫵 Régi App Verzió 🫵',
      popup_case7_ObsolteAppVersionDescription: 'Ez a app verzió elavult.\nA legjobb felhasználói élmény érdekében, javasoljuk, hogy frissítsd le! 😌',
      popup_case7_ButtonUpdateNow: 'Frissítés',
      popup_caseDefault_InvalidPopupState: 'Hiányos Adatok...',
      popup_case8_AcceptLanguageSuggestion: '🗣️ App Nyelvezet 🗣️',
      popup_case8_AcceptLanguageSuggestionDescription: 'Az app támogatja az általad beszélt nyelvet.\nHa gondolod állítsd be.',
      popup_case8_ButtonAcceptLang: 'Beállít',
      popup_case1_langSwap_DownloadingLang: 'Nyelv letöltése',
      popup_case1_langSwap_DownloadingLangFail: 'Nem lehet letölteni, nincs internet',
      popup_case1_settingOption9_ThemeSwap: 'App téma',
      popup_case1_settingOption9_ThemeSwapDescription: 'Válaszd ki milyen színű legyen az app',
      popup_case1_themeSwap_DownloadingThemeFail : 'Téma letöltése',
      settings_section_AppearanceLanguage: 'Megjelenés és nyelv',
      settings_section_FontScale: 'App betűméret skálázás',
      settings_section_Notifications: 'Értesítések',
      settings_section_BehaviorOther: 'Működés és egyéb',
      settings_section_CalendarFilters: 'Naptár szűrők',
      settings_calendar_ShowClasses: 'Órák megjelenítése',
      settings_calendar_ShowExams: 'Vizsgák megjelenítése',
      settings_calendar_ShowPeriods: 'Időszakok megjelenítése',
      calendar_next48h_Header: 'Következő 48 óra',
      calendar_tasks_Header: 'Feladatok / ZH',
      calendar_exams_Header: 'Vizsgák',
      calendar_periods_Header: 'Időszak bannerek',
      calendar_break_label: 'szünet',
      calendar_break_now: 'Szünet most',
      calendar_break_next: 'Következő: %0',
      calendar_break_minutes: '%0 perc',
      calendar_break_hours: '%0 óra',
      calendar_break_hoursMinutes: '%0 óra %1 perc',
      markbook_myCourses_Header: 'Felvett kurzusok',
      markbook_gradeHistory_Header: 'Jegyek más félévekből',
      payment_invoices_Header: 'Gyűjtőszámlák',
      mail_translate_EN: 'Fordítás EN',
      mail_translate_RU: 'Fordítás RU',
      mail_translate_Disclaimer: 'A fordítás gépi és pontatlan lehet.',
      mail_translate_ShowOriginal: 'Eredeti',
      topmenu_TrainingSelectorTitle: 'Képzés',
      notif_title_Exam: 'Vizsga emlékeztető!',
      notif_title_Class: 'Óra',
      notif_title_Payment: 'Befizetés',
      notif_title_Period: 'Időszak',
      notif_period_Tomorrow: '"%0" időszak lesz HOLNAP!',
      notif_period_Today: '"%0" időszak van MA!',
      courseDetail_Type: 'Típus:',
      courseDetail_Teacher: 'Tanár:',
      courseDetail_Room: 'Terem:',
      courseDetail_Subject: 'Tárgy:',
      courseDetail_Result: 'Eredmény:',
      courseDetail_Close: 'Bezárás',
      courseDetail_Unknown: 'Ismeretlen',
      courseDetail_NoResultYet: 'Nincs még kiírva',
      courseDetail_LoadingRoom: '⏳ Terem betöltése...',
      courseDetail_NoRoom: 'Nincs terem',
      courseDetail_NoTeacher: 'Nincs tanár',
      courseDetail_NoInternet: 'Nincs internet',
      courseDetail_OfflineMode: 'Offline mód',
      courseDetail_LoadError: 'Hiba a betöltésnél',
      courseDetail_OldApiUnsupported: 'Nem támogatott (Régi API)',
      courseDetail_Unsupported: 'Nem támogatott',
      courseDetail_NotSpecified: 'Nincs megadva',
      roomCode_Floor: 'Emelet',
      roomCode_Room: 'Terem',
      roomCode_Stream: 'Stream',
      roomCode_Group: 'Csoport',
      roomCode_Building_LD: 'Déli Tömb',
      roomCode_Building_LE: 'Északi Tömb',
      roomCode_Building_LK: 'Kémiai tömb (Északi)',
      markbook_creditAbbrev: 'kr',
      notif_exam_BodyToday: '"%0" tárgyból vizsgád lesz MA!',
      notif_exam_BodyTomorrow: '"%0" tárgyból vizsgád lesz HOLNAP!',
      notif_exam_BodyInDays: '"%0" tárgyból vizsgád lesz %1 nap múlva!',
      notif_class_BodyIn10Min: '"%0" órád lesz itt: "%1" 10 perc múlva!',
      notif_class_BodyIn5Min: '"%0" órád lesz itt: "%1" 5 perc múlva!',
      notif_class_BodyNow: '"%0" órád van itt: "%1"!',
      settings_fontScale_Label: 'Betűméret',
      mail_error_Prefix: 'Hiba: %0',
      mail_error_EmptyMessage: 'Üres üzenet.',
      popup_case9_2faHeader: 'Kétlépcsős azonosítás',
      popup_case9_2faDescription: 'Add meg a Microsoft Authenticator 6 jegyű TOTP kódját. Ezután az app a hallgatói webre lép OuterLogin-nal — ugyanaz az út, mint a böngészőben.',
      updater_NoInternet: 'Nincs internetkapcsolat!',
      updater_Checking: 'Frissítések keresése...',
      updater_FetchFailed: 'Nem sikerült lekérni a GitHub kiadásokat (%0)',
      updater_UpToDate: 'Az alkalmazás naprakész! (v%0)',
      updater_CheckError: 'Hiba történt a frissítés ellenőrzésekor.',
      updater_DialogTitle: 'Frissítés elérhető!',
      updater_DialogBody: 'Az alkalmazás új verziója (%0) elérhető. Szeretnéd most letölteni és telepíteni?',
      updater_Later: 'Később',
      updater_Yes: 'Igen',
      updater_NoApk: 'Nem található kompatibilis telepítőcsomag (.apk) a kiadásban.',
      updater_DownloadError: 'Hiba történt a letöltés során!',
      updater_Downloading: 'Frissítés letöltése folyamatban...',
      updater_DontClose: 'Kérlek, ne zárd be az alkalmazást.',
      api_fallback_NoTitle: 'Nincs cím',
      api_fallback_Unknown: 'Ismeretlen',
      api_fallback_UnknownSubject: 'Ismeretlen tárgy',
      api_fallback_Task: 'Feladat',
      api_fallback_NoResult: 'Nincs eredmény',
      api_fallback_UnknownPeriod: 'Ismeretlen időszak',
      api_fallback_NoTermId: 'Hiba lépett fel!\nNincs term id.',
      api_demo_Term1: 'DEMO Félév (2025/26/1)',
      api_demo_Term2: 'DEMO Félév (2025/26/2)',
      api_demo_Subject1: 'DEMO tantárgy 1',
      api_demo_GhostGrade: 'DEMO szellemjegy',
      api_demo_Course: 'DEMO kurzus',
      api_demo_Payment1: 'DEMO befizetés 1',
      api_demo_Payment2: 'DEMO befizetés 2',
      api_demo_MailSubject: 'Tárgy',
      api_demo_MailBody: 'Szöveg',
      api_demo_MailSender: 'DEMO feladó',
      api_error_InvalidUrlOrHtml: 'Hibás URL vagy a Neptun szervere weboldalt küldött válaszként',
      api_error_Network: 'Hálózati hiba: %0',
      api_error_EmptyNeptunResponse: 'Üres válasz érkezett a Neptuntól.\n\nSzerver válasza: %0',
      api_error_DownloadNetwork: 'Hálózati hiba a letöltés során:\n%0',
      mail_preview_TapToLoadBody: 'A szöveg letöltéséhez kattints ide...',
      rootpage_setupPage_IcsImport: 'Naptár használat',
      rootpage_setupPage_IcsImportDescription: 'Betudod importálni a neptunos órarendedet, viszont ha az órarendedben változás történik, arról te nem fogsz értesülni.\nCsak annak ajánlott, aki semmilyen módon nem tud bejelentkezni!',
      rootpage_setupPage_OtherUsageModes: 'Offline módok',
      calendarLogin_setupPage_InvalidFile: 'Hibás ICS fájl! 😵',
      calendarLogin_setupPage_LoginViaICSHeader: 'Naptár használat',
      calendarLogin_setupPage_WhereIsICSHelper: 'Nem tudod merre találod a neptunos órarended (.ics fájl)?',
      calendarLogin_setupPage_WhereIsICSHelperDescription: 'Lépj a "Saját adatok" > "Beállítások" > "Naptár export"\nHa pontos heti megjelenítést akarsz akkor, szeptember 1.-jétől (xxxx.09.01), a következő év szeptember 1.-éig (xxxx.09.01) exportáld ki a naptárad! 🤓',
      calendarLogin_setupPage_ImportICSFileHelpText: 'Kattits a gombra, majd válaszd ki a frissen letöltött órarend fájlodat!',
      calendarLogin_setupPage_ImportICSFileButton: 'Feltöltés'
    )});
    //---
    _languages.addAll({_supportedLanguages[0]: LanguagePack(
      language_flag: '🇺🇸/🇬🇧',
      rootpage_setupPage_SelectLoginTypeHeader: 'ELTE Neptun hub — only Eötvös Loránd University',
      rootpage_setupPage_InstitutesSelection: 'Sign in with ELTE Neptun',
      rootpage_setupPage_InstitutesSelectionDescription: 'Use your Neptun code and password. ELTE requires two-factor authentication after password.',
      rootpage_setupPage_UrlLogin: 'Neptun URL',
      rootpage_setupPage_UrlLoginDescription: 'If you can\'t find your university in the list, you can enter the Neptun URL of your school to log in. This might not work with all universities!',
      rootpage_setupPage_AppProblemReporting: 'Is there a problem with the app?\nTell me! 👉',
      instituteSelection_setupPage_LoadingText: 'Loading...',
      instituteSelection_setupPage_NoNetwork: 'No network...',
      instituteSelection_setupPage_SelectValidInstitute: 'Select a valid institute! 😡',
      instituteSelection_setupPage_SelectInstitute: 'Select institute',
      instituteSelection_setupPage_Search: 'Search',
      instituteSelection_setupPage_SearchNotFound: 'Nothing found...',
      instituteSelection_setupPage_InstituteCantFindHelpText: 'Can\'t find your school in the list?',
      instituteSelection_setupPage_InstituteCantFindHelpTextDescription: 'Items in the list above were added manually! 😅 It is possible that some institutes are missing from it.\nYou can log in via URL if you can\'t find your school. 😉',
      any_setupPage_GoBack: 'Back',
      any_setupPage_ProceedLogin: 'Proceed',
      urlLogin_setupPage_InvalidUrl: 'Enter a valid Neptun URL! 😡',
      urlLogin_setupPage_LoginViaURlHeader: 'Login via URL',
      urlLogin_setupPage_InstituteNeptunUrl: 'Institute Neptun URL',
      urlLogin_setupPage_InstituteNeptunUrlInvalid: 'This is not a valid Neptun URL! 😡\n\nPaste something similar here:\nhttps://neptun-ws01.uni-pannon.hu/hallgato/login.aspx 🤫',
      urlLogin_setupPage_WhereIsURLHelper: 'Where do I find the URL?',
      urlLogin_setupPage_WhereIsURLHelperDescription: 'Go to your school\'s Neptun website, and paste the link from up top. 🔗\n\nEx: https://neptun-ws01.uni-pannon.hu/hallgato/login.aspx',
      loginPage_setupPage_InvalidCredentials: 'Provide valid credentials! 😡',
      loginPage_setupPage_LoginHeaderText: 'Log in',
      loginPage_setupPage_ActivityCacheInvalidHelper: 'ERROR! Please go back!',
      loginPage_setupPage_NeptunCode: 'Neptun code',
      loginPage_setupPage_Password: 'Password',
      loginPage_setupPage_InvalidCredentialsEntered: 'Invalid username or password!',
      loginPage_setupPage_2faWarning: 'If you have multi-factor authentication enabled on your account, you won\'t be able to log in!',
      loginPage_setupPage_2faWarningDescription: '❌ Neptun2 uses the old Neptun mobile app API, which didn\'t include multi-factor authentication. If your account is protected by it, you won\'t be able to log in via Neptun2.\n\n🤓 But you can turn it off, and you will be able to use Neptun2 without a problem.\nTo turn it off, go to "My Data/Settings" in Neptun web.',
      loginPage_setupPage_LogInButton: 'Login',
      loginPage_setupPage_LoginInProgress: 'Logging in...',
      loginPage_setupPage_LoginInProgressSlow: 'Neptun servers are having a hard time...',
      loginPage_setupPage_StudentWebFull: 'Student web is full. Please try again later.',
      loginPage_setupPage_2faInvalidCode: 'Wrong or expired 2FA code. Try again.',
      loginPage_setupPage_ConnectingStudentWeb: 'Connecting to Student web…',
      auth_sessionExpired_PleaseSignIn: 'Session expired — please sign in again',
      cache_showingFromCache: 'From cache · refresh pending',
      api_monthJan_Universal: 'january',
      api_monthFeb_Universal: 'february',
      api_monthMar_Universal: 'march',
      api_monthApr_Universal: 'april',
      api_monthMay_Universal: 'may',
      api_monthJun_Universal: 'june',
      api_monthJul_Universal: 'july',
      api_monthAug_Universal: 'august',
      api_monthSep_Universal: 'september',
      api_monthOkt_Universal: 'october',
      api_monthNov_Universal: 'november',
      api_monthDec_Universal: 'december',
      api_dayMon_Universal: 'Monday',
      api_dayTue_Universal: 'Tuesday',
      api_dayWed_Universal: 'Wednesday',
      api_dayThu_Universal: 'Thursday',
      api_dayFri_Universal: 'Friday',
      api_daySat_Universal: 'Saturday',
      api_daySun_Universal: 'Sunday',
      api_loadingScreenHintFriendly1_Universal: 'Your phone would go up in flames if this was faster...',
      api_loadingScreenHintFriendly2_Universal: 'Still better than the non-existent Neptun mobile app...',
      api_loadingScreenHintFriendly3_Universal: 'Loads in any millennium now...',
      api_loadingScreenHintFriendly4_Universal: 'There\'s a power outage at SDA informatics...',
      api_loadingScreenHintFriendly5_Universal: 'SDA informatics is an amazing company...',
      api_loadingScreenHintFriendly6_Universal: 'Did you know? "Neptun 2" was created in about 1 week...',
      api_loadingScreenHintFriendly7_Universal: 'Too slow? Send a complaint to SDA informatics...',
      api_loadingScreenHint1_Universal: 'The Neptun servers are working as hard as an average Hungarian construction worker...',
      api_loadingScreenHint2_Universal: 'We are waiting until the CEO of SDA informatics drowns in coffee...',
      api_loadingScreenHint3_Universal: 'Be patient, the servers are down because a rat got into them...',
      api_loadingScreenHint4_Universal: 'I\'m more likely to believe there are penguins at the North Pole than SDA informatics has spent money on Neptun servers...',
      api_loadingScreenHint5_Universal: 'Neptun servers are so reliable, I would do my banking on them...',
      api_loadingScreenHint6_Universal: 'SDA meaning: Sok Dagadt Analfabéta, aka: Many Fat Analfabetics. They couldn\'t create a usable mobile app...',
      api_loadingScreenHint7_Universal: 'I would bet my house that you are still reading this because it is still loading...',
      api_loadingScreenHintFriendlyMini1_Universal: 'Just a second...',
      api_loadingScreenHintFriendlyMini2_Universal: 'We are getting there...',
      api_loadingScreenHintFriendlyMini3_Universal: 'Easy does it...',
      api_loadingScreenHintFriendlyMini4_Universal: 'It\'s really loading something...',
      api_loadingScreenHintMini1_Universal: 'So, found it?...',
      api_loadingScreenHintMini2_Universal: 'Hold up! It can\'t do it that fast...',
      api_loadingScreenHintMini3_Universal: 'Forgot what you just read? Try taking B6 vitamins!...',
      api_noData_Universal: 'No Data',
      view_header_Calendar: 'Calendar',
      view_header_Messages: 'Messages',
      view_header_Payments: 'Payments',
      view_header_Periods: 'Periods',
      view_header_Subjects: 'Subjects',
      topheader_calendar_greetMessage_1to6: 'Merry midnight! 🍼',
      topheader_calendar_greetMessage_6to9: 'Good morning! ☕',
      topheader_calendar_greetMessage_9to13: 'Good day! 🍷',
      topheader_calendar_greetMessage_13to17: 'Good afternoon! 🥂',
      topheader_calendar_greetMessage_17to21: 'Good evening! 🍻',
      topheader_calendar_greetMessage_21to1: 'Good night! 🍹',
      topheader_subjects_CreditsInSemester: 'Your credits this semester: %0🎖️',
      topheader_subjects_CreditsHeader: 'This term: %0 · Accumulated (completed): %1🎖️',
      topheader_payments_TotalMoneySpent: 'You have spent %0Huf on university 💸',
      topheader_periods_ActiveText: 'Active',
      topheader_periods_ExpiredText: 'Expired',
      topheader_periods_FutureText: 'Future',
      topheader_periods_MainHeader: '%0 %1, %2 %3, %4 %5 🗓️',
      topheader_messages_UnreadMessages: 'You have %0 unread messages 💌',
      topmenu_Greet: 'Hello %0! 👋',
      topmenu_LoginPlace: 'You are logged in here: 🔗\n%0',
      topmenu_buttons_Settings: '⚙ Settings',
      topmenu_buttons_SupportDev: '🎁 Support developer',
      topmenu_buttons_Bugreport: '🐞 Bug report',
      topmenu_buttons_Logout: '🚪 Log out',
      topmenu_buttons_LogoutSuccessToast: 'You have logged out successfully! 🚪',
      topmenu_buttons_Contacts: 'Contacts',
      topmenu_SemesterSelectorTitle: 'Semester',
      topmenu_SemesterToast: 'Semester switched: %0',
      topmenu_AccountBalance: 'Account balance',
      topmenu_UnreadMessagesBadge: '%0 new messages',
      topmenu_NoUnreadMessages: 'No new messages',
      topmenu_MessagesTitle: 'Messages',
      topmenu_PaymentsTitle: 'Payments',
      calendarPage_FreeDay: '🥳Free Day!🥳',
      calendarPage_weekNav_ClassesThisWeekFull: 'Classes this week: %0 %1. - %2 %3.',
      calendarPage_weekNav_ClassesThisWeekOneDay: 'Class this week: %0 %1. (%2)',
      calendarPage_weekNav_ClassesThisWeekEmpty: 'This week is empty! 🥳',
      calendarPage_weekNav_ClassesThisWeekLoading: 'Thinking... 🤔',
      calendarPage_weekNav_StudyWeek: '%0. education week',
      markbookPage_AverageDisplay: 'Average: %0 %1',
      markbookPage_AverageScholarshipDisplay: '/30 (scholarship index): %0 %1',
      markbookPage_AppComputedNote: 'App-computed — not official Neptun KKI/GPA',
      markbookPage_NoGrades: 'You have no grades',
      markbookPage_Empty: '🤪You don\'t have any subjects🤪',
      markbookPage_CompletedLine: 'Completed',
      paymentPage_Empty: '😇All paid😇',
      paymentPage_MoneyDisplay: '%0Huf',
      paymentPage_PaymentDeadlineTime: '(%0 days remaining)',
      paymentPage_PaymentMissedTime: '(%0 days since deadline)',
      payment_currencyHuf: 'HUF',
      payment_unknownTransaction: 'Unknown transaction',
      payment_unknownStatus: 'Unknown status',
      notif_payment_BodyNoDeadline: 'You owe %0. Please pay! (No deadline)',
      notif_payment_BodyWithDeadline: 'You owe %0. Pay by: %1!',
      periodPage_Empty: '🤩Break time🤩',
      periodPage_Expired: 'Expired: ',
      periodPage_Starts: 'Starts: ',
      periodPage_ActiveDays: '(%0 days remaining)',
      periodPage_StartDays: '(in %0 days)',
      periodPage_ExpiredDays: '(%0 days ago)',
      messagePage_SentBy: 'Sent by: %0',
      messagePage_Empty: '😥You don\'t have any messages😥',
      mail_search_Hint: 'Search messages...',
      mail_filter_UnreadOnly: 'Unread',
      mail_filter_NoMatches: 'No matching messages',
      whatsChanged_Header: 'What’s changed',
      whatsChanged_NewMessages: '%0 new messages',
      whatsChanged_GradeChanges: '%0 grade changes',
      popup_case0_GhostGradeHeader: '👻 Ghost grade 👻',
      popup_case0_SelectGrade: 'Select grade...',
      popup_caseAll_OkButton: 'Ok',
      popup_case1_SettingsHeader: '⚙ Settings ⚙',
      popup_case1_settingOption1_FamilyFriendlyLoadingText: 'Outspoken loading texts',
      popup_case1_settingOption1_FamilyFriendlyLoadingTextDescription: 'If you turn this on, loading texts will become outspoken.',
      popup_case1_settingOption2_ExamNotifications: 'Exam notifications',
      popup_case1_settingOption2_ExamNotificationsDescription: 'Exam notifications will send you notifications 2 weeks beforehand. It is useful if you like procrastinating studying, or tend to forget.',
      popup_case1_settingOption3_ClassNotifications: 'Notifications before classes',
      popup_case1_settingOption3_ClassNotificationsDescription: 'It will send you notifications 10 minutes, 5 minutes, and at the start of the class, so you won\'t miss them. Useful if you want to know what class you are going to have beforehand, without needing to check your phone (ex: You have a smartwatch)',
      popup_case1_settingOption4_PaymentNotifications: 'Payment notifications',
      popup_case1_settingOption4_PaymentNotificationsDescription: 'If you have payments due, the app will notify you every day, until they are paid. Useful if you tend to forget, or just don\'t want to miss a due date.',
      popup_case1_settingOption5_PeriodsNotifications: 'Period notifications',
      popup_case1_settingOption5_PeriodsNotificationsDescription: 'If a new period is about to become active, the app will notify you 1 day before the given period, and the day they become active. Useful if you don\'t want to miss something important tied to periods (ex: class registration period).',
      popup_case1_settingOption6_AppHaptics: 'App haptics',
      popup_case1_settingOption6_AppHapticsDescription: 'You can set if you want the app to give you haptic feedback (vibrate).',
      popup_case1_settingOption7_WeekOffset: 'Study week offset',
      popup_case1_settingOption7_WeekOffsetDescription: 'If you have issues with the current study week, you can offset it to the correct week!',
      popup_case1_settingOption7_WeekOffsetAuto: 'Auto',
      popup_case1_settingBottomText_InstallOrigin: '%0 - Installed from: ',
      popup_case1_settingBottomText_InstallOrigin3rdParty: 'Package Installer',
      popup_case1_settingBottomText_InstallOriginGPlay: 'Google Play',
      popup_case2_RateAppPopup: '⭐ Rate The App! ⭐',
      popup_case2_RateAppPopupDescription: 'Do you like the app? Do you hate it? Rate it on Google Play!\nIt takes about 10 seconds, and it gives me and other users feedback.',
      popup_case2_RateButton: 'Rate it',
      popup_case3_MessagesHeader: '💌 Message 💌',
      clickableText_OnCopy: 'Copied! 📋',
      popup_case4_SubjectInfo: '📢 Subject Info 📢',
      popup_case4_TeachedBy: 'Taught by:',
      popup_case4_5_SubjectCode: 'Subject code:',
      popup_case4_5_SubjectLocation: 'Location:',
      popup_case4_SubjectStartTime: 'Subject start time:',
      popup_case5_ExamInfo: '⚠️ Exam Info ⚠️',
      popup_case5_ExamStartTime: 'Exam start time:',
      popup_case6_AccountError: '🤷 There is an issue with your account 🤷',
      popup_case6_AccountErrorDescription: 'It seems like we can\'t fetch data from your Neptun.\nPlease log out, and log back in.',
      popup_case6_AccountErrorLogoutButton: 'Logout',
      popup_case1_settingOption8_LangaugeSelection: 'App language',
      popup_case1_settingOption8_LangaugeSelectionDescription: 'Select what language the app shall speak to you.',
      popup_case7_ObsolteAppVersion: '🫵 Old App Version 🫵',
      popup_case7_ObsolteAppVersionDescription: 'This version of the app is outdated.\nPlease consider updating the app for the best user experience! 😌',
      popup_case7_ButtonUpdateNow: 'Update',
      popup_caseDefault_InvalidPopupState: 'Missing Data...',
      popup_case8_AcceptLanguageSuggestion: '🗣️ App Language 🗣️',
      popup_case8_AcceptLanguageSuggestionDescription: 'The app supports the language you are speaking.\nChange it if you want to.',
      popup_case8_ButtonAcceptLang: 'Change',
      popup_case1_langSwap_DownloadingLang: 'Downloading language',
      popup_case1_langSwap_DownloadingLangFail: 'Can\'t download, no internet',
      popup_case1_settingOption9_ThemeSwap: 'App theme',
      popup_case1_settingOption9_ThemeSwapDescription: 'Select how the app should look like',
      popup_case1_themeSwap_DownloadingThemeFail: 'Downloading theme',
      settings_section_AppearanceLanguage: 'Appearance & language',
      settings_section_FontScale: 'App font size scaling',
      settings_section_Notifications: 'Notifications',
      settings_section_BehaviorOther: 'Behavior & other',
      settings_section_CalendarFilters: 'Calendar filters',
      settings_calendar_ShowClasses: 'Show classes',
      settings_calendar_ShowExams: 'Show exams',
      settings_calendar_ShowPeriods: 'Show periods',
      calendar_next48h_Header: 'Next 48 hours',
      calendar_tasks_Header: 'Tasks / midterms',
      calendar_exams_Header: 'Exams',
      calendar_periods_Header: 'Period banners',
      calendar_break_label: 'break',
      calendar_break_now: 'Break now',
      calendar_break_next: 'Next: %0',
      calendar_break_minutes: '%0 min',
      calendar_break_hours: '%0 h',
      calendar_break_hoursMinutes: '%0 h %1 min',
      markbook_myCourses_Header: 'My courses',
      markbook_gradeHistory_Header: 'Grades from other terms',
      payment_invoices_Header: 'Collective invoices',
      mail_translate_EN: 'Translate EN',
      mail_translate_RU: 'Translate RU',
      mail_translate_Disclaimer: 'Machine translation may be inaccurate.',
      mail_translate_ShowOriginal: 'Original',
      topmenu_TrainingSelectorTitle: 'Training',
      notif_title_Exam: 'Exam reminder!',
      notif_title_Class: 'Class',
      notif_title_Payment: 'Payment',
      notif_title_Period: 'Period',
      notif_period_Tomorrow: '"%0" period starts TOMORROW!',
      notif_period_Today: '"%0" period is TODAY!',
      courseDetail_Type: 'Type:',
      courseDetail_Teacher: 'Teacher:',
      courseDetail_Room: 'Room:',
      courseDetail_Subject: 'Subject:',
      courseDetail_Result: 'Result:',
      courseDetail_Close: 'Close',
      courseDetail_Unknown: 'Unknown',
      courseDetail_NoResultYet: 'Not posted yet',
      courseDetail_LoadingRoom: '⏳ Loading room...',
      courseDetail_NoRoom: 'No room',
      courseDetail_NoTeacher: 'No teacher',
      courseDetail_NoInternet: 'No internet',
      courseDetail_OfflineMode: 'Offline mode',
      courseDetail_LoadError: 'Failed to load',
      courseDetail_OldApiUnsupported: 'Not supported (legacy API)',
      courseDetail_Unsupported: 'Not supported',
      courseDetail_NotSpecified: 'Not specified',
      roomCode_Floor: 'Floor',
      roomCode_Room: 'Room',
      roomCode_Stream: 'Stream',
      roomCode_Group: 'Group',
      roomCode_Building_LD: 'Southern Building',
      roomCode_Building_LE: 'Northern Building',
      roomCode_Building_LK: 'Chemistry block (Northern Building)',
      markbook_creditAbbrev: 'cr',
      notif_exam_BodyToday: '"%0" exam is TODAY!',
      notif_exam_BodyTomorrow: '"%0" exam is TOMORROW!',
      notif_exam_BodyInDays: '"%0" exam in %1 days!',
      notif_class_BodyIn10Min: '"%0" class at "%1" in 10 minutes!',
      notif_class_BodyIn5Min: '"%0" class at "%1" in 5 minutes!',
      notif_class_BodyNow: '"%0" class now at "%1"!',
      settings_fontScale_Label: 'Font scale',
      mail_error_Prefix: 'Error: %0',
      mail_error_EmptyMessage: 'Empty message.',
      popup_case9_2faHeader: 'Two-step authentication',
      popup_case9_2faDescription: 'Enter the 6-digit TOTP from Microsoft Authenticator. After that the app opens Student web (hallgato) via OuterLogin — same path as the browser.',
      updater_NoInternet: 'No internet connection!',
      updater_Checking: 'Checking for updates...',
      updater_FetchFailed: 'Could not fetch GitHub releases (%0)',
      updater_UpToDate: 'App is up to date! (v%0)',
      updater_CheckError: 'Error while checking for updates.',
      updater_DialogTitle: 'Update available!',
      updater_DialogBody: 'A new version (%0) is available. Download and install now?',
      updater_Later: 'Later',
      updater_Yes: 'Yes',
      updater_NoApk: 'No compatible installer package (.apk) found in the release.',
      updater_DownloadError: 'Download failed!',
      updater_Downloading: 'Downloading update...',
      updater_DontClose: 'Please do not close the app.',
      api_fallback_NoTitle: 'No title',
      api_fallback_Unknown: 'Unknown',
      api_fallback_UnknownSubject: 'Unknown subject',
      api_fallback_Task: 'Task',
      api_fallback_NoResult: 'No result',
      api_fallback_UnknownPeriod: 'Unknown period',
      api_fallback_NoTermId: 'An error occurred!\nNo term id.',
      api_demo_Term1: 'DEMO Term (2025/26/1)',
      api_demo_Term2: 'DEMO Term (2025/26/2)',
      api_demo_Subject1: 'DEMO subject 1',
      api_demo_GhostGrade: 'DEMO ghost grade',
      api_demo_Course: 'DEMO course',
      api_demo_Payment1: 'DEMO payment 1',
      api_demo_Payment2: 'DEMO payment 2',
      api_demo_MailSubject: 'Subject',
      api_demo_MailBody: 'Body',
      api_demo_MailSender: 'DEMO sender',
      api_error_InvalidUrlOrHtml: 'Invalid URL or Neptun returned a web page instead of data',
      api_error_Network: 'Network error: %0',
      api_error_EmptyNeptunResponse: 'Empty response from Neptun.\n\nServer response: %0',
      api_error_DownloadNetwork: 'Network error while downloading:\n%0',
      mail_preview_TapToLoadBody: 'Tap here to download the message body...',
      rootpage_setupPage_IcsImport: 'Calendar Use',
      rootpage_setupPage_IcsImportDescription: 'You can load your timetable, if it was a calendar, but if the university makes a change with it, you will not have the latest one.\nYou should only use this, if you can not login into the app!',
      rootpage_setupPage_OtherUsageModes: 'Offline modes',
      calendarLogin_setupPage_InvalidFile: 'Bad ICS file! 😵',
      calendarLogin_setupPage_LoginViaICSHeader: 'Calendar use',
      calendarLogin_setupPage_WhereIsICSHelper: 'Dont know where you can find your neptun timetable (.ics file)?',
      calendarLogin_setupPage_WhereIsICSHelperDescription: 'Go to "My data" > "Settings" > "Calendar export"\nIf you want accurate data, select exporting from september 1. (xxxx.09.01), to the next years september 1. (xxxx.09.01)! 🤓',
      calendarLogin_setupPage_ImportICSFileHelpText: 'Click on the button, then select your freshly downloaded timetable file!',
      calendarLogin_setupPage_ImportICSFileButton: 'Import'
    )});

    final downloadedSupportedLanguages = DataCache.getDownloadedSupportedLanguages();
    final List<String> converted = DataCache.getDownloadedSupportedLanguagesData();
    for(int i = 0; i < downloadedSupportedLanguages.length && i < converted.length; i++){
      try {
        LanguagePack.fromJson(downloadedSupportedLanguages[i], converted[i], (){});
      } catch (_) {}
    }

    _hasInit = true;
  }

  static String popupLangPrev_Header = "ERROR";
  static String popupLangPrev_Description = "ERROR";
  static String popupLangPrev_Button = "ERROR";
  static String popupLangPrev_ObtainingLang = "ERROR";
  static String popupLangPrev_ObtainingLangError = "ERROR";

  static void setupPopupPreviews(LanguagePack pack){
    popupLangPrev_Header = pack.popup_case8_AcceptLanguageSuggestion;
    popupLangPrev_Description = pack.popup_case8_AcceptLanguageSuggestionDescription;
    popupLangPrev_Button = pack.popup_case8_ButtonAcceptLang;
    popupLangPrev_ObtainingLang = pack.popup_case1_langSwap_DownloadingLang;
    popupLangPrev_ObtainingLangError = pack.popup_case1_langSwap_DownloadingLangFail;
  }

  static String getCurrentLangCode(){
    return _getCurrentLang();
  }

  /// Neptun LCID for API content language (EN/HU/RU/TR).
  static int getNeptunLcid(){
    switch (_getCurrentLang()) {
      case 'hu':
        return 1038;
      case 'ru':
        return 1049;
      case 'tr':
        return 1055;
      case 'en':
      default:
        return 1033;
    }
  }

  static LanguagePack getLanguagePack(){
    return _getLangPack(_getCurrentLang());
  }

  /// True for empty / legacy HU / localized "no room" placeholders (not real rooms).
  static bool isMissingRoomValue(String? value) {
    if (value == null) return true;
    final v = value.trim();
    if (v.isEmpty || v == 'NULL') return true;
    if (v == 'Nincs terem' || v == 'No room' || v == 'Nincs megadva' || v == 'Not specified') return true;
    try {
      final lang = getLanguagePack();
      if (v == lang.courseDetail_NoRoom || v == lang.courseDetail_NotSpecified) return true;
    } catch (_) {}
    return false;
  }

  /// True for empty / legacy HU / localized "no teacher" placeholders.
  static bool isMissingTeacherValue(String? value) {
    if (value == null) return true;
    final v = value.trim();
    if (v.isEmpty || v == 'NULL') return true;
    if (v == 'Nincs tanár' || v == 'No teacher' || v == 'Nincs megadva' || v == 'Not specified') return true;
    try {
      final lang = getLanguagePack();
      if (v == lang.courseDetail_NoTeacher || v == lang.courseDetail_NotSpecified) return true;
    } catch (_) {}
    return false;
  }

  /// Maps known app-generated placeholders to the active language; leaves Neptun content as-is.
  static String localizeCourseDetailValue(String? value, {required String Function(LanguagePack) placeholder}) {
    if (value == null || value.trim().isEmpty || value == 'NULL') {
      return placeholder(getLanguagePack());
    }
    final mapped = mapKnownCourseDetailPlaceholder(value.trim());
    if (mapped != null) return mapped;
    return value.trim();
  }

  /// Returns localized text for known app placeholders, or null if [value] is real Neptun content.
  static String? mapKnownCourseDetailPlaceholder(String value) {
    final v = value.trim();
    final lang = getLanguagePack();
    if (v == 'Nincs terem' || v == 'No room' || v == lang.courseDetail_NoRoom) {
      return lang.courseDetail_NoRoom;
    }
    if (v == 'Nincs tanár' || v == 'No teacher' || v == lang.courseDetail_NoTeacher) {
      return lang.courseDetail_NoTeacher;
    }
    if (v == 'Nincs megadva' || v == 'Not specified' || v == lang.courseDetail_NotSpecified) {
      return lang.courseDetail_NotSpecified;
    }
    if (v == 'Nincs internet' || v == 'No internet' || v == lang.courseDetail_NoInternet) {
      return lang.courseDetail_NoInternet;
    }
    if (v == 'Offline mód' || v == 'Offline mode' || v == lang.courseDetail_OfflineMode) {
      return lang.courseDetail_OfflineMode;
    }
    if (v == 'Hiba a betöltésnél' || v == 'Failed to load' || v == lang.courseDetail_LoadError) {
      return lang.courseDetail_LoadError;
    }
    if (v == 'Nem támogatott (Régi API)' || v == 'Not supported (legacy API)' || v == lang.courseDetail_OldApiUnsupported) {
      return lang.courseDetail_OldApiUnsupported;
    }
    if (v == 'Nem támogatott' || v == 'Not supported' || v == lang.courseDetail_Unsupported) {
      return lang.courseDetail_Unsupported;
    }
    return null;
  }

  static String _getCurrentLang(){
    final selectedCode = DataCache.getUserSelectedLanguageCode();
    if (selectedCode != null && selectedCode.isNotEmpty) {
      return selectedCode;
    }
    final currLangId = DataCache.getUserSelectedLanguage();
    final selectonList = _supportedLanguages + _downloadedSupportedLanguages;
    if(currLangId == null || currLangId == -1 || currLangId >= selectonList.length || currLangId < 0){
      // Default language is English; use device locale only if we have that pack.
      if (selectonList.contains(_defaultLocale)) {
        return _defaultLocale;
      }
      return 'en';
    }
    return selectonList[currLangId];
  }

  static LanguagePack _getLangPack(String id){
    final selectonList = Map<String, LanguagePack>.from(_languages);
    selectonList.addAll(_downloadedLanguages);
    if(!selectonList.containsKey(id)){
      if (selectonList.containsKey('en')) {
        return selectonList['en']!; // default to english
      }
      return selectonList['hu']!;
    }
    return selectonList[id]!;
  }

  static String getStringWithParams(String base, List<dynamic> params){
    String result = "" + base;
    for(int i = 0; i < params.length; i++){
      result = result.replaceAll('%$i', '${params[i].toString()}');
    }
    return result;
  }

  static String getStringPrural(String one, String multiple, int determiner){
    return determiner <= 0 ? one : multiple;
  }

  static List<String> getAllLangFlags(){
    return _supportedLanguagesFlags + _downloadedSupportedLanguagesFlags;
  }

  static List<String> getAllLangCodes(){
    return _supportedLanguages + _downloadedSupportedLanguages;
  }

  static List<String> getAllDownloadedCodes(){
    return _downloadedSupportedLanguages;
  }

  static List<String> getLanguageNamesWithFlag(){
    final List<String> list = [];
    final List<LangPackMap> langNames = Language.getAllLanguagesWithNative();
    final obtainedList = _supportedLanguages + _downloadedSupportedLanguages;
    for(var item in obtainedList){
      for(var item2 in langNames){
        if(item2.langId == item){
          list.add("${item2.langFlag} ${item2.langName}");
          break;
        }
      }
    }
    for(var item in langNames){
      if(obtainedList.contains(item.langId)){
        continue;
      }
      list.add("${item.langFlag} ${item.langName}");
    }
    return list;
  }

  static bool hasLanguageDownloaded(String id){
    final list = _supportedLanguages + _downloadedSupportedLanguages;
    return list.contains(id);
  }

  static void saveDownloadedLanguageData(){
    DataCache.setDownloadedSupportedLanguages(_downloadedSupportedLanguages);
    final List<String> converted = [];
    for(var item in _downloadedLanguages.values){
      converted.add(LanguagePack.toJson(item));
    }
    DataCache.setDownloadedSupportedLanguagesData(converted);
  }

  static Timer _loadDownloadLangTimer = Timer(Duration.zero, () {});

  static Future<void> loadDownloadedLanguageData(BuildContext context)async{
    final downloadedSupportedLanguages = DataCache.getDownloadedSupportedLanguages();
    final List<String> converted = DataCache.getDownloadedSupportedLanguagesData();
    for(int i = 0; i < downloadedSupportedLanguages.length; i++){
      LanguagePack.fromJson(downloadedSupportedLanguages[i], converted[i], ()async{
        if(!DataCache.getHasNetwork()){
          return;
        }
        await Language.getLanguagePackById(await Language.getAllLanguages(), downloadedSupportedLanguages[i]);
        _loadDownloadLangTimer.cancel();
        _loadDownloadLangTimer = Timer(const Duration(seconds: 3), (){
          saveDownloadedLanguageData();
          Navigator.popUntil(context, (route) => route.willHandlePopInternally);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const Splitter()),
          );
        });
      });
    }
  }
}

class LanguagePack{
  final String language_flag;

  final String rootpage_setupPage_SelectLoginTypeHeader;
  final String rootpage_setupPage_InstitutesSelection;
  final String rootpage_setupPage_InstitutesSelectionDescription;
  final String rootpage_setupPage_UrlLogin;
  final String rootpage_setupPage_UrlLoginDescription;
  final String rootpage_setupPage_AppProblemReporting;

  final String rootpage_setupPage_OtherUsageModes;
  final String rootpage_setupPage_IcsImport;
  final String rootpage_setupPage_IcsImportDescription;

  final String instituteSelection_setupPage_LoadingText;
  final String instituteSelection_setupPage_NoNetwork;
  final String instituteSelection_setupPage_SelectValidInstitute;
  final String instituteSelection_setupPage_SelectInstitute;
  final String instituteSelection_setupPage_Search;
  final String instituteSelection_setupPage_SearchNotFound;
  final String instituteSelection_setupPage_InstituteCantFindHelpText;
  final String instituteSelection_setupPage_InstituteCantFindHelpTextDescription;

  final String any_setupPage_GoBack;
  final String any_setupPage_ProceedLogin;

  final String urlLogin_setupPage_InvalidUrl;
  final String urlLogin_setupPage_LoginViaURlHeader;
  final String urlLogin_setupPage_InstituteNeptunUrl;
  final String urlLogin_setupPage_InstituteNeptunUrlInvalid;
  final String urlLogin_setupPage_WhereIsURLHelper;
  final String urlLogin_setupPage_WhereIsURLHelperDescription;

  final String calendarLogin_setupPage_InvalidFile;
  final String calendarLogin_setupPage_LoginViaICSHeader;
  final String calendarLogin_setupPage_WhereIsICSHelper;
  final String calendarLogin_setupPage_WhereIsICSHelperDescription;
  final String calendarLogin_setupPage_ImportICSFileHelpText;
  final String calendarLogin_setupPage_ImportICSFileButton;

  final String loginPage_setupPage_InvalidCredentials;
  final String loginPage_setupPage_LoginHeaderText;
  final String loginPage_setupPage_ActivityCacheInvalidHelper;
  final String loginPage_setupPage_NeptunCode;
  final String loginPage_setupPage_Password;
  final String loginPage_setupPage_InvalidCredentialsEntered;
  final String loginPage_setupPage_2faWarning;
  final String loginPage_setupPage_2faWarningDescription;
  final String loginPage_setupPage_LogInButton;
  final String loginPage_setupPage_LoginInProgress;
  final String loginPage_setupPage_LoginInProgressSlow;
  final String loginPage_setupPage_StudentWebFull;
  final String loginPage_setupPage_2faInvalidCode;
  final String loginPage_setupPage_ConnectingStudentWeb;
  final String auth_sessionExpired_PleaseSignIn;
  final String cache_showingFromCache;

  final String api_monthJan_Universal;
  final String api_monthFeb_Universal;
  final String api_monthMar_Universal;
  final String api_monthApr_Universal;
  final String api_monthMay_Universal;
  final String api_monthJun_Universal;
  final String api_monthJul_Universal;
  final String api_monthAug_Universal;
  final String api_monthSep_Universal;
  final String api_monthOkt_Universal;
  final String api_monthNov_Universal;
  final String api_monthDec_Universal;

  final String api_dayMon_Universal;
  final String api_dayTue_Universal;
  final String api_dayWed_Universal;
  final String api_dayThu_Universal;
  final String api_dayFri_Universal;
  final String api_daySat_Universal;
  final String api_daySun_Universal;

  final String api_loadingScreenHintFriendly1_Universal;
  final String api_loadingScreenHintFriendly2_Universal;
  final String api_loadingScreenHintFriendly3_Universal;
  final String api_loadingScreenHintFriendly4_Universal;
  final String api_loadingScreenHintFriendly5_Universal;
  final String api_loadingScreenHintFriendly6_Universal;
  final String api_loadingScreenHintFriendly7_Universal;

  final String api_loadingScreenHint1_Universal;
  final String api_loadingScreenHint2_Universal;
  final String api_loadingScreenHint3_Universal;
  final String api_loadingScreenHint4_Universal;
  final String api_loadingScreenHint5_Universal;
  final String api_loadingScreenHint6_Universal;
  final String api_loadingScreenHint7_Universal;

  final String api_loadingScreenHintFriendlyMini1_Universal;
  final String api_loadingScreenHintFriendlyMini2_Universal;
  final String api_loadingScreenHintFriendlyMini3_Universal;
  final String api_loadingScreenHintFriendlyMini4_Universal;

  final String api_loadingScreenHintMini1_Universal;
  final String api_loadingScreenHintMini2_Universal;
  final String api_loadingScreenHintMini3_Universal;

  final String api_noData_Universal;

  final String view_header_Calendar;
  final String view_header_Subjects;
  final String view_header_Payments;
  final String view_header_Periods;
  final String view_header_Messages;

  final String topheader_calendar_greetMessage_1to6;
  final String topheader_calendar_greetMessage_6to9;
  final String topheader_calendar_greetMessage_9to13;
  final String topheader_calendar_greetMessage_13to17;
  final String topheader_calendar_greetMessage_17to21;
  final String topheader_calendar_greetMessage_21to1;

  final String topheader_subjects_CreditsInSemester;
  final String topheader_subjects_CreditsHeader;

  final String topheader_payments_TotalMoneySpent;

  final String topheader_periods_ActiveText;
  final String topheader_periods_ExpiredText;
  final String topheader_periods_FutureText;
  final String topheader_periods_MainHeader;

  final String topheader_messages_UnreadMessages;

  final String topmenu_Greet;
  final String topmenu_LoginPlace;
  final String topmenu_buttons_Settings;
  final String topmenu_buttons_SupportDev;
  final String topmenu_buttons_Bugreport;
  final String topmenu_buttons_Logout;
  final String topmenu_buttons_LogoutSuccessToast;
  final String topmenu_buttons_Contacts;
  final String topmenu_SemesterSelectorTitle;
  final String topmenu_SemesterToast;
  final String topmenu_AccountBalance;
  final String topmenu_UnreadMessagesBadge;
  final String topmenu_NoUnreadMessages;
  final String topmenu_MessagesTitle;
  final String topmenu_PaymentsTitle;

  final String calendarPage_weekNav_StudyWeek;
  final String calendarPage_weekNav_ClassesThisWeekFull;
  final String calendarPage_weekNav_ClassesThisWeekOneDay;
  final String calendarPage_weekNav_ClassesThisWeekLoading;
  final String calendarPage_weekNav_ClassesThisWeekEmpty;
  final String calendarPage_FreeDay;

  final String markbookPage_AverageDisplay;
  final String markbookPage_AverageScholarshipDisplay;
  final String markbookPage_AppComputedNote;
  final String markbookPage_NoGrades;
  final String markbookPage_Empty;
  final String markbookPage_CompletedLine;

  final String paymentPage_Empty;
  final String paymentPage_MoneyDisplay;
  final String paymentPage_PaymentMissedTime;
  final String paymentPage_PaymentDeadlineTime;
  final String payment_currencyHuf;
  final String payment_unknownTransaction;
  final String payment_unknownStatus;
  final String notif_payment_BodyNoDeadline;
  final String notif_payment_BodyWithDeadline;

  final String periodPage_Empty;
  final String periodPage_Expired;
  final String periodPage_Starts;
  final String periodPage_ExpiredDays;
  final String periodPage_StartDays;
  final String periodPage_ActiveDays;

  final String messagePage_SentBy;
  final String messagePage_Empty;
  final String mail_search_Hint;
  final String mail_filter_UnreadOnly;
  final String mail_filter_NoMatches;
  final String whatsChanged_Header;
  final String whatsChanged_NewMessages;
  final String whatsChanged_GradeChanges;

  final String popup_case0_GhostGradeHeader;
  final String popup_caseAll_OkButton;
  final String popup_case0_SelectGrade;

  final String popup_case1_SettingsHeader;
  final String popup_case1_settingOption1_FamilyFriendlyLoadingText;
  final String popup_case1_settingOption1_FamilyFriendlyLoadingTextDescription;
  final String popup_case1_settingOption2_ExamNotifications;
  final String popup_case1_settingOption2_ExamNotificationsDescription;
  final String popup_case1_settingOption3_ClassNotifications;
  final String popup_case1_settingOption3_ClassNotificationsDescription;
  final String popup_case1_settingOption4_PaymentNotifications;
  final String popup_case1_settingOption4_PaymentNotificationsDescription;
  final String popup_case1_settingOption5_PeriodsNotifications;
  final String popup_case1_settingOption5_PeriodsNotificationsDescription;
  final String popup_case1_settingOption6_AppHaptics;
  final String popup_case1_settingOption6_AppHapticsDescription;
  final String popup_case1_settingOption7_WeekOffset;
  final String popup_case1_settingOption7_WeekOffsetDescription;
  final String popup_case1_settingOption7_WeekOffsetAuto;
  final String popup_case1_settingBottomText_InstallOrigin;
  final String popup_case1_settingBottomText_InstallOriginGPlay;
  final String popup_case1_settingBottomText_InstallOrigin3rdParty;
  final String popup_case1_settingOption8_LangaugeSelection;
  final String popup_case1_settingOption8_LangaugeSelectionDescription;
  final String popup_case1_settingOption9_ThemeSwap;
  final String popup_case1_settingOption9_ThemeSwapDescription;

  final String popup_case2_RateAppPopup;
  final String popup_case2_RateAppPopupDescription;
  final String popup_case2_RateButton;

  final String popup_case3_MessagesHeader;
  final String clickableText_OnCopy;

  final String popup_case4_SubjectInfo;
  final String popup_case4_TeachedBy;
  final String popup_case4_5_SubjectCode;
  final String popup_case4_5_SubjectLocation;
  final String popup_case4_SubjectStartTime;

  final String popup_case5_ExamInfo;
  final String popup_case5_ExamStartTime;

  final String popup_case6_AccountError;
  final String popup_case6_AccountErrorDescription;
  final String popup_case6_AccountErrorLogoutButton;

  final String popup_case7_ObsolteAppVersion;
  final String popup_case7_ObsolteAppVersionDescription;
  final String popup_case7_ButtonUpdateNow;

  final String popup_case8_AcceptLanguageSuggestion;
  final String popup_case8_AcceptLanguageSuggestionDescription;
  final String popup_case8_ButtonAcceptLang;

  final String popup_case1_langSwap_DownloadingLang;
  final String popup_case1_langSwap_DownloadingLangFail;
  final String popup_case1_themeSwap_DownloadingThemeFail;

  final String settings_section_AppearanceLanguage;
  final String settings_section_FontScale;
  final String settings_section_Notifications;
  final String settings_section_BehaviorOther;
  final String settings_section_CalendarFilters;
  final String settings_calendar_ShowClasses;
  final String settings_calendar_ShowExams;
  final String settings_calendar_ShowPeriods;
  final String calendar_next48h_Header;
  final String calendar_tasks_Header;
  final String calendar_exams_Header;
  final String calendar_periods_Header;
  final String calendar_break_label;
  final String calendar_break_now;
  final String calendar_break_next;
  final String calendar_break_minutes;
  final String calendar_break_hours;
  final String calendar_break_hoursMinutes;
  final String markbook_myCourses_Header;
  final String markbook_gradeHistory_Header;
  final String payment_invoices_Header;
  final String mail_translate_EN;
  final String mail_translate_RU;
  final String mail_translate_Disclaimer;
  final String mail_translate_ShowOriginal;
  final String topmenu_TrainingSelectorTitle;
  final String notif_title_Exam;
  final String notif_title_Class;
  final String notif_title_Payment;
  final String notif_title_Period;
  final String notif_period_Tomorrow;
  final String notif_period_Today;
  final String courseDetail_Type;
  final String courseDetail_Teacher;
  final String courseDetail_Room;
  final String courseDetail_Subject;
  final String courseDetail_Result;
  final String courseDetail_Close;
  final String courseDetail_Unknown;
  final String courseDetail_NoResultYet;
  final String courseDetail_LoadingRoom;
  final String courseDetail_NoRoom;
  final String courseDetail_NoTeacher;
  final String courseDetail_NoInternet;
  final String courseDetail_OfflineMode;
  final String courseDetail_LoadError;
  final String courseDetail_OldApiUnsupported;
  final String courseDetail_Unsupported;
  final String courseDetail_NotSpecified;
  final String roomCode_Floor;
  final String roomCode_Room;
  final String roomCode_Stream;
  final String roomCode_Group;
  final String roomCode_Building_LD;
  final String roomCode_Building_LE;
  final String roomCode_Building_LK;
  final String markbook_creditAbbrev;
  final String notif_exam_BodyToday;
  final String notif_exam_BodyTomorrow;
  final String notif_exam_BodyInDays;
  final String notif_class_BodyIn10Min;
  final String notif_class_BodyIn5Min;
  final String notif_class_BodyNow;
  final String settings_fontScale_Label;
  final String mail_error_Prefix;
  final String mail_error_EmptyMessage;
  final String popup_case9_2faHeader;
  final String popup_case9_2faDescription;
  final String updater_NoInternet;
  final String updater_Checking;
  final String updater_FetchFailed;
  final String updater_UpToDate;
  final String updater_CheckError;
  final String updater_DialogTitle;
  final String updater_DialogBody;
  final String updater_Later;
  final String updater_Yes;
  final String updater_NoApk;
  final String updater_DownloadError;
  final String updater_Downloading;
  final String updater_DontClose;
  final String api_fallback_NoTitle;
  final String api_fallback_Unknown;
  final String api_fallback_UnknownSubject;
  final String api_fallback_Task;
  final String api_fallback_NoResult;
  final String api_fallback_UnknownPeriod;
  final String api_fallback_NoTermId;
  final String api_demo_Term1;
  final String api_demo_Term2;
  final String api_demo_Subject1;
  final String api_demo_GhostGrade;
  final String api_demo_Course;
  final String api_demo_Payment1;
  final String api_demo_Payment2;
  final String api_demo_MailSubject;
  final String api_demo_MailBody;
  final String api_demo_MailSender;
  final String api_error_InvalidUrlOrHtml;
  final String api_error_Network;
  final String api_error_EmptyNeptunResponse;
  final String api_error_DownloadNetwork;
  final String mail_preview_TapToLoadBody;

  final String popup_caseDefault_InvalidPopupState;

  const LanguagePack({
    required this.language_flag,
    required this.rootpage_setupPage_SelectLoginTypeHeader,
    required this.rootpage_setupPage_InstitutesSelection,
    required this.rootpage_setupPage_InstitutesSelectionDescription,
    required this.rootpage_setupPage_UrlLogin,
    required this.rootpage_setupPage_UrlLoginDescription,
    required this.rootpage_setupPage_AppProblemReporting,
    required this.instituteSelection_setupPage_LoadingText,
    required this.instituteSelection_setupPage_NoNetwork,
    required this.instituteSelection_setupPage_SelectValidInstitute,
    required this.instituteSelection_setupPage_SelectInstitute,
    required this.instituteSelection_setupPage_Search,
    required this.instituteSelection_setupPage_SearchNotFound,
    required this.instituteSelection_setupPage_InstituteCantFindHelpText,
    required this.instituteSelection_setupPage_InstituteCantFindHelpTextDescription,
    required this.any_setupPage_GoBack,
    required this.any_setupPage_ProceedLogin,
    required this.urlLogin_setupPage_InvalidUrl,
    required this.urlLogin_setupPage_LoginViaURlHeader,
    required this.urlLogin_setupPage_InstituteNeptunUrl,
    required this.urlLogin_setupPage_InstituteNeptunUrlInvalid,
    required this.urlLogin_setupPage_WhereIsURLHelper,
    required this.urlLogin_setupPage_WhereIsURLHelperDescription,
    required this.loginPage_setupPage_InvalidCredentials,
    required this.loginPage_setupPage_LoginHeaderText,
    required this.loginPage_setupPage_ActivityCacheInvalidHelper,
    required this.loginPage_setupPage_NeptunCode,
    required this.loginPage_setupPage_Password,
    required this.loginPage_setupPage_InvalidCredentialsEntered,
    required this.loginPage_setupPage_2faWarning,
    required this.loginPage_setupPage_2faWarningDescription,
    required this.loginPage_setupPage_LogInButton,
    required this.loginPage_setupPage_LoginInProgress,
    required this.loginPage_setupPage_LoginInProgressSlow,
    required this.loginPage_setupPage_StudentWebFull,
    required this.loginPage_setupPage_2faInvalidCode,
    required this.loginPage_setupPage_ConnectingStudentWeb,
    required this.auth_sessionExpired_PleaseSignIn,
    required this.cache_showingFromCache,
    required this.api_monthJan_Universal,
    required this.api_monthFeb_Universal,
    required this.api_monthMar_Universal,
    required this.api_monthApr_Universal,
    required this.api_monthJun_Universal,
    required this.api_monthMay_Universal,
    required this.api_monthJul_Universal,
    required this.api_monthAug_Universal,
    required this.api_monthSep_Universal,
    required this.api_monthOkt_Universal,
    required this.api_monthNov_Universal,
    required this.api_monthDec_Universal,
    required this.api_dayMon_Universal,
    required this.api_dayTue_Universal,
    required this.api_dayWed_Universal,
    required this.api_dayThu_Universal,
    required this.api_dayFri_Universal,
    required this.api_daySat_Universal,
    required this.api_daySun_Universal,
    required this.api_loadingScreenHintFriendly1_Universal,
    required this.api_loadingScreenHintFriendly2_Universal,
    required this.api_loadingScreenHintFriendly3_Universal,
    required this.api_loadingScreenHintFriendly4_Universal,
    required this.api_loadingScreenHintFriendly5_Universal,
    required this.api_loadingScreenHintFriendly6_Universal,
    required this.api_loadingScreenHintFriendly7_Universal,
    required this.api_loadingScreenHint1_Universal,
    required this.api_loadingScreenHint2_Universal,
    required this.api_loadingScreenHint3_Universal,
    required this.api_loadingScreenHint4_Universal,
    required this.api_loadingScreenHint5_Universal,
    required this.api_loadingScreenHint6_Universal,
    required this.api_loadingScreenHint7_Universal,
    required this.api_loadingScreenHintFriendlyMini1_Universal,
    required this.api_loadingScreenHintFriendlyMini2_Universal,
    required this.api_loadingScreenHintFriendlyMini3_Universal,
    required this.api_loadingScreenHintFriendlyMini4_Universal,
    required this.api_loadingScreenHintMini1_Universal,
    required this.api_loadingScreenHintMini2_Universal,
    required this.api_loadingScreenHintMini3_Universal,
    required this.api_noData_Universal,
    required this.view_header_Calendar,
    required this.view_header_Messages,
    required this.view_header_Payments,
    required this.view_header_Periods,
    required this.view_header_Subjects,
    required this.topheader_calendar_greetMessage_1to6,
    required this.topheader_calendar_greetMessage_6to9,
    required this.topheader_calendar_greetMessage_9to13,
    required this.topheader_calendar_greetMessage_13to17,
    required this.topheader_calendar_greetMessage_17to21,
    required this.topheader_calendar_greetMessage_21to1,
    required this.topheader_subjects_CreditsInSemester,
    required this.topheader_subjects_CreditsHeader,
    required this.topheader_payments_TotalMoneySpent,
    required this.topheader_periods_ActiveText,
    required this.topheader_periods_ExpiredText,
    required this.topheader_periods_FutureText,
    required this.topheader_periods_MainHeader,
    required this.topheader_messages_UnreadMessages,
    required this.topmenu_buttons_Bugreport,
    required this.topmenu_buttons_Logout,
    required this.topmenu_buttons_Settings,
    required this.topmenu_buttons_SupportDev,
    required this.topmenu_Greet,
    required this.topmenu_LoginPlace,
    required this.topmenu_buttons_LogoutSuccessToast,
    required this.topmenu_buttons_Contacts,
    required this.calendarPage_FreeDay,
    required this.calendarPage_weekNav_ClassesThisWeekFull,
    required this.calendarPage_weekNav_ClassesThisWeekOneDay,
    required this.calendarPage_weekNav_StudyWeek,
    required this.calendarPage_weekNav_ClassesThisWeekEmpty,
    required this.calendarPage_weekNav_ClassesThisWeekLoading,
    required this.markbookPage_AverageDisplay,
    required this.markbookPage_AverageScholarshipDisplay,
    required this.markbookPage_AppComputedNote,
    required this.markbookPage_NoGrades,
    required this.markbookPage_Empty,
    required this.markbookPage_CompletedLine,
    required this.paymentPage_Empty,
    required this.paymentPage_MoneyDisplay,
    required this.paymentPage_PaymentDeadlineTime,
    required this.paymentPage_PaymentMissedTime,
    required this.payment_currencyHuf,
    required this.payment_unknownTransaction,
    required this.payment_unknownStatus,
    required this.notif_payment_BodyNoDeadline,
    required this.notif_payment_BodyWithDeadline,
    required this.periodPage_ActiveDays,
    required this.periodPage_Empty,
    required this.periodPage_Expired,
    required this.periodPage_ExpiredDays,
    required this.periodPage_StartDays,
    required this.periodPage_Starts,
    required this.messagePage_SentBy,
    required this.messagePage_Empty,
    required this.mail_search_Hint,
    required this.mail_filter_UnreadOnly,
    required this.mail_filter_NoMatches,
    required this.whatsChanged_Header,
    required this.whatsChanged_NewMessages,
    required this.whatsChanged_GradeChanges,
    required this.popup_case0_GhostGradeHeader,
    required this.popup_case0_SelectGrade,
    required this.popup_caseAll_OkButton,
    required this.popup_case1_settingBottomText_InstallOrigin,
    required this.popup_case1_settingBottomText_InstallOrigin3rdParty,
    required this.popup_case1_settingBottomText_InstallOriginGPlay,
    required this.popup_case1_settingOption1_FamilyFriendlyLoadingText,
    required this.popup_case1_settingOption1_FamilyFriendlyLoadingTextDescription,
    required this.popup_case1_settingOption2_ExamNotifications,
    required this.popup_case1_settingOption2_ExamNotificationsDescription,
    required this.popup_case1_settingOption3_ClassNotifications,
    required this.popup_case1_settingOption3_ClassNotificationsDescription,
    required this.popup_case1_settingOption4_PaymentNotifications,
    required this.popup_case1_settingOption4_PaymentNotificationsDescription,
    required this.popup_case1_settingOption5_PeriodsNotifications,
    required this.popup_case1_settingOption5_PeriodsNotificationsDescription,
    required this.popup_case1_settingOption6_AppHaptics,
    required this.popup_case1_settingOption6_AppHapticsDescription,
    required this.popup_case1_settingOption7_WeekOffset,
    required this.popup_case1_settingOption7_WeekOffsetDescription,
    required this.popup_case1_settingOption7_WeekOffsetAuto,
    required this.popup_case1_SettingsHeader,
    required this.popup_case2_RateAppPopup,
    required this.popup_case2_RateAppPopupDescription,
    required this.popup_case2_RateButton,
    required this.popup_case3_MessagesHeader,
    required this.clickableText_OnCopy,
    required this.popup_case4_5_SubjectCode,
    required this.popup_case4_5_SubjectLocation,
    required this.popup_case4_SubjectStartTime,
    required this.popup_case4_SubjectInfo,
    required this.popup_case4_TeachedBy,
    required this.popup_case5_ExamInfo,
    required this.popup_case5_ExamStartTime,
    required this.popup_case6_AccountError,
    required this.popup_case6_AccountErrorDescription,
    required this.popup_case6_AccountErrorLogoutButton,
    required this.popup_case1_settingOption8_LangaugeSelection,
    required this.popup_case1_settingOption8_LangaugeSelectionDescription,
    required this.popup_case7_ButtonUpdateNow,
    required this.popup_case7_ObsolteAppVersion,
    required this.popup_case7_ObsolteAppVersionDescription,
    required this.popup_caseDefault_InvalidPopupState,
    required this.popup_case8_AcceptLanguageSuggestion,
    required this.popup_case8_AcceptLanguageSuggestionDescription,
    required this.popup_case8_ButtonAcceptLang,
    required this.popup_case1_langSwap_DownloadingLang,
    required this.popup_case1_langSwap_DownloadingLangFail,
    required this.popup_case1_settingOption9_ThemeSwap,
    required this.popup_case1_settingOption9_ThemeSwapDescription,
    required this.popup_case1_themeSwap_DownloadingThemeFail,
    required this.settings_section_AppearanceLanguage,
    required this.settings_section_FontScale,
    required this.settings_section_Notifications,
    required this.settings_section_BehaviorOther,
    required this.settings_section_CalendarFilters,
    required this.settings_calendar_ShowClasses,
    required this.settings_calendar_ShowExams,
    required this.settings_calendar_ShowPeriods,
    required this.calendar_next48h_Header,
    required this.calendar_tasks_Header,
    required this.calendar_exams_Header,
    required this.calendar_periods_Header,
    required this.calendar_break_label,
    required this.calendar_break_now,
    required this.calendar_break_next,
    required this.calendar_break_minutes,
    required this.calendar_break_hours,
    required this.calendar_break_hoursMinutes,
    required this.markbook_myCourses_Header,
    required this.markbook_gradeHistory_Header,
    required this.payment_invoices_Header,
    required this.mail_translate_EN,
    required this.mail_translate_RU,
    required this.mail_translate_Disclaimer,
    required this.mail_translate_ShowOriginal,
    required this.topmenu_TrainingSelectorTitle,
    required this.notif_title_Exam,
    required this.notif_title_Class,
    required this.notif_title_Payment,
    required this.notif_title_Period,
    required this.notif_period_Tomorrow,
    required this.notif_period_Today,
    required this.courseDetail_Type,
    required this.courseDetail_Teacher,
    required this.courseDetail_Room,
    required this.courseDetail_Subject,
    required this.courseDetail_Result,
    required this.courseDetail_Close,
    required this.courseDetail_Unknown,
    required this.courseDetail_NoResultYet,
    required this.courseDetail_LoadingRoom,
    required this.courseDetail_NoRoom,
    required this.courseDetail_NoTeacher,
    required this.courseDetail_NoInternet,
    required this.courseDetail_OfflineMode,
    required this.courseDetail_LoadError,
    required this.courseDetail_OldApiUnsupported,
    required this.courseDetail_Unsupported,
    required this.courseDetail_NotSpecified,
    this.roomCode_Floor = 'Floor',
    this.roomCode_Room = 'Room',
    this.roomCode_Stream = 'Stream',
    this.roomCode_Group = 'Group',
    this.roomCode_Building_LD = 'Southern Building',
    this.roomCode_Building_LE = 'Northern Building',
    this.roomCode_Building_LK = 'Chemistry block (Northern Building)',
    required this.markbook_creditAbbrev,
    required this.notif_exam_BodyToday,
    required this.notif_exam_BodyTomorrow,
    required this.notif_exam_BodyInDays,
    required this.notif_class_BodyIn10Min,
    required this.notif_class_BodyIn5Min,
    required this.notif_class_BodyNow,
    required this.settings_fontScale_Label,
    required this.mail_error_Prefix,
    required this.mail_error_EmptyMessage,
    required this.popup_case9_2faHeader,
    required this.popup_case9_2faDescription,
    required this.updater_NoInternet,
    required this.updater_Checking,
    required this.updater_FetchFailed,
    required this.updater_UpToDate,
    required this.updater_CheckError,
    required this.updater_DialogTitle,
    required this.updater_DialogBody,
    required this.updater_Later,
    required this.updater_Yes,
    required this.updater_NoApk,
    required this.updater_DownloadError,
    required this.updater_Downloading,
    required this.updater_DontClose,
    required this.api_fallback_NoTitle,
    required this.api_fallback_Unknown,
    required this.api_fallback_UnknownSubject,
    required this.api_fallback_Task,
    required this.api_fallback_NoResult,
    required this.api_fallback_UnknownPeriod,
    required this.api_fallback_NoTermId,
    required this.api_demo_Term1,
    required this.api_demo_Term2,
    required this.api_demo_Subject1,
    required this.api_demo_GhostGrade,
    required this.api_demo_Course,
    required this.api_demo_Payment1,
    required this.api_demo_Payment2,
    required this.api_demo_MailSubject,
    required this.api_demo_MailBody,
    required this.api_demo_MailSender,
    required this.api_error_InvalidUrlOrHtml,
    required this.api_error_Network,
    required this.api_error_EmptyNeptunResponse,
    required this.api_error_DownloadNetwork,
    required this.mail_preview_TapToLoadBody,

    required this.rootpage_setupPage_IcsImport,
    required this.rootpage_setupPage_IcsImportDescription,
    required this.rootpage_setupPage_OtherUsageModes,
    required this.calendarLogin_setupPage_InvalidFile,
    required this.calendarLogin_setupPage_LoginViaICSHeader,
    required this.calendarLogin_setupPage_WhereIsICSHelper,
    required this.calendarLogin_setupPage_WhereIsICSHelperDescription,
    required this.calendarLogin_setupPage_ImportICSFileHelpText,
    required this.calendarLogin_setupPage_ImportICSFileButton,
    this.topmenu_SemesterSelectorTitle = 'Semester',
    this.topmenu_SemesterToast = 'Semester switched: %0',
    this.topmenu_AccountBalance = 'Account balance',
    this.topmenu_UnreadMessagesBadge = '%0 new messages',
    this.topmenu_NoUnreadMessages = 'No new messages',
    this.topmenu_MessagesTitle = 'Messages',
    this.topmenu_PaymentsTitle = 'Payments'
  });

  static LanguagePack fromJson(String countryId, String json, VoidCallback onLanguageOutdated){
    LanguagePack? decodedLangPack;
    if(AppStrings._downloadedSupportedLanguages.contains(countryId)){
      // overwrite
      final duplicateIdx = AppStrings._downloadedSupportedLanguages.indexOf(countryId);
      AppStrings._downloadedSupportedLanguages.removeAt(duplicateIdx);
      AppStrings._downloadedSupportedLanguagesFlags.removeAt(duplicateIdx);
      AppStrings._downloadedLanguages.remove(countryId);
    }
    try{
      final dynamic decodedRaw = conv.json.decode(json);
      Map<String, dynamic> lang = decodedRaw is Map<String, dynamic> ? decodedRaw : Map<String, dynamic>.from(decodedRaw as Map);
      lang = AppStrings._mergeWithBundled(countryId, lang);
      final en = AppStrings._languages['en'] ?? AppStrings._languages['hu']!;

      String getStr(String key, String fallback) {
        final val = lang[key];
        if (val != null && val.toString().trim().isNotEmpty) {
          return val.toString();
        }
        return fallback;
      }

      decodedLangPack = LanguagePack(
        language_flag: getStr('language_flag', '🌐'),
        rootpage_setupPage_SelectLoginTypeHeader: getStr('rootpage_setupPage_SelectLoginTypeHeader', en.rootpage_setupPage_SelectLoginTypeHeader),
        rootpage_setupPage_InstitutesSelection: getStr('rootpage_setupPage_InstitutesSelection', en.rootpage_setupPage_InstitutesSelection),
        rootpage_setupPage_InstitutesSelectionDescription: getStr('rootpage_setupPage_InstitutesSelectionDescription', en.rootpage_setupPage_InstitutesSelectionDescription),
        rootpage_setupPage_UrlLogin: getStr('rootpage_setupPage_UrlLogin', en.rootpage_setupPage_UrlLogin),
        rootpage_setupPage_UrlLoginDescription: getStr('rootpage_setupPage_UrlLoginDescription', en.rootpage_setupPage_UrlLoginDescription),
        rootpage_setupPage_AppProblemReporting: getStr('rootpage_setupPage_AppProblemReporting', en.rootpage_setupPage_AppProblemReporting),
        instituteSelection_setupPage_LoadingText: getStr('instituteSelection_setupPage_LoadingText', en.instituteSelection_setupPage_LoadingText),
        instituteSelection_setupPage_NoNetwork: getStr('instituteSelection_setupPage_NoNetwork', en.instituteSelection_setupPage_NoNetwork),
        instituteSelection_setupPage_SelectValidInstitute: getStr('instituteSelection_setupPage_SelectValidInstitute', en.instituteSelection_setupPage_SelectValidInstitute),
        instituteSelection_setupPage_SelectInstitute: getStr('instituteSelection_setupPage_SelectInstitute', en.instituteSelection_setupPage_SelectInstitute),
        instituteSelection_setupPage_Search: getStr('instituteSelection_setupPage_Search', en.instituteSelection_setupPage_Search),
        instituteSelection_setupPage_SearchNotFound: getStr('instituteSelection_setupPage_SearchNotFound', en.instituteSelection_setupPage_SearchNotFound),
        instituteSelection_setupPage_InstituteCantFindHelpText: getStr('instituteSelection_setupPage_InstituteCantFindHelpText', en.instituteSelection_setupPage_InstituteCantFindHelpText),
        instituteSelection_setupPage_InstituteCantFindHelpTextDescription: getStr('instituteSelection_setupPage_InstituteCantFindHelpTextDescription', en.instituteSelection_setupPage_InstituteCantFindHelpTextDescription),
        any_setupPage_GoBack: getStr('any_setupPage_GoBack', en.any_setupPage_GoBack),
        any_setupPage_ProceedLogin: getStr('any_setupPage_ProceedLogin', en.any_setupPage_ProceedLogin),
        urlLogin_setupPage_InvalidUrl: getStr('urlLogin_setupPage_InvalidUrl', en.urlLogin_setupPage_InvalidUrl),
        urlLogin_setupPage_LoginViaURlHeader: getStr('urlLogin_setupPage_LoginViaURlHeader', en.urlLogin_setupPage_LoginViaURlHeader),
        urlLogin_setupPage_InstituteNeptunUrl: getStr('urlLogin_setupPage_InstituteNeptunUrl', en.urlLogin_setupPage_InstituteNeptunUrl),
        urlLogin_setupPage_InstituteNeptunUrlInvalid: getStr('urlLogin_setupPage_InstituteNeptunUrlInvalid', en.urlLogin_setupPage_InstituteNeptunUrlInvalid),
        urlLogin_setupPage_WhereIsURLHelper: getStr('urlLogin_setupPage_WhereIsURLHelper', en.urlLogin_setupPage_WhereIsURLHelper),
        urlLogin_setupPage_WhereIsURLHelperDescription: getStr('urlLogin_setupPage_WhereIsURLHelperDescription', en.urlLogin_setupPage_WhereIsURLHelperDescription),
        loginPage_setupPage_InvalidCredentials: getStr('loginPage_setupPage_InvalidCredentials', en.loginPage_setupPage_InvalidCredentials),
        loginPage_setupPage_LoginHeaderText: getStr('loginPage_setupPage_LoginHeaderText', en.loginPage_setupPage_LoginHeaderText),
        loginPage_setupPage_ActivityCacheInvalidHelper: getStr('loginPage_setupPage_ActivityCacheInvalidHelper', en.loginPage_setupPage_ActivityCacheInvalidHelper),
        loginPage_setupPage_NeptunCode: getStr('loginPage_setupPage_NeptunCode', en.loginPage_setupPage_NeptunCode),
        loginPage_setupPage_Password: getStr('loginPage_setupPage_Password', en.loginPage_setupPage_Password),
        loginPage_setupPage_InvalidCredentialsEntered: getStr('loginPage_setupPage_InvalidCredentialsEntered', en.loginPage_setupPage_InvalidCredentialsEntered),
        loginPage_setupPage_2faWarning: getStr('loginPage_setupPage_2faWarning', en.loginPage_setupPage_2faWarning),
        loginPage_setupPage_2faWarningDescription: getStr('loginPage_setupPage_2faWarningDescription', en.loginPage_setupPage_2faWarningDescription),
        loginPage_setupPage_LogInButton: getStr('loginPage_setupPage_LogInButton', en.loginPage_setupPage_LogInButton),
        loginPage_setupPage_LoginInProgress: getStr('loginPage_setupPage_LoginInProgress', en.loginPage_setupPage_LoginInProgress),
        loginPage_setupPage_LoginInProgressSlow: getStr('loginPage_setupPage_LoginInProgressSlow', en.loginPage_setupPage_LoginInProgressSlow),
        loginPage_setupPage_StudentWebFull: getStr('loginPage_setupPage_StudentWebFull', en.loginPage_setupPage_StudentWebFull),
        loginPage_setupPage_2faInvalidCode: getStr('loginPage_setupPage_2faInvalidCode', en.loginPage_setupPage_2faInvalidCode),
        loginPage_setupPage_ConnectingStudentWeb: getStr('loginPage_setupPage_ConnectingStudentWeb', en.loginPage_setupPage_ConnectingStudentWeb),
        auth_sessionExpired_PleaseSignIn: getStr('auth_sessionExpired_PleaseSignIn', en.auth_sessionExpired_PleaseSignIn),
        cache_showingFromCache: getStr('cache_showingFromCache', en.cache_showingFromCache),
        api_monthJan_Universal: getStr('api_monthJan_Universal', en.api_monthJan_Universal),
        api_monthFeb_Universal: getStr('api_monthFeb_Universal', en.api_monthFeb_Universal),
        api_monthMar_Universal: getStr('api_monthMar_Universal', en.api_monthMar_Universal),
        api_monthApr_Universal: getStr('api_monthApr_Universal', en.api_monthApr_Universal),
        api_monthJun_Universal: getStr('api_monthJun_Universal', en.api_monthJun_Universal),
        api_monthMay_Universal: getStr('api_monthMay_Universal', en.api_monthMay_Universal),
        api_monthJul_Universal: getStr('api_monthJul_Universal', en.api_monthJul_Universal),
        api_monthAug_Universal: getStr('api_monthAug_Universal', en.api_monthAug_Universal),
        api_monthSep_Universal: getStr('api_monthSep_Universal', en.api_monthSep_Universal),
        api_monthOkt_Universal: getStr('api_monthOkt_Universal', en.api_monthOkt_Universal),
        api_monthNov_Universal: getStr('api_monthNov_Universal', en.api_monthNov_Universal),
        api_monthDec_Universal: getStr('api_monthDec_Universal', en.api_monthDec_Universal),
        api_dayMon_Universal: getStr('api_dayMon_Universal', en.api_dayMon_Universal),
        api_dayTue_Universal: getStr('api_dayTue_Universal', en.api_dayTue_Universal),
        api_dayWed_Universal: getStr('api_dayWed_Universal', en.api_dayWed_Universal),
        api_dayThu_Universal: getStr('api_dayThu_Universal', en.api_dayThu_Universal),
        api_dayFri_Universal: getStr('api_dayFri_Universal', en.api_dayFri_Universal),
        api_daySat_Universal: getStr('api_daySat_Universal', en.api_daySat_Universal),
        api_daySun_Universal: getStr('api_daySun_Universal', en.api_daySun_Universal),
        api_loadingScreenHintFriendly1_Universal: getStr('api_loadingScreenHintFriendly1_Universal', en.api_loadingScreenHintFriendly1_Universal),
        api_loadingScreenHintFriendly2_Universal: getStr('api_loadingScreenHintFriendly2_Universal', en.api_loadingScreenHintFriendly2_Universal),
        api_loadingScreenHintFriendly3_Universal: getStr('api_loadingScreenHintFriendly3_Universal', en.api_loadingScreenHintFriendly3_Universal),
        api_loadingScreenHintFriendly4_Universal: getStr('api_loadingScreenHintFriendly4_Universal', en.api_loadingScreenHintFriendly4_Universal),
        api_loadingScreenHintFriendly5_Universal: getStr('api_loadingScreenHintFriendly5_Universal', en.api_loadingScreenHintFriendly5_Universal),
        api_loadingScreenHintFriendly6_Universal: getStr('api_loadingScreenHintFriendly6_Universal', en.api_loadingScreenHintFriendly6_Universal),
        api_loadingScreenHintFriendly7_Universal: getStr('api_loadingScreenHintFriendly7_Universal', en.api_loadingScreenHintFriendly7_Universal),
        api_loadingScreenHint1_Universal: getStr('api_loadingScreenHint1_Universal', en.api_loadingScreenHint1_Universal),
        api_loadingScreenHint2_Universal: getStr('api_loadingScreenHint2_Universal', en.api_loadingScreenHint2_Universal),
        api_loadingScreenHint3_Universal: getStr('api_loadingScreenHint3_Universal', en.api_loadingScreenHint3_Universal),
        api_loadingScreenHint4_Universal: getStr('api_loadingScreenHint4_Universal', en.api_loadingScreenHint4_Universal),
        api_loadingScreenHint5_Universal: getStr('api_loadingScreenHint5_Universal', en.api_loadingScreenHint5_Universal),
        api_loadingScreenHint6_Universal: getStr('api_loadingScreenHint6_Universal', en.api_loadingScreenHint6_Universal),
        api_loadingScreenHint7_Universal: getStr('api_loadingScreenHint7_Universal', en.api_loadingScreenHint7_Universal),
        api_loadingScreenHintFriendlyMini1_Universal: getStr('api_loadingScreenHintFriendlyMini1_Universal', en.api_loadingScreenHintFriendlyMini1_Universal),
        api_loadingScreenHintFriendlyMini2_Universal: getStr('api_loadingScreenHintFriendlyMini2_Universal', en.api_loadingScreenHintFriendlyMini2_Universal),
        api_loadingScreenHintFriendlyMini3_Universal: getStr('api_loadingScreenHintFriendlyMini3_Universal', en.api_loadingScreenHintFriendlyMini3_Universal),
        api_loadingScreenHintFriendlyMini4_Universal: getStr('api_loadingScreenHintFriendlyMini4_Universal', en.api_loadingScreenHintFriendlyMini4_Universal),
        api_loadingScreenHintMini1_Universal: getStr('api_loadingScreenHintMini1_Universal', en.api_loadingScreenHintMini1_Universal),
        api_loadingScreenHintMini2_Universal: getStr('api_loadingScreenHintMini2_Universal', en.api_loadingScreenHintMini2_Universal),
        api_loadingScreenHintMini3_Universal: getStr('api_loadingScreenHintMini3_Universal', en.api_loadingScreenHintMini3_Universal),
        api_noData_Universal: getStr('api_noData_Universal', en.api_noData_Universal),
        view_header_Calendar: getStr('view_header_Calendar', en.view_header_Calendar),
        view_header_Messages: getStr('view_header_Messages', en.view_header_Messages),
        view_header_Payments: getStr('view_header_Payments', en.view_header_Payments),
        view_header_Periods: getStr('view_header_Periods', en.view_header_Periods),
        view_header_Subjects: getStr('view_header_Subjects', en.view_header_Subjects),
        topheader_calendar_greetMessage_1to6: getStr('topheader_calendar_greetMessage_1to6', en.topheader_calendar_greetMessage_1to6),
        topheader_calendar_greetMessage_6to9: getStr('topheader_calendar_greetMessage_6to9', en.topheader_calendar_greetMessage_6to9),
        topheader_calendar_greetMessage_9to13: getStr('topheader_calendar_greetMessage_9to13', en.topheader_calendar_greetMessage_9to13),
        topheader_calendar_greetMessage_13to17: getStr('topheader_calendar_greetMessage_13to17', en.topheader_calendar_greetMessage_13to17),
        topheader_calendar_greetMessage_17to21: getStr('topheader_calendar_greetMessage_17to21', en.topheader_calendar_greetMessage_17to21),
        topheader_calendar_greetMessage_21to1: getStr('topheader_calendar_greetMessage_21to1', en.topheader_calendar_greetMessage_21to1),
        topheader_subjects_CreditsInSemester: getStr('topheader_subjects_CreditsInSemester', en.topheader_subjects_CreditsInSemester),
        topheader_subjects_CreditsHeader: getStr('topheader_subjects_CreditsHeader', en.topheader_subjects_CreditsHeader),
        topheader_payments_TotalMoneySpent: getStr('topheader_payments_TotalMoneySpent', en.topheader_payments_TotalMoneySpent),
        topheader_periods_ActiveText: getStr('topheader_periods_ActiveText', en.topheader_periods_ActiveText),
        topheader_periods_ExpiredText: getStr('topheader_periods_ExpiredText', en.topheader_periods_ExpiredText),
        topheader_periods_FutureText: getStr('topheader_periods_FutureText', en.topheader_periods_FutureText),
        topheader_periods_MainHeader: getStr('topheader_periods_MainHeader', en.topheader_periods_MainHeader),
        topheader_messages_UnreadMessages: getStr('topheader_messages_UnreadMessages', en.topheader_messages_UnreadMessages),
        topmenu_buttons_Bugreport: getStr('topmenu_buttons_Bugreport', en.topmenu_buttons_Bugreport),
        topmenu_buttons_Logout: getStr('topmenu_buttons_Logout', en.topmenu_buttons_Logout),
        topmenu_buttons_Settings: getStr('topmenu_buttons_Settings', en.topmenu_buttons_Settings),
        topmenu_buttons_SupportDev: getStr('topmenu_buttons_SupportDev', en.topmenu_buttons_SupportDev),
        topmenu_Greet: getStr('topmenu_Greet', en.topmenu_Greet),
        topmenu_LoginPlace: getStr('topmenu_LoginPlace', en.topmenu_LoginPlace),
        topmenu_buttons_LogoutSuccessToast: getStr('topmenu_buttons_LogoutSuccessToast', en.topmenu_buttons_LogoutSuccessToast),
        topmenu_buttons_Contacts: getStr('topmenu_buttons_Contacts', en.topmenu_buttons_Contacts),
        calendarPage_FreeDay: getStr('calendarPage_FreeDay', en.calendarPage_FreeDay),
        calendarPage_weekNav_ClassesThisWeekFull: getStr('calendarPage_weekNav_ClassesThisWeekFull', en.calendarPage_weekNav_ClassesThisWeekFull),
        calendarPage_weekNav_ClassesThisWeekOneDay: getStr('calendarPage_weekNav_ClassesThisWeekOneDay', en.calendarPage_weekNav_ClassesThisWeekOneDay),
        calendarPage_weekNav_StudyWeek: getStr('calendarPage_weekNav_StudyWeek', en.calendarPage_weekNav_StudyWeek),
        calendarPage_weekNav_ClassesThisWeekEmpty: getStr('calendarPage_weekNav_ClassesThisWeekEmpty', en.calendarPage_weekNav_ClassesThisWeekEmpty),
        calendarPage_weekNav_ClassesThisWeekLoading: getStr('calendarPage_weekNav_ClassesThisWeekLoading', en.calendarPage_weekNav_ClassesThisWeekLoading),
        markbookPage_AverageDisplay: getStr('markbookPage_AverageDisplay', en.markbookPage_AverageDisplay),
        markbookPage_AverageScholarshipDisplay: getStr('markbookPage_AverageScholarshipDisplay', en.markbookPage_AverageScholarshipDisplay),
        markbookPage_AppComputedNote: getStr('markbookPage_AppComputedNote', en.markbookPage_AppComputedNote),
        markbookPage_NoGrades: getStr('markbookPage_NoGrades', en.markbookPage_NoGrades),
        markbookPage_Empty: getStr('markbookPage_Empty', en.markbookPage_Empty),
        markbookPage_CompletedLine: getStr('markbookPage_CompletedLine', en.markbookPage_CompletedLine),
        paymentPage_Empty: getStr('paymentPage_Empty', en.paymentPage_Empty),
        paymentPage_MoneyDisplay: getStr('paymentPage_MoneyDisplay', en.paymentPage_MoneyDisplay),
        paymentPage_PaymentDeadlineTime: getStr('paymentPage_PaymentDeadlineTime', en.paymentPage_PaymentDeadlineTime),
        paymentPage_PaymentMissedTime: getStr('paymentPage_PaymentMissedTime', en.paymentPage_PaymentMissedTime),
        payment_currencyHuf: getStr('payment_currencyHuf', en.payment_currencyHuf),
        payment_unknownTransaction: getStr('payment_unknownTransaction', en.payment_unknownTransaction),
        payment_unknownStatus: getStr('payment_unknownStatus', en.payment_unknownStatus),
        notif_payment_BodyNoDeadline: getStr('notif_payment_BodyNoDeadline', en.notif_payment_BodyNoDeadline),
        notif_payment_BodyWithDeadline: getStr('notif_payment_BodyWithDeadline', en.notif_payment_BodyWithDeadline),
        periodPage_ActiveDays: getStr('periodPage_ActiveDays', en.periodPage_ActiveDays),
        periodPage_Empty: getStr('periodPage_Empty', en.periodPage_Empty),
        periodPage_Expired: getStr('periodPage_Expired', en.periodPage_Expired),
        periodPage_ExpiredDays: getStr('periodPage_ExpiredDays', en.periodPage_ExpiredDays),
        periodPage_StartDays: getStr('periodPage_StartDays', en.periodPage_StartDays),
        periodPage_Starts: getStr('periodPage_Starts', en.periodPage_Starts),
        messagePage_SentBy: getStr('messagePage_SentBy', en.messagePage_SentBy),
        messagePage_Empty: getStr('messagePage_Empty', en.messagePage_Empty),
        mail_search_Hint: getStr('mail_search_Hint', en.mail_search_Hint),
        mail_filter_UnreadOnly: getStr('mail_filter_UnreadOnly', en.mail_filter_UnreadOnly),
        mail_filter_NoMatches: getStr('mail_filter_NoMatches', en.mail_filter_NoMatches),
        whatsChanged_Header: getStr('whatsChanged_Header', en.whatsChanged_Header),
        whatsChanged_NewMessages: getStr('whatsChanged_NewMessages', en.whatsChanged_NewMessages),
        whatsChanged_GradeChanges: getStr('whatsChanged_GradeChanges', en.whatsChanged_GradeChanges),
        popup_case0_GhostGradeHeader: getStr('popup_case0_GhostGradeHeader', en.popup_case0_GhostGradeHeader),
        popup_case0_SelectGrade: getStr('popup_case0_SelectGrade', en.popup_case0_SelectGrade),
        popup_caseAll_OkButton: getStr('popup_caseAll_OkButton', en.popup_caseAll_OkButton),
        popup_case1_settingBottomText_InstallOrigin: getStr('popup_case1_settingBottomText_InstallOrigin', en.popup_case1_settingBottomText_InstallOrigin),
        popup_case1_settingBottomText_InstallOrigin3rdParty: getStr('popup_case1_settingBottomText_InstallOrigin3rdParty', en.popup_case1_settingBottomText_InstallOrigin3rdParty),
        popup_case1_settingBottomText_InstallOriginGPlay: getStr('popup_case1_settingBottomText_InstallOriginGPlay', en.popup_case1_settingBottomText_InstallOriginGPlay),
        popup_case1_settingOption1_FamilyFriendlyLoadingText: getStr('popup_case1_settingOption1_FamilyFriendlyLoadingText', en.popup_case1_settingOption1_FamilyFriendlyLoadingText),
        popup_case1_settingOption1_FamilyFriendlyLoadingTextDescription: getStr('popup_case1_settingOption1_FamilyFriendlyLoadingTextDescription', en.popup_case1_settingOption1_FamilyFriendlyLoadingTextDescription),
        popup_case1_settingOption2_ExamNotifications: getStr('popup_case1_settingOption2_ExamNotifications', en.popup_case1_settingOption2_ExamNotifications),
        popup_case1_settingOption2_ExamNotificationsDescription: getStr('popup_case1_settingOption2_ExamNotificationsDescription', en.popup_case1_settingOption2_ExamNotificationsDescription),
        popup_case1_settingOption3_ClassNotifications: getStr('popup_case1_settingOption3_ClassNotifications', en.popup_case1_settingOption3_ClassNotifications),
        popup_case1_settingOption3_ClassNotificationsDescription: getStr('popup_case1_settingOption3_ClassNotificationsDescription', en.popup_case1_settingOption3_ClassNotificationsDescription),
        popup_case1_settingOption4_PaymentNotifications: getStr('popup_case1_settingOption4_PaymentNotifications', en.popup_case1_settingOption4_PaymentNotifications),
        popup_case1_settingOption4_PaymentNotificationsDescription: getStr('popup_case1_settingOption4_PaymentNotificationsDescription', en.popup_case1_settingOption4_PaymentNotificationsDescription),
        popup_case1_settingOption5_PeriodsNotifications: getStr('popup_case1_settingOption5_PeriodsNotifications', en.popup_case1_settingOption5_PeriodsNotifications),
        popup_case1_settingOption5_PeriodsNotificationsDescription: getStr('popup_case1_settingOption5_PeriodsNotificationsDescription', en.popup_case1_settingOption5_PeriodsNotificationsDescription),
        popup_case1_settingOption6_AppHaptics: getStr('popup_case1_settingOption6_AppHaptics', en.popup_case1_settingOption6_AppHaptics),
        popup_case1_settingOption6_AppHapticsDescription: getStr('popup_case1_settingOption6_AppHapticsDescription', en.popup_case1_settingOption6_AppHapticsDescription),
        popup_case1_settingOption7_WeekOffset: getStr('popup_case1_settingOption7_WeekOffset', en.popup_case1_settingOption7_WeekOffset),
        popup_case1_settingOption7_WeekOffsetDescription: getStr('popup_case1_settingOption7_WeekOffsetDescription', en.popup_case1_settingOption7_WeekOffsetDescription),
        popup_case1_settingOption7_WeekOffsetAuto: getStr('popup_case1_settingOption7_WeekOffsetAuto', en.popup_case1_settingOption7_WeekOffsetAuto),
        popup_case1_SettingsHeader: getStr('popup_case1_SettingsHeader', en.popup_case1_SettingsHeader),
        popup_case2_RateAppPopup: getStr('popup_case2_RateAppPopup', en.popup_case2_RateAppPopup),
        popup_case2_RateAppPopupDescription: getStr('popup_case2_RateAppPopupDescription', en.popup_case2_RateAppPopupDescription),
        popup_case2_RateButton: getStr('popup_case2_RateButton', en.popup_case2_RateButton),
        popup_case3_MessagesHeader: getStr('popup_case3_MessagesHeader', en.popup_case3_MessagesHeader),
        clickableText_OnCopy: getStr('clickableText_OnCopy', en.clickableText_OnCopy),
        popup_case4_5_SubjectCode: getStr('popup_case4_5_SubjectCode', en.popup_case4_5_SubjectCode),
        popup_case4_5_SubjectLocation: getStr('popup_case4_5_SubjectLocation', en.popup_case4_5_SubjectLocation),
        popup_case4_SubjectStartTime: getStr('popup_case4_SubjectStartTime', en.popup_case4_SubjectStartTime),
        popup_case4_SubjectInfo: getStr('popup_case4_SubjectInfo', en.popup_case4_SubjectInfo),
        popup_case4_TeachedBy: getStr('popup_case4_TeachedBy', en.popup_case4_TeachedBy),
        popup_case5_ExamInfo: getStr('popup_case5_ExamInfo', en.popup_case5_ExamInfo),
        popup_case5_ExamStartTime: getStr('popup_case5_ExamStartTime', en.popup_case5_ExamStartTime),
        popup_case6_AccountError: getStr('popup_case6_AccountError', en.popup_case6_AccountError),
        popup_case6_AccountErrorDescription: getStr('popup_case6_AccountErrorDescription', en.popup_case6_AccountErrorDescription),
        popup_case6_AccountErrorLogoutButton: getStr('popup_case6_AccountErrorLogoutButton', en.popup_case6_AccountErrorLogoutButton),
        popup_case1_settingOption8_LangaugeSelection: getStr('popup_case1_settingOption8_LangaugeSelection', en.popup_case1_settingOption8_LangaugeSelection),
        popup_case1_settingOption8_LangaugeSelectionDescription: getStr('popup_case1_settingOption8_LangaugeSelectionDescription', en.popup_case1_settingOption8_LangaugeSelectionDescription),
        popup_case7_ButtonUpdateNow: getStr('popup_case7_ButtonUpdateNow', en.popup_case7_ButtonUpdateNow),
        popup_case7_ObsolteAppVersion: getStr('popup_case7_ObsolteAppVersion', en.popup_case7_ObsolteAppVersion),
        popup_case7_ObsolteAppVersionDescription: getStr('popup_case7_ObsolteAppVersionDescription', en.popup_case7_ObsolteAppVersionDescription),
        popup_caseDefault_InvalidPopupState: getStr('popup_caseDefault_InvalidPopupState', en.popup_caseDefault_InvalidPopupState),
        popup_case8_AcceptLanguageSuggestion: getStr('popup_case8_AcceptLanguageSuggestion', en.popup_case8_AcceptLanguageSuggestion),
        popup_case8_AcceptLanguageSuggestionDescription: getStr('popup_case8_AcceptLanguageSuggestionDescription', en.popup_case8_AcceptLanguageSuggestionDescription),
        popup_case8_ButtonAcceptLang: getStr('popup_case8_ButtonAcceptLang', en.popup_case8_ButtonAcceptLang),
        popup_case1_langSwap_DownloadingLang: getStr('popup_case1_langSwap_DownloadingLang', en.popup_case1_langSwap_DownloadingLang),
        popup_case1_langSwap_DownloadingLangFail: getStr('popup_case1_langSwap_DownloadingLangFail', en.popup_case1_langSwap_DownloadingLangFail),
        popup_case1_settingOption9_ThemeSwap: getStr('popup_case1_settingOption9_ThemeSwap', en.popup_case1_settingOption9_ThemeSwap),
        popup_case1_settingOption9_ThemeSwapDescription: getStr('popup_case1_settingOption9_ThemeSwapDescription', en.popup_case1_settingOption9_ThemeSwapDescription),
        popup_case1_themeSwap_DownloadingThemeFail: getStr('popup_case1_themeSwap_DownloadingThemeFail', en.popup_case1_themeSwap_DownloadingThemeFail),
        settings_section_AppearanceLanguage: getStr('settings_section_AppearanceLanguage', en.settings_section_AppearanceLanguage),
        settings_section_FontScale: getStr('settings_section_FontScale', en.settings_section_FontScale),
        settings_section_Notifications: getStr('settings_section_Notifications', en.settings_section_Notifications),
        settings_section_BehaviorOther: getStr('settings_section_BehaviorOther', en.settings_section_BehaviorOther),
        settings_section_CalendarFilters: getStr('settings_section_CalendarFilters', en.settings_section_CalendarFilters),
        settings_calendar_ShowClasses: getStr('settings_calendar_ShowClasses', en.settings_calendar_ShowClasses),
        settings_calendar_ShowExams: getStr('settings_calendar_ShowExams', en.settings_calendar_ShowExams),
        settings_calendar_ShowPeriods: getStr('settings_calendar_ShowPeriods', en.settings_calendar_ShowPeriods),
        calendar_next48h_Header: getStr('calendar_next48h_Header', en.calendar_next48h_Header),
        calendar_tasks_Header: getStr('calendar_tasks_Header', en.calendar_tasks_Header),
        calendar_exams_Header: getStr('calendar_exams_Header', en.calendar_exams_Header),
        calendar_periods_Header: getStr('calendar_periods_Header', en.calendar_periods_Header),
        calendar_break_label: getStr('calendar_break_label', en.calendar_break_label),
        calendar_break_now: getStr('calendar_break_now', en.calendar_break_now),
        calendar_break_next: getStr('calendar_break_next', en.calendar_break_next),
        calendar_break_minutes: getStr('calendar_break_minutes', en.calendar_break_minutes),
        calendar_break_hours: getStr('calendar_break_hours', en.calendar_break_hours),
        calendar_break_hoursMinutes: getStr('calendar_break_hoursMinutes', en.calendar_break_hoursMinutes),
        markbook_myCourses_Header: getStr('markbook_myCourses_Header', en.markbook_myCourses_Header),
        markbook_gradeHistory_Header: getStr('markbook_gradeHistory_Header', en.markbook_gradeHistory_Header),
        payment_invoices_Header: getStr('payment_invoices_Header', en.payment_invoices_Header),
        mail_translate_EN: getStr('mail_translate_EN', en.mail_translate_EN),
        mail_translate_RU: getStr('mail_translate_RU', en.mail_translate_RU),
        mail_translate_Disclaimer: getStr('mail_translate_Disclaimer', en.mail_translate_Disclaimer),
        mail_translate_ShowOriginal: getStr('mail_translate_ShowOriginal', en.mail_translate_ShowOriginal),
        topmenu_TrainingSelectorTitle: getStr('topmenu_TrainingSelectorTitle', en.topmenu_TrainingSelectorTitle),
        notif_title_Exam: getStr('notif_title_Exam', en.notif_title_Exam),
        notif_title_Class: getStr('notif_title_Class', en.notif_title_Class),
        notif_title_Payment: getStr('notif_title_Payment', en.notif_title_Payment),
        notif_title_Period: getStr('notif_title_Period', en.notif_title_Period),
        notif_period_Tomorrow: getStr('notif_period_Tomorrow', en.notif_period_Tomorrow),
        notif_period_Today: getStr('notif_period_Today', en.notif_period_Today),
        courseDetail_Type: getStr('courseDetail_Type', en.courseDetail_Type),
        courseDetail_Teacher: getStr('courseDetail_Teacher', en.courseDetail_Teacher),
        courseDetail_Room: getStr('courseDetail_Room', en.courseDetail_Room),
        courseDetail_Subject: getStr('courseDetail_Subject', en.courseDetail_Subject),
        courseDetail_Result: getStr('courseDetail_Result', en.courseDetail_Result),
        courseDetail_Close: getStr('courseDetail_Close', en.courseDetail_Close),
        courseDetail_Unknown: getStr('courseDetail_Unknown', en.courseDetail_Unknown),
        courseDetail_NoResultYet: getStr('courseDetail_NoResultYet', en.courseDetail_NoResultYet),
        courseDetail_LoadingRoom: getStr('courseDetail_LoadingRoom', en.courseDetail_LoadingRoom),
        courseDetail_NoRoom: getStr('courseDetail_NoRoom', en.courseDetail_NoRoom),
        courseDetail_NoTeacher: getStr('courseDetail_NoTeacher', en.courseDetail_NoTeacher),
        courseDetail_NoInternet: getStr('courseDetail_NoInternet', en.courseDetail_NoInternet),
        courseDetail_OfflineMode: getStr('courseDetail_OfflineMode', en.courseDetail_OfflineMode),
        courseDetail_LoadError: getStr('courseDetail_LoadError', en.courseDetail_LoadError),
        courseDetail_OldApiUnsupported: getStr('courseDetail_OldApiUnsupported', en.courseDetail_OldApiUnsupported),
        courseDetail_Unsupported: getStr('courseDetail_Unsupported', en.courseDetail_Unsupported),
        courseDetail_NotSpecified: getStr('courseDetail_NotSpecified', en.courseDetail_NotSpecified),
        roomCode_Floor: getStr('roomCode_Floor', en.roomCode_Floor),
        roomCode_Room: getStr('roomCode_Room', en.roomCode_Room),
        roomCode_Stream: getStr('roomCode_Stream', en.roomCode_Stream),
        roomCode_Group: getStr('roomCode_Group', en.roomCode_Group),
        roomCode_Building_LD: getStr('roomCode_Building_LD', en.roomCode_Building_LD),
        roomCode_Building_LE: getStr('roomCode_Building_LE', en.roomCode_Building_LE),
        roomCode_Building_LK: getStr('roomCode_Building_LK', en.roomCode_Building_LK),
        markbook_creditAbbrev: getStr('markbook_creditAbbrev', en.markbook_creditAbbrev),
        notif_exam_BodyToday: getStr('notif_exam_BodyToday', en.notif_exam_BodyToday),
        notif_exam_BodyTomorrow: getStr('notif_exam_BodyTomorrow', en.notif_exam_BodyTomorrow),
        notif_exam_BodyInDays: getStr('notif_exam_BodyInDays', en.notif_exam_BodyInDays),
        notif_class_BodyIn10Min: getStr('notif_class_BodyIn10Min', en.notif_class_BodyIn10Min),
        notif_class_BodyIn5Min: getStr('notif_class_BodyIn5Min', en.notif_class_BodyIn5Min),
        notif_class_BodyNow: getStr('notif_class_BodyNow', en.notif_class_BodyNow),
        settings_fontScale_Label: getStr('settings_fontScale_Label', en.settings_fontScale_Label),
        mail_error_Prefix: getStr('mail_error_Prefix', en.mail_error_Prefix),
        mail_error_EmptyMessage: getStr('mail_error_EmptyMessage', en.mail_error_EmptyMessage),
        popup_case9_2faHeader: getStr('popup_case9_2faHeader', en.popup_case9_2faHeader),
        popup_case9_2faDescription: getStr('popup_case9_2faDescription', en.popup_case9_2faDescription),
        updater_NoInternet: getStr('updater_NoInternet', en.updater_NoInternet),
        updater_Checking: getStr('updater_Checking', en.updater_Checking),
        updater_FetchFailed: getStr('updater_FetchFailed', en.updater_FetchFailed),
        updater_UpToDate: getStr('updater_UpToDate', en.updater_UpToDate),
        updater_CheckError: getStr('updater_CheckError', en.updater_CheckError),
        updater_DialogTitle: getStr('updater_DialogTitle', en.updater_DialogTitle),
        updater_DialogBody: getStr('updater_DialogBody', en.updater_DialogBody),
        updater_Later: getStr('updater_Later', en.updater_Later),
        updater_Yes: getStr('updater_Yes', en.updater_Yes),
        updater_NoApk: getStr('updater_NoApk', en.updater_NoApk),
        updater_DownloadError: getStr('updater_DownloadError', en.updater_DownloadError),
        updater_Downloading: getStr('updater_Downloading', en.updater_Downloading),
        updater_DontClose: getStr('updater_DontClose', en.updater_DontClose),
        api_fallback_NoTitle: getStr('api_fallback_NoTitle', en.api_fallback_NoTitle),
        api_fallback_Unknown: getStr('api_fallback_Unknown', en.api_fallback_Unknown),
        api_fallback_UnknownSubject: getStr('api_fallback_UnknownSubject', en.api_fallback_UnknownSubject),
        api_fallback_Task: getStr('api_fallback_Task', en.api_fallback_Task),
        api_fallback_NoResult: getStr('api_fallback_NoResult', en.api_fallback_NoResult),
        api_fallback_UnknownPeriod: getStr('api_fallback_UnknownPeriod', en.api_fallback_UnknownPeriod),
        api_fallback_NoTermId: getStr('api_fallback_NoTermId', en.api_fallback_NoTermId),
        api_demo_Term1: getStr('api_demo_Term1', en.api_demo_Term1),
        api_demo_Term2: getStr('api_demo_Term2', en.api_demo_Term2),
        api_demo_Subject1: getStr('api_demo_Subject1', en.api_demo_Subject1),
        api_demo_GhostGrade: getStr('api_demo_GhostGrade', en.api_demo_GhostGrade),
        api_demo_Course: getStr('api_demo_Course', en.api_demo_Course),
        api_demo_Payment1: getStr('api_demo_Payment1', en.api_demo_Payment1),
        api_demo_Payment2: getStr('api_demo_Payment2', en.api_demo_Payment2),
        api_demo_MailSubject: getStr('api_demo_MailSubject', en.api_demo_MailSubject),
        api_demo_MailBody: getStr('api_demo_MailBody', en.api_demo_MailBody),
        api_demo_MailSender: getStr('api_demo_MailSender', en.api_demo_MailSender),
        api_error_InvalidUrlOrHtml: getStr('api_error_InvalidUrlOrHtml', en.api_error_InvalidUrlOrHtml),
        api_error_Network: getStr('api_error_Network', en.api_error_Network),
        api_error_EmptyNeptunResponse: getStr('api_error_EmptyNeptunResponse', en.api_error_EmptyNeptunResponse),
        api_error_DownloadNetwork: getStr('api_error_DownloadNetwork', en.api_error_DownloadNetwork),
        mail_preview_TapToLoadBody: getStr('mail_preview_TapToLoadBody', en.mail_preview_TapToLoadBody),
        rootpage_setupPage_IcsImport: getStr('rootpage_setupPage_IcsImport', en.rootpage_setupPage_IcsImport),
        rootpage_setupPage_IcsImportDescription: getStr('rootpage_setupPage_IcsImportDescription', en.rootpage_setupPage_IcsImportDescription),
        rootpage_setupPage_OtherUsageModes: getStr('rootpage_setupPage_OtherUsageModes', en.rootpage_setupPage_OtherUsageModes),
        calendarLogin_setupPage_InvalidFile: getStr('calendarLogin_setupPage_InvalidFile', en.calendarLogin_setupPage_InvalidFile),
        calendarLogin_setupPage_LoginViaICSHeader: getStr('calendarLogin_setupPage_LoginViaICSHeader', en.calendarLogin_setupPage_LoginViaICSHeader),
        calendarLogin_setupPage_WhereIsICSHelper: getStr('calendarLogin_setupPage_WhereIsICSHelper', en.calendarLogin_setupPage_WhereIsICSHelper),
        calendarLogin_setupPage_WhereIsICSHelperDescription: getStr('calendarLogin_setupPage_WhereIsICSHelperDescription', en.calendarLogin_setupPage_WhereIsICSHelperDescription),
        calendarLogin_setupPage_ImportICSFileHelpText: getStr('calendarLogin_setupPage_ImportICSFileHelpText', en.calendarLogin_setupPage_ImportICSFileHelpText),
        calendarLogin_setupPage_ImportICSFileButton: getStr('calendarLogin_setupPage_ImportICSFileButton', en.calendarLogin_setupPage_ImportICSFileButton),
        topmenu_SemesterSelectorTitle: getStr('topmenu_SemesterSelectorTitle', en.topmenu_SemesterSelectorTitle),
        topmenu_SemesterToast: getStr('topmenu_SemesterToast', en.topmenu_SemesterToast),
        topmenu_AccountBalance: getStr('topmenu_AccountBalance', en.topmenu_AccountBalance),
        topmenu_UnreadMessagesBadge: getStr('topmenu_UnreadMessagesBadge', en.topmenu_UnreadMessagesBadge),
        topmenu_NoUnreadMessages: getStr('topmenu_NoUnreadMessages', en.topmenu_NoUnreadMessages),
        topmenu_MessagesTitle: getStr('topmenu_MessagesTitle', en.topmenu_MessagesTitle),
        topmenu_PaymentsTitle: getStr('topmenu_PaymentsTitle', en.topmenu_PaymentsTitle),
      );
    }
    catch(error){
      debugPrint("LanguagePack parse error for $countryId: $error");
      Future.delayed(Duration.zero,(){
        onLanguageOutdated();
      });
      return AppStrings.getLanguagePack();
    }
    // add to db
    AppStrings._downloadedSupportedLanguagesFlags.add(decodedLangPack.language_flag);
    AppStrings._downloadedSupportedLanguages.add(countryId);
    AppStrings._downloadedLanguages.addAll({countryId:decodedLangPack});

    return decodedLangPack;
  }

  static String toJson(LanguagePack lang){
    final json = conv.json.encode({
      'language_flag':lang.language_flag,
      'rootpage_setupPage_SelectLoginTypeHeader':lang.rootpage_setupPage_SelectLoginTypeHeader,
      'rootpage_setupPage_InstitutesSelection':lang.rootpage_setupPage_InstitutesSelection,
      'rootpage_setupPage_InstitutesSelectionDescription':lang.rootpage_setupPage_InstitutesSelectionDescription,
      'rootpage_setupPage_UrlLogin':lang.rootpage_setupPage_UrlLogin,
      'rootpage_setupPage_UrlLoginDescription':lang.rootpage_setupPage_UrlLoginDescription,
      'rootpage_setupPage_AppProblemReporting':lang.rootpage_setupPage_AppProblemReporting,
      'instituteSelection_setupPage_LoadingText':lang.instituteSelection_setupPage_LoadingText,
      'instituteSelection_setupPage_NoNetwork':lang.instituteSelection_setupPage_NoNetwork,
      'instituteSelection_setupPage_SelectValidInstitute':lang.instituteSelection_setupPage_SelectValidInstitute,
      'instituteSelection_setupPage_SelectInstitute':lang.instituteSelection_setupPage_SelectInstitute,
      'instituteSelection_setupPage_Search':lang.instituteSelection_setupPage_Search,
      'instituteSelection_setupPage_SearchNotFound':lang.instituteSelection_setupPage_SearchNotFound,
      'instituteSelection_setupPage_InstituteCantFindHelpText':lang.instituteSelection_setupPage_InstituteCantFindHelpText,
      'instituteSelection_setupPage_InstituteCantFindHelpTextDescription':lang.instituteSelection_setupPage_InstituteCantFindHelpTextDescription,
      'any_setupPage_GoBack':lang.any_setupPage_GoBack,
      'any_setupPage_ProceedLogin':lang.any_setupPage_ProceedLogin,
      'urlLogin_setupPage_InvalidUrl':lang.urlLogin_setupPage_InvalidUrl,
      'urlLogin_setupPage_LoginViaURlHeader':lang.urlLogin_setupPage_LoginViaURlHeader,
      'urlLogin_setupPage_InstituteNeptunUrl':lang.urlLogin_setupPage_InstituteNeptunUrl,
      'urlLogin_setupPage_InstituteNeptunUrlInvalid':lang.urlLogin_setupPage_InstituteNeptunUrlInvalid,
      'urlLogin_setupPage_WhereIsURLHelper':lang.urlLogin_setupPage_WhereIsURLHelper,
      'urlLogin_setupPage_WhereIsURLHelperDescription':lang.urlLogin_setupPage_WhereIsURLHelperDescription,
      'loginPage_setupPage_InvalidCredentials':lang.loginPage_setupPage_InvalidCredentials,
      'loginPage_setupPage_LoginHeaderText':lang.loginPage_setupPage_LoginHeaderText,
      'loginPage_setupPage_ActivityCacheInvalidHelper':lang.loginPage_setupPage_ActivityCacheInvalidHelper,
      'loginPage_setupPage_NeptunCode':lang.loginPage_setupPage_NeptunCode,
      'loginPage_setupPage_Password':lang.loginPage_setupPage_Password,
      'loginPage_setupPage_InvalidCredentialsEntered':lang.loginPage_setupPage_InvalidCredentialsEntered,
      'loginPage_setupPage_2faWarning':lang.loginPage_setupPage_2faWarning,
      'loginPage_setupPage_2faWarningDescription':lang.loginPage_setupPage_2faWarningDescription,
      'loginPage_setupPage_LogInButton':lang.loginPage_setupPage_LogInButton,
      'loginPage_setupPage_LoginInProgress':lang.loginPage_setupPage_LoginInProgress,
      'loginPage_setupPage_LoginInProgressSlow':lang.loginPage_setupPage_LoginInProgressSlow,
      'loginPage_setupPage_StudentWebFull':lang.loginPage_setupPage_StudentWebFull,
      'loginPage_setupPage_2faInvalidCode':lang.loginPage_setupPage_2faInvalidCode,
      'loginPage_setupPage_ConnectingStudentWeb':lang.loginPage_setupPage_ConnectingStudentWeb,
      'auth_sessionExpired_PleaseSignIn':lang.auth_sessionExpired_PleaseSignIn,
      'cache_showingFromCache':lang.cache_showingFromCache,
      'api_monthJan_Universal':lang.api_monthJan_Universal,
      'api_monthFeb_Universal':lang.api_monthFeb_Universal,
      'api_monthMar_Universal':lang.api_monthMar_Universal,
      'api_monthApr_Universal':lang.api_monthApr_Universal,
      'api_monthJun_Universal':lang.api_monthJun_Universal,
      'api_monthMay_Universal':lang.api_monthMay_Universal,
      'api_monthJul_Universal':lang.api_monthJul_Universal,
      'api_monthAug_Universal':lang.api_monthAug_Universal,
      'api_monthSep_Universal':lang.api_monthSep_Universal,
      'api_monthOkt_Universal':lang.api_monthOkt_Universal,
      'api_monthNov_Universal':lang.api_monthNov_Universal,
      'api_monthDec_Universal':lang.api_monthDec_Universal,
      'api_dayMon_Universal':lang.api_dayMon_Universal,
      'api_dayTue_Universal':lang.api_dayTue_Universal,
      'api_dayWed_Universal':lang.api_dayWed_Universal,
      'api_dayThu_Universal':lang.api_dayThu_Universal,
      'api_dayFri_Universal':lang.api_dayFri_Universal,
      'api_daySat_Universal':lang.api_daySat_Universal,
      'api_daySun_Universal':lang.api_daySun_Universal,
      'api_loadingScreenHintFriendly1_Universal':lang.api_loadingScreenHintFriendly1_Universal,
      'api_loadingScreenHintFriendly2_Universal':lang.api_loadingScreenHintFriendly2_Universal,
      'api_loadingScreenHintFriendly3_Universal':lang.api_loadingScreenHintFriendly3_Universal,
      'api_loadingScreenHintFriendly4_Universal':lang.api_loadingScreenHintFriendly4_Universal,
      'api_loadingScreenHintFriendly5_Universal':lang.api_loadingScreenHintFriendly5_Universal,
      'api_loadingScreenHintFriendly6_Universal':lang.api_loadingScreenHintFriendly6_Universal,
      'api_loadingScreenHintFriendly7_Universal':lang.api_loadingScreenHintFriendly7_Universal,
      'api_loadingScreenHint1_Universal':lang.api_loadingScreenHint1_Universal,
      'api_loadingScreenHint2_Universal':lang.api_loadingScreenHint2_Universal,
      'api_loadingScreenHint3_Universal':lang.api_loadingScreenHint3_Universal,
      'api_loadingScreenHint4_Universal':lang.api_loadingScreenHint4_Universal,
      'api_loadingScreenHint5_Universal':lang.api_loadingScreenHint5_Universal,
      'api_loadingScreenHint6_Universal':lang.api_loadingScreenHint6_Universal,
      'api_loadingScreenHint7_Universal':lang.api_loadingScreenHint7_Universal,
      'api_loadingScreenHintFriendlyMini1_Universal':lang.api_loadingScreenHintFriendlyMini1_Universal,
      'api_loadingScreenHintFriendlyMini2_Universal':lang.api_loadingScreenHintFriendlyMini2_Universal,
      'api_loadingScreenHintFriendlyMini3_Universal':lang.api_loadingScreenHintFriendlyMini3_Universal,
      'api_loadingScreenHintFriendlyMini4_Universal':lang.api_loadingScreenHintFriendlyMini4_Universal,
      'api_loadingScreenHintMini1_Universal':lang.api_loadingScreenHintMini1_Universal,
      'api_loadingScreenHintMini2_Universal':lang.api_loadingScreenHintMini2_Universal,
      'api_loadingScreenHintMini3_Universal':lang.api_loadingScreenHintMini3_Universal,
      'api_noData_Universal':lang.api_noData_Universal,
      'view_header_Calendar':lang.view_header_Calendar,
      'view_header_Messages':lang.view_header_Messages,
      'view_header_Payments':lang.view_header_Payments,
      'view_header_Periods':lang.view_header_Periods,
      'view_header_Subjects':lang.view_header_Subjects,
      'topheader_calendar_greetMessage_1to6':lang.topheader_calendar_greetMessage_1to6,
      'topheader_calendar_greetMessage_6to9':lang.topheader_calendar_greetMessage_6to9,
      'topheader_calendar_greetMessage_9to13':lang.topheader_calendar_greetMessage_9to13,
      'topheader_calendar_greetMessage_13to17':lang.topheader_calendar_greetMessage_13to17,
      'topheader_calendar_greetMessage_17to21':lang.topheader_calendar_greetMessage_17to21,
      'topheader_calendar_greetMessage_21to1':lang.topheader_calendar_greetMessage_21to1,
      'topheader_subjects_CreditsInSemester':lang.topheader_subjects_CreditsInSemester,
      'topheader_subjects_CreditsHeader':lang.topheader_subjects_CreditsHeader,
      'topheader_payments_TotalMoneySpent':lang.topheader_payments_TotalMoneySpent,
      'topheader_periods_ActiveText':lang.topheader_periods_ActiveText,
      'topheader_periods_ExpiredText':lang.topheader_periods_ExpiredText,
      'topheader_periods_FutureText':lang.topheader_periods_FutureText,
      'topheader_periods_MainHeader':lang.topheader_periods_MainHeader,
      'topheader_messages_UnreadMessages':lang.topheader_messages_UnreadMessages,
      'topmenu_buttons_Bugreport':lang.topmenu_buttons_Bugreport,
      'topmenu_buttons_Logout':lang.topmenu_buttons_Logout,
      'topmenu_buttons_Settings':lang.topmenu_buttons_Settings,
      'topmenu_buttons_SupportDev':lang.topmenu_buttons_SupportDev,
      'topmenu_Greet':lang.topmenu_Greet,
      'topmenu_LoginPlace':lang.topmenu_LoginPlace,
      'topmenu_buttons_LogoutSuccessToast':lang.topmenu_buttons_LogoutSuccessToast,
      'topmenu_buttons_Contacts':lang.topmenu_buttons_Contacts,
      'topmenu_SemesterSelectorTitle':lang.topmenu_SemesterSelectorTitle,
      'topmenu_SemesterToast':lang.topmenu_SemesterToast,
      'topmenu_AccountBalance':lang.topmenu_AccountBalance,
      'topmenu_UnreadMessagesBadge':lang.topmenu_UnreadMessagesBadge,
      'topmenu_NoUnreadMessages':lang.topmenu_NoUnreadMessages,
      'topmenu_MessagesTitle':lang.topmenu_MessagesTitle,
      'topmenu_PaymentsTitle':lang.topmenu_PaymentsTitle,
      'calendarPage_FreeDay':lang.calendarPage_FreeDay,
      'calendarPage_weekNav_ClassesThisWeekFull':lang.calendarPage_weekNav_ClassesThisWeekFull,
      'calendarPage_weekNav_ClassesThisWeekOneDay':lang.calendarPage_weekNav_ClassesThisWeekOneDay,
      'calendarPage_weekNav_StudyWeek':lang.calendarPage_weekNav_StudyWeek,
      'calendarPage_weekNav_ClassesThisWeekEmpty':lang.calendarPage_weekNav_ClassesThisWeekEmpty,
      'calendarPage_weekNav_ClassesThisWeekLoading':lang.calendarPage_weekNav_ClassesThisWeekLoading,
      'markbookPage_AverageDisplay':lang.markbookPage_AverageDisplay,
      'markbookPage_AverageScholarshipDisplay':lang.markbookPage_AverageScholarshipDisplay,
      'markbookPage_AppComputedNote':lang.markbookPage_AppComputedNote,
      'markbookPage_NoGrades':lang.markbookPage_NoGrades,
      'markbookPage_Empty':lang.markbookPage_Empty,
      'markbookPage_CompletedLine':lang.markbookPage_CompletedLine,
      'paymentPage_Empty':lang.paymentPage_Empty,
      'paymentPage_MoneyDisplay':lang.paymentPage_MoneyDisplay,
      'paymentPage_PaymentDeadlineTime':lang.paymentPage_PaymentDeadlineTime,
      'paymentPage_PaymentMissedTime':lang.paymentPage_PaymentMissedTime,
      'payment_currencyHuf':lang.payment_currencyHuf,
      'payment_unknownTransaction':lang.payment_unknownTransaction,
      'payment_unknownStatus':lang.payment_unknownStatus,
      'notif_payment_BodyNoDeadline':lang.notif_payment_BodyNoDeadline,
      'notif_payment_BodyWithDeadline':lang.notif_payment_BodyWithDeadline,
      'periodPage_ActiveDays':lang.periodPage_ActiveDays,
      'periodPage_Empty':lang.periodPage_Empty,
      'periodPage_Expired':lang.periodPage_Expired,
      'periodPage_ExpiredDays':lang.periodPage_ExpiredDays,
      'periodPage_StartDays':lang.periodPage_StartDays,
      'periodPage_Starts':lang.periodPage_Starts,
      'messagePage_SentBy':lang.messagePage_SentBy,
      'messagePage_Empty':lang.messagePage_Empty,
      'mail_search_Hint':lang.mail_search_Hint,
      'mail_filter_UnreadOnly':lang.mail_filter_UnreadOnly,
      'mail_filter_NoMatches':lang.mail_filter_NoMatches,
      'whatsChanged_Header':lang.whatsChanged_Header,
      'whatsChanged_NewMessages':lang.whatsChanged_NewMessages,
      'whatsChanged_GradeChanges':lang.whatsChanged_GradeChanges,
      'popup_case0_GhostGradeHeader':lang.popup_case0_GhostGradeHeader,
      'popup_case0_SelectGrade':lang.popup_case0_SelectGrade,
      'popup_caseAll_OkButton':lang.popup_caseAll_OkButton,
      'popup_case1_settingBottomText_InstallOrigin':lang.popup_case1_settingBottomText_InstallOrigin,
      'popup_case1_settingBottomText_InstallOrigin3rdParty':lang.popup_case1_settingBottomText_InstallOrigin3rdParty,
      'popup_case1_settingBottomText_InstallOriginGPlay':lang.popup_case1_settingBottomText_InstallOriginGPlay,
      'popup_case1_settingOption1_FamilyFriendlyLoadingText':lang.popup_case1_settingOption1_FamilyFriendlyLoadingText,
      'popup_case1_settingOption1_FamilyFriendlyLoadingTextDescription':lang.popup_case1_settingOption1_FamilyFriendlyLoadingTextDescription,
      'popup_case1_settingOption2_ExamNotifications':lang.popup_case1_settingOption2_ExamNotifications,
      'popup_case1_settingOption2_ExamNotificationsDescription':lang.popup_case1_settingOption2_ExamNotificationsDescription,
      'popup_case1_settingOption3_ClassNotifications':lang.popup_case1_settingOption3_ClassNotifications,
      'popup_case1_settingOption3_ClassNotificationsDescription':lang.popup_case1_settingOption3_ClassNotificationsDescription,
      'popup_case1_settingOption4_PaymentNotifications':lang.popup_case1_settingOption4_PaymentNotifications,
      'popup_case1_settingOption4_PaymentNotificationsDescription':lang.popup_case1_settingOption4_PaymentNotificationsDescription,
      'popup_case1_settingOption5_PeriodsNotifications':lang.popup_case1_settingOption5_PeriodsNotifications,
      'popup_case1_settingOption5_PeriodsNotificationsDescription':lang.popup_case1_settingOption5_PeriodsNotificationsDescription,
      'popup_case1_settingOption6_AppHaptics':lang.popup_case1_settingOption6_AppHaptics,
      'popup_case1_settingOption6_AppHapticsDescription':lang.popup_case1_settingOption6_AppHapticsDescription,
      'popup_case1_settingOption7_WeekOffset':lang.popup_case1_settingOption7_WeekOffset,
      'popup_case1_settingOption7_WeekOffsetDescription':lang.popup_case1_settingOption7_WeekOffsetDescription,
      'popup_case1_settingOption7_WeekOffsetAuto':lang.popup_case1_settingOption7_WeekOffsetAuto,
      'popup_case1_SettingsHeader':lang.popup_case1_SettingsHeader,
      'popup_case2_RateAppPopup':lang.popup_case2_RateAppPopup,
      'popup_case2_RateAppPopupDescription':lang.popup_case2_RateAppPopupDescription,
      'popup_case2_RateButton':lang.popup_case2_RateButton,
      'popup_case3_MessagesHeader':lang.popup_case3_MessagesHeader,
      'clickableText_OnCopy':lang.clickableText_OnCopy,
      'popup_case4_5_SubjectCode':lang.popup_case4_5_SubjectCode,
      'popup_case4_5_SubjectLocation':lang.popup_case4_5_SubjectLocation,
      'popup_case4_SubjectStartTime':lang.popup_case4_SubjectStartTime,
      'popup_case4_SubjectInfo':lang.popup_case4_SubjectInfo,
      'popup_case4_TeachedBy':lang.popup_case4_TeachedBy,
      'popup_case5_ExamInfo':lang.popup_case5_ExamInfo,
      'popup_case5_ExamStartTime':lang.popup_case5_ExamStartTime,
      'popup_case6_AccountError':lang.popup_case6_AccountError,
      'popup_case6_AccountErrorDescription':lang.popup_case6_AccountErrorDescription,
      'popup_case6_AccountErrorLogoutButton':lang.popup_case6_AccountErrorLogoutButton,
      'popup_case1_settingOption8_LangaugeSelection':lang.popup_case1_settingOption8_LangaugeSelection,
      'popup_case1_settingOption8_LangaugeSelectionDescription':lang.popup_case1_settingOption8_LangaugeSelectionDescription,
      'popup_case7_ButtonUpdateNow':lang.popup_case7_ButtonUpdateNow,
      'popup_case7_ObsolteAppVersion':lang.popup_case7_ObsolteAppVersion,
      'popup_case7_ObsolteAppVersionDescription':lang.popup_case7_ObsolteAppVersionDescription,
      'popup_caseDefault_InvalidPopupState':lang.popup_caseDefault_InvalidPopupState,
      'popup_case8_AcceptLanguageSuggestion':lang.popup_case8_AcceptLanguageSuggestion,
      'popup_case8_AcceptLanguageSuggestionDescription':lang.popup_case8_AcceptLanguageSuggestionDescription,
      'popup_case8_ButtonAcceptLang':lang.popup_case8_ButtonAcceptLang,
      'popup_case1_langSwap_DownloadingLang':lang.popup_case1_langSwap_DownloadingLang,
      'popup_case1_langSwap_DownloadingLangFail':lang.popup_case1_langSwap_DownloadingLangFail,
      'popup_case1_settingOption9_ThemeSwap':lang.popup_case1_settingOption9_ThemeSwap,
      'popup_case1_settingOption9_ThemeSwapDescription':lang.popup_case1_settingOption9_ThemeSwapDescription,
      'popup_case1_themeSwap_DownloadingThemeFail':lang.popup_case1_themeSwap_DownloadingThemeFail,
      'settings_section_AppearanceLanguage':lang.settings_section_AppearanceLanguage,
      'settings_section_FontScale':lang.settings_section_FontScale,
      'settings_section_Notifications':lang.settings_section_Notifications,
      'settings_section_BehaviorOther':lang.settings_section_BehaviorOther,
      'settings_section_CalendarFilters':lang.settings_section_CalendarFilters,
      'settings_calendar_ShowClasses':lang.settings_calendar_ShowClasses,
      'settings_calendar_ShowExams':lang.settings_calendar_ShowExams,
      'settings_calendar_ShowPeriods':lang.settings_calendar_ShowPeriods,
      'calendar_next48h_Header':lang.calendar_next48h_Header,
      'calendar_tasks_Header':lang.calendar_tasks_Header,
      'calendar_exams_Header':lang.calendar_exams_Header,
      'calendar_periods_Header':lang.calendar_periods_Header,
      'calendar_break_label':lang.calendar_break_label,
      'calendar_break_now':lang.calendar_break_now,
      'calendar_break_next':lang.calendar_break_next,
      'calendar_break_minutes':lang.calendar_break_minutes,
      'calendar_break_hours':lang.calendar_break_hours,
      'calendar_break_hoursMinutes':lang.calendar_break_hoursMinutes,
      'markbook_myCourses_Header':lang.markbook_myCourses_Header,
      'markbook_gradeHistory_Header':lang.markbook_gradeHistory_Header,
      'payment_invoices_Header':lang.payment_invoices_Header,
      'mail_translate_EN':lang.mail_translate_EN,
      'mail_translate_RU':lang.mail_translate_RU,
      'mail_translate_Disclaimer':lang.mail_translate_Disclaimer,
      'mail_translate_ShowOriginal':lang.mail_translate_ShowOriginal,
      'topmenu_TrainingSelectorTitle':lang.topmenu_TrainingSelectorTitle,
      'notif_title_Exam':lang.notif_title_Exam,
      'notif_title_Class':lang.notif_title_Class,
      'notif_title_Payment':lang.notif_title_Payment,
      'notif_title_Period':lang.notif_title_Period,
      'notif_period_Tomorrow':lang.notif_period_Tomorrow,
      'notif_period_Today':lang.notif_period_Today,
      'courseDetail_Type':lang.courseDetail_Type,
      'courseDetail_Teacher':lang.courseDetail_Teacher,
      'courseDetail_Room':lang.courseDetail_Room,
      'courseDetail_Subject':lang.courseDetail_Subject,
      'courseDetail_Result':lang.courseDetail_Result,
      'courseDetail_Close':lang.courseDetail_Close,
      'courseDetail_Unknown':lang.courseDetail_Unknown,
      'courseDetail_NoResultYet':lang.courseDetail_NoResultYet,
      'courseDetail_LoadingRoom':lang.courseDetail_LoadingRoom,
      'courseDetail_NoRoom':lang.courseDetail_NoRoom,
      'courseDetail_NoTeacher':lang.courseDetail_NoTeacher,
      'courseDetail_NoInternet':lang.courseDetail_NoInternet,
      'courseDetail_OfflineMode':lang.courseDetail_OfflineMode,
      'courseDetail_LoadError':lang.courseDetail_LoadError,
      'courseDetail_OldApiUnsupported':lang.courseDetail_OldApiUnsupported,
      'courseDetail_Unsupported':lang.courseDetail_Unsupported,
      'courseDetail_NotSpecified':lang.courseDetail_NotSpecified,
      'roomCode_Floor':lang.roomCode_Floor,
      'roomCode_Room':lang.roomCode_Room,
      'roomCode_Stream':lang.roomCode_Stream,
      'roomCode_Group':lang.roomCode_Group,
      'roomCode_Building_LD':lang.roomCode_Building_LD,
      'roomCode_Building_LE':lang.roomCode_Building_LE,
      'roomCode_Building_LK':lang.roomCode_Building_LK,
      'markbook_creditAbbrev':lang.markbook_creditAbbrev,
      'notif_exam_BodyToday':lang.notif_exam_BodyToday,
      'notif_exam_BodyTomorrow':lang.notif_exam_BodyTomorrow,
      'notif_exam_BodyInDays':lang.notif_exam_BodyInDays,
      'notif_class_BodyIn10Min':lang.notif_class_BodyIn10Min,
      'notif_class_BodyIn5Min':lang.notif_class_BodyIn5Min,
      'notif_class_BodyNow':lang.notif_class_BodyNow,
      'settings_fontScale_Label':lang.settings_fontScale_Label,
      'mail_error_Prefix':lang.mail_error_Prefix,
      'mail_error_EmptyMessage':lang.mail_error_EmptyMessage,
      'popup_case9_2faHeader':lang.popup_case9_2faHeader,
      'popup_case9_2faDescription':lang.popup_case9_2faDescription,
      'updater_NoInternet':lang.updater_NoInternet,
      'updater_Checking':lang.updater_Checking,
      'updater_FetchFailed':lang.updater_FetchFailed,
      'updater_UpToDate':lang.updater_UpToDate,
      'updater_CheckError':lang.updater_CheckError,
      'updater_DialogTitle':lang.updater_DialogTitle,
      'updater_DialogBody':lang.updater_DialogBody,
      'updater_Later':lang.updater_Later,
      'updater_Yes':lang.updater_Yes,
      'updater_NoApk':lang.updater_NoApk,
      'updater_DownloadError':lang.updater_DownloadError,
      'updater_Downloading':lang.updater_Downloading,
      'updater_DontClose':lang.updater_DontClose,
      'api_fallback_NoTitle':lang.api_fallback_NoTitle,
      'api_fallback_Unknown':lang.api_fallback_Unknown,
      'api_fallback_UnknownSubject':lang.api_fallback_UnknownSubject,
      'api_fallback_Task':lang.api_fallback_Task,
      'api_fallback_NoResult':lang.api_fallback_NoResult,
      'api_fallback_UnknownPeriod':lang.api_fallback_UnknownPeriod,
      'api_fallback_NoTermId':lang.api_fallback_NoTermId,
      'api_demo_Term1':lang.api_demo_Term1,
      'api_demo_Term2':lang.api_demo_Term2,
      'api_demo_Subject1':lang.api_demo_Subject1,
      'api_demo_GhostGrade':lang.api_demo_GhostGrade,
      'api_demo_Course':lang.api_demo_Course,
      'api_demo_Payment1':lang.api_demo_Payment1,
      'api_demo_Payment2':lang.api_demo_Payment2,
      'api_demo_MailSubject':lang.api_demo_MailSubject,
      'api_demo_MailBody':lang.api_demo_MailBody,
      'api_demo_MailSender':lang.api_demo_MailSender,
      'api_error_InvalidUrlOrHtml':lang.api_error_InvalidUrlOrHtml,
      'api_error_Network':lang.api_error_Network,
      'api_error_EmptyNeptunResponse':lang.api_error_EmptyNeptunResponse,
      'api_error_DownloadNetwork':lang.api_error_DownloadNetwork,
      'mail_preview_TapToLoadBody':lang.mail_preview_TapToLoadBody,
      'rootpage_setupPage_IcsImport':lang.rootpage_setupPage_IcsImport,
      'rootpage_setupPage_IcsImportDescription':lang.rootpage_setupPage_IcsImportDescription,
      'rootpage_setupPage_OtherUsageModes':lang.rootpage_setupPage_OtherUsageModes,
      'calendarLogin_setupPage_InvalidFile':lang.calendarLogin_setupPage_InvalidFile,
      'calendarLogin_setupPage_LoginViaICSHeader':lang.calendarLogin_setupPage_LoginViaICSHeader,
      'calendarLogin_setupPage_WhereIsICSHelper':lang.calendarLogin_setupPage_WhereIsICSHelper,
      'calendarLogin_setupPage_WhereIsICSHelperDescription':lang.calendarLogin_setupPage_WhereIsICSHelperDescription,
      'calendarLogin_setupPage_ImportICSFileHelpText':lang.calendarLogin_setupPage_ImportICSFileHelpText,
      'calendarLogin_setupPage_ImportICSFileButton':lang.calendarLogin_setupPage_ImportICSFileButton
    });
    return json;
  }
}

class LanguageManager{
  static Future<void> suggestLang(BuildContext context, VoidCallback? blur, VoidCallback? closeBlur)async{
    final cacheTime = await getInt('SuggestLangUpdateCacheTime') ?? -1;
    final nudgeAmount = await getInt('SuggestLangNudgeTime') ?? 0;
    if((DateTime.now().millisecondsSinceEpoch - cacheTime) > const Duration(hours: 24).inMilliseconds ||
      nudgeAmount >= 3){
      return;
    }
    final supportedUserLang = await Language.checkSupportedUserLanguage();
    final preferedLang = DataCache.getUserSelectedLanguage()!;
    if(!supportedUserLang || preferedLang != -1 || !DataCache.getHasNetwork()){
      // applied via native, or has a language preference, or no network
      return;
    }
    final deviceLang = Platform.localeName.split('_')[0].toLowerCase();
    var langPack = await Language.getLanguagePackById(await Language.getAllLanguages(), deviceLang);
    if(langPack == null){
      return;
    }
    //AppHaptics.attentionImpact();
    AppStrings.saveDownloadedLanguageData();
    AppStrings.setupPopupPreviews(langPack);
    await saveInt('SuggestLangUpdateCacheTime', DateTime.now().millisecondsSinceEpoch);
    await saveInt('SuggestLangNudgeTime', nudgeAmount + 1);
    PopupWidgetHandler(mode: 8, callback: (_)async{
      final idx = AppStrings.getAllLangCodes().indexOf(deviceLang);
      await DataCache.setUserSelectedLanguage(idx);
      AppStrings.initialize();
      Navigator.popUntil(context, (route) => route.willHandlePopInternally);
      Navigator.push(context, MaterialPageRoute(builder: (context) => const Splitter()));
    });
    PopupWidgetHandler.doPopup(context, blur: blur, closeBlur: closeBlur);
  }

  static Future<void> refreshAllDownloadedLangs()async{
    final cacheTime = await getInt('RefreshLangCacheTime') ?? -1;
    if((DateTime.now().millisecondsSinceEpoch - cacheTime) > const Duration(hours: 24).inMilliseconds || !DataCache.getHasNetwork()){
      // not enough time passed, or no network
      return;
    }
    final downloadedLangs = AppStrings.getAllDownloadedCodes();
    await saveInt('RefreshLangCacheTime', DateTime.now().millisecondsSinceEpoch);
    if(downloadedLangs.isEmpty){
      return;
    }
    final allLangs = await Language.getAllLanguages();
    for(var item in downloadedLangs){
      await Language.getLanguagePackById(allLangs, item);
    }
    AppStrings.saveDownloadedLanguageData();
    // once the app is reloaded, changes will be seen, but no need to make it instant, as nothing is missing
  }
}