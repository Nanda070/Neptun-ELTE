import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

Future<void> saveString(String key, String value) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString(key, value);
}

Future<void> saveInt(String key, int value) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setInt(key, value);
}

Future<void> saveFloat(String key, double value) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setDouble(key, value);
}

Future<void> saveStringList(String key, List<String> value) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(key, value);
}

Future<String?> getString(String key) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getString(key);
}

Future<int?> getInt(String key) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getInt(key);
}

Future<void> saveDouble(String key, double value) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setDouble(key, value);
}

Future<double?> getDouble(String key) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getDouble(key);
}

Future<List<String>?> getStringList(String key) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getStringList(key);
}

class DataCache{
  static Future<void> dataWipe() async{
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    // Keep Neptun username for login prefill; password must not survive logout.
    final keepUsername = (_instance._username != null && _instance._username!.isNotEmpty)
        ? _instance._username!
        : (await getString('Username') ?? '');

    await prefs.clear();
    await prefs.reload();
    await _secureStorage.delete(key: 'neptun_password');
    await _secureStorage.delete(key: 'neptun_jwt_token');
    await _secureStorage.delete(key: 'neptun_refresh_token');
    // Leftover device cookie can poison same-process re-login (false invalid credentials).
    if (keepUsername.isNotEmpty) {
      await setDeviceCookie(keepUsername, null);
    }
    _instance._localWipe();
    _instance._password = '';
    if (keepUsername.isNotEmpty) {
      await setUsername(keepUsername);
    }
  }

  /// Session expiry / logout: wipe auth only, **keep academic cache** so tabs
  /// can paint instantly after re-login (plan item 1). Prefer this over [dataWipe]
  /// unless a full reset is required.
  /// Wipes JWT / login flags; keeps academic cache and username.
  /// When [wipePassword] is false (opt-in remember password), keeps `neptun_password`.
  static Future<void> sessionWipeKeepCache({bool wipePassword = true}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final keepUsername = (_instance._username != null && _instance._username!.isNotEmpty)
        ? _instance._username!
        : (await getString('Username') ?? '');

    if (wipePassword) {
      await _secureStorage.delete(key: 'neptun_password');
      _instance._password = '';
    } else {
      final kept = await _secureStorage.read(key: 'neptun_password');
      _instance._password = kept ?? '';
    }
    await _secureStorage.delete(key: 'neptun_jwt_token');
    await _secureStorage.delete(key: 'neptun_refresh_token');
    await prefs.remove('Password');
    await prefs.remove('AccessToken');
    await prefs.setInt('HasLogin', 0);
    await prefs.setInt('SESSION_StartedAtMs', 0);
    if (keepUsername.isNotEmpty) {
      await setDeviceCookie(keepUsername, null);
    }

    _instance._accessToken = '';
    _instance._refreshToken = '';
    _instance._hasLogin = false;
    if (keepUsername.isNotEmpty) {
      _instance._username = keepUsername;
      await setUsername(keepUsername);
    }
  }

  static Future<void> dataWipeNoKeep()async{
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.reload();
  }

  void _localWipe(){
    _username = '';
    _password = '';
    _instituteUrl = '';
    _accessToken = '';
    _refreshToken = '';
    _hasNetwork = false;
    _hasLogin = false;
    _hasCachedCalendar = false;
    _hasCachedMarkbook = false;
    _hasCachedPayments = false;
    _hasCachedFirstWeekEpoch = false;
    _hasCachedPeriods = false;
    _firstweekOfSemesterEpoch = 0;
    _isDemoAccount = false;
    _icsLocationPath = '';
    _icsIsUploaded = false;
    _selectedTermId = null;
    _selectedTermName = null;
    _cachedTermsList = [];
    _studentTrainingId = null;
    _studentDisplayName = null;
    _studentTrainingName = null;
    _studentAvatarBase64 = null;
    _trainingLabelsJson = null;
    _studentCardCacheJson = null;
    setNeedFamilyFriendlyComments(_persistentSetting_familyFriendlyLoadingComments! ? 1 : 0);
    setNeedExamNotifications(_persistentSetting_showExamNotifications! ? 1 : 0);
    setNeedClassNotifications(_persistentSetting_showClassNotifications! ? 1 : 0);
    setClassNotif10(_persistentSetting_classNotif10! ? 1 : 0);
    setClassNotif5(_persistentSetting_classNotif5! ? 1 : 0);
    setClassNotif0(_persistentSetting_classNotif0! ? 1 : 0);
    setNeedPaymentsNotifications(_persistentSetting_showPaymentsNotifications! ? 1 : 0);
    setNeedPeriodsNotifications(_persistentSetting_showPeriodsNotifications! ? 1 : 0);
    setUserWeekOffset(_persistentSetting_weekOffset!);
    setUserSelectedLanguage(_persistentSetting_userSelectedLanguage!);
    setUserSelectedLanguageCode(_persistentSetting_userSelectedLanguageCode);
    setNeedsHaptics(_persistentSetting_needBetterHaptics! ? 1 : 0);
    setIsInstalledFromGPlay(_permanentConfiguration_isInstalledFromGooglePlay!);
    setDownloadedSupportedLanguages(_languageJsonSupportedLangs);
    setDownloadedSupportedLanguagesData(_languageJsonBatch);
    setPreferredAppTheme(_themePreference!);
    setAllDownloadedAppThemes(_themesJsonBatch);
    setHasSeenMailTranslateDisclaimer(_hasSeenMailTranslateDisclaimer);
  }

  static final DataCache _instance = DataCache();

  late String? _username = '';
  late String? _password = '';
  late String? _instituteUrl = '';
  late String? _accessToken = ''; //new systems token query
  late String? _refreshToken = '';
  String? _selectedTermId;
  String? _selectedTermName;
  List<String> _cachedTermsList = [];
  String? _studentTrainingId;
  String? _studentDisplayName;
  String? _studentTrainingName;
  String? _studentAvatarBase64;
  String? _trainingLabelsJson;
  /// Non-secret student-card claim / bank flags (+ light profile). No IBAN / nekId.
  String? _studentCardCacheJson;
  late bool _hasNetwork = false;
  late bool? _hasLogin = false;
  late bool? _hasCachedCalendar = false;
  late bool? _hasCachedMarkbook = false;
  late bool? _hasCachedPayments = false;
  late bool? _hasCachedPeriods = false;
  late bool? _hasCachedMail = false;
  late bool? _hasCachedFirstWeekEpoch = false;
  late int? _firstweekOfSemesterEpoch = 0;
  late bool? _isDemoAccount = false;

  bool _isModernApi = false;

  static bool getIsModernApi() {
    return _instance._isModernApi;
  }

  static Future<void> setIsModernApi(bool value) async {
    _instance._isModernApi = value;
    await saveInt('IsModernApi', value ? 1 : 0);
  }

  Future<void> saveBool(String key, bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<bool?> getBool(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key);
  }
  double _fontScale = 1.0;
  static double getFontScale() {
    return _instance._fontScale;
  }

  static Future<void> setFontScale(double scale) async {
    _instance._fontScale = scale;
    await saveDouble('FontScale', scale);
  }

  double? _accountBalance;
  String? _accountBalanceCurrency = 'HUF';
  int _unreadMailCount = 0;

  /// Pending “What’s Changed” counts after the last successful network refresh.
  int _whatsChangedNewMails = 0;
  int _whatsChangedGradeChanges = 0;

  late bool? _persistentSetting_familyFriendlyLoadingComments = false;
  late bool? _persistentSetting_showExamNotifications = true;
  late bool? _persistentSetting_showClassNotifications = true;
  late bool? _persistentSetting_classNotif10 = true;
  late bool? _persistentSetting_classNotif5 = true;
  late bool? _persistentSetting_classNotif0 = true;
  late bool? _persistentSetting_showPaymentsNotifications = true;
  late bool? _persistentSetting_showPeriodsNotifications = true;
  late int? _persistentSetting_weekOffset = 0;
  late bool? _persistentSetting_needBetterHaptics = true;
  late bool? _persistentSetting_rememberPasswordOnDevice = false;
  late int? _persistentSetting_userSelectedLanguage = -1;
  String? _persistentSetting_userSelectedLanguageCode;

  late int? _permanentConfiguration_isInstalledFromGooglePlay = 0;



  late List<String> _languageJsonSupportedLangs = [];
  late List<String> _languageJsonBatch = [];

  late String? _themePreference = '';
  late List<String> _themesJsonBatch = [];

  late String? _icsLocationPath = '';
  late bool? _icsIsUploaded = false;

  static Future<void> loadData() async{return _instance._loadData();}

  Future<void> _loadData() async{
    int? tmp;

    _username = await getString('Username');
    _instituteUrl = await getString('URL');

    _password = await _secureStorage.read(key: 'neptun_password');


    if (_password == null) {
      String? oldPassword = await getString('Password');
      if (oldPassword != null && oldPassword.isNotEmpty) {
        _password = oldPassword;
        await _secureStorage.write(key: 'neptun_password', value: oldPassword);

      }
    }

    _accessToken = await _secureStorage.read(key: 'neptun_jwt_token');

    if (_accessToken == null) {
      String? oldToken = await getString('AccessToken');
      if (oldToken != null && oldToken.isNotEmpty) {
        _accessToken = oldToken;
        await _secureStorage.write(key: 'neptun_jwt_token', value: oldToken);
      }
    }

    _refreshToken = await _secureStorage.read(key: 'neptun_refresh_token');

    tmp = await getInt('IsModernApi');
    _isModernApi = tmp != null && tmp != 0;

    tmp = await getInt('HasLogin');
    _hasLogin = tmp != null && tmp != 0;

    tmp = await getInt('HasCachedCalendar');
    _hasCachedCalendar = tmp != null && tmp != 0;

    tmp = await getInt('HasCachedMarkbook');
    _hasCachedMarkbook = tmp != null && tmp != 0;

    tmp = await getInt('HasCachedPayments');
    _hasCachedPayments = tmp != null && tmp != 0;

    tmp = await getInt('HasCachedPeriods');
    _hasCachedPeriods = tmp != null && tmp != 0;

    tmp = await getInt('HasCachedMail');
    _hasCachedMail = tmp != null && tmp != 0;

    final connResults = await Connectivity().checkConnectivity();
    _hasNetwork = connResults.any((r) => r != ConnectivityResult.none);
    Connectivity().onConnectivityChanged.listen((event) {
      _hasNetwork = event.any((r) => r != ConnectivityResult.none);
    });

    tmp = await getInt('HasCachedFirstWeekEpoch');
    _hasCachedFirstWeekEpoch = tmp != null && tmp != 0;

    tmp = await getInt('FirstWeekOfSemesterEpoch');
    _firstweekOfSemesterEpoch = tmp ?? 0;

    tmp = await getInt('IsDemoAccount');
    _isDemoAccount = tmp != null && tmp != 0;

    final prefs = await SharedPreferences.getInstance();
    _displayClasses = prefs.getBool('CALENDAR_DisplayClasses') ?? true;
    _displayExams = prefs.getBool('CALENDAR_DisplayExams') ?? true;
    _displayPeriods = prefs.getBool('CALENDAR_DisplayPeriods') ?? true;
    _hasSeenMailTranslateDisclaimer = prefs.getBool('hasSeenMailTranslateDisclaimer') ?? false;

    tmp = await getInt('SETTING_IsFamilyFriendlyLoading');
    _persistentSetting_familyFriendlyLoadingComments = tmp != null && tmp != 0;
    if(tmp == null){
      _persistentSetting_familyFriendlyLoadingComments = false;  // this is the default value
    }

    tmp = await getInt('SETTING_IsNeedExamNotifications');
    _persistentSetting_showExamNotifications = tmp != null && tmp != 0;
    if(tmp == null){
      _persistentSetting_showExamNotifications = true;  // this is the default value, not false
    }

    tmp = await getInt('SETTING_IsNeedClassNotifications');
    _persistentSetting_showClassNotifications = tmp != null && tmp != 0;
    if(tmp == null){
      _persistentSetting_showClassNotifications = true;  // this is the default value, not false
    }

    tmp = await getInt('SETTING_ClassNotif10');
    _persistentSetting_classNotif10 = tmp == null || tmp != 0;
    tmp = await getInt('SETTING_ClassNotif5');
    _persistentSetting_classNotif5 = tmp == null || tmp != 0;
    tmp = await getInt('SETTING_ClassNotif0');
    _persistentSetting_classNotif0 = tmp == null || tmp != 0;

    tmp = await getInt('SETTING_IsNeedPaymentsNotifications');
    _persistentSetting_showPaymentsNotifications = tmp != null && tmp != 0;
    if(tmp == null){
      _persistentSetting_showPaymentsNotifications = true;  // this is the default value, not false
    }

    tmp = await getInt('SETTING_IsNeedPeriodsNotifications');
    _persistentSetting_showPeriodsNotifications = tmp != null && tmp != 0;
    if(tmp == null){
      _persistentSetting_showPeriodsNotifications = true;  // this is the default value, not false
    }

    tmp = await getInt('SETTING_NeedHaptics');
    _persistentSetting_needBetterHaptics = tmp != null && tmp != 0;
    if(tmp == null){
      _persistentSetting_needBetterHaptics = true;
    }

    tmp = await getInt('SETTING_RememberPasswordOnDevice');
    _persistentSetting_rememberPasswordOnDevice = tmp != null && tmp != 0;

    tmp = await getInt('SETTING_UserWeekOffset');
    _persistentSetting_weekOffset = tmp ?? 0;

    tmp = await getInt('SETTING_UserSelectedLanguage');
    _persistentSetting_userSelectedLanguage = tmp ?? -1;

    _persistentSetting_userSelectedLanguageCode = await getString('SETTING_UserSelectedLanguageCode');

    _selectedTermId = await getString('SELECTED_TermId');
    _selectedTermName = await getString('SELECTED_TermName');
    _cachedTermsList = await getStringList('CACHED_TermsList') ?? [];
    _studentTrainingId = await getString('STUDENT_TrainingId');
    _studentDisplayName = await getString('STUDENT_DisplayName');
    _studentTrainingName = await getString('STUDENT_TrainingName');
    _studentAvatarBase64 = await getString('STUDENT_AvatarBase64');
    _trainingLabelsJson = await getString('STUDENT_TrainingLabelsJson') ?? '{}';
    _studentCardCacheJson = await getString('STUDENT_CardCacheJson');

    tmp = await getInt('CONFIG_IsInstalledFromGPlay');
    _permanentConfiguration_isInstalledFromGooglePlay = tmp ?? 0;


    _languageJsonSupportedLangs = await getStringList('LANGUAGE_DownloadedSupportedLangs') ?? [];
    _languageJsonBatch = await getStringList('LANGUAGE_DownloadedLanguagesJsonBatch') ?? [];

    _icsLocationPath = await getString('ICS_FileLocation') ?? '';

    tmp = await getInt('ICS_HasIcsUpload');
    _icsIsUploaded = tmp != null && tmp != 0;

    final fs = await getDouble('FontScale');
    _fontScale = fs ?? 1.0;

    _accountBalance = await getDouble('ACCOUNT_Balance');
    _accountBalanceCurrency = await getString('ACCOUNT_BalanceCurrency') ?? 'HUF';
    final unread = await getInt('CachedMailsUnread');
    _unreadMailCount = unread ?? 0;

    _whatsChangedNewMails = (await getInt('WHATSCHANGED_NewMails')) ?? 0;
    _whatsChangedGradeChanges = (await getInt('WHATSCHANGED_GradeChanges')) ?? 0;
  }

  static Future<void> loadThemeOnly()async{
    _instance._themePreference = await getString('THEME_AppTheme') ?? 'Dark';
    _instance._themesJsonBatch = await getStringList('THEME_ThemesJsonBatch') ?? [];
  }

  static String? getUsername(){return _instance._username;}
  static Future<void> setUsername(String? value) async{
    _instance._username = value;
    await saveString('Username', value.toString());
  }

  // A kritikus dolgoknak (jelszó, token) létrehozzuk a Secure Storage-ot
  static const _secureStorage = FlutterSecureStorage();
  // PASSWORD HANDLING:



// SZINKRON GETTER! Így a többi fájl nem fog pirosodni,
  // mert azonnal a memóriából kapják meg az adatot.
  static String? getPassword() {
    return _instance._password;
  }

  // ASZINKRON SETTER (Ide mentjük el biztonságosan)
  static Future<void> setPassword(String? password) async {
    _instance._password = password; // Frissítjük a memóriában is

    if (password == null) {
      await _secureStorage.delete(key: 'neptun_password');
    } else {
      await _secureStorage.write(key: 'neptun_password', value: password);
    }
  }

  static String? getInstituteUrl(){return _instance._instituteUrl;}

  static Future<void> setInstituteUrl(String? value) async{
    _instance._instituteUrl = value;
    await saveString('URL', value.toString());
  }


// ASZINKRON SETTER
  static Future<void> setAccessToken(String? token) async {
    _instance._accessToken = token; // Frissítjük a memóriában

    if (token == null) {
      await _secureStorage.delete(key: 'neptun_jwt_token');
    } else {
      await _secureStorage.write(key: 'neptun_jwt_token', value: token);
    }
  }

  static String? getAccessToken() {
    return _instance._accessToken;
  }

  static String? getRefreshToken() {
    return _instance._refreshToken;
  }

  static Future<void> setRefreshToken(String? token) async {
    _instance._refreshToken = token;
    if (token == null) {
      await _secureStorage.delete(key: 'neptun_refresh_token');
    } else {
      await _secureStorage.write(key: 'neptun_refresh_token', value: token);
    }
  }

  static Future<String?> getDeviceCookie(String username) async {
    return await _secureStorage.read(key: 'devicecookie_${username.toUpperCase()}');
  }

  static Future<void> setDeviceCookie(String username, String? cookieValue) async {
    if (cookieValue == null) {
      await _secureStorage.delete(key: 'devicecookie_${username.toUpperCase()}');
    } else {
      await _secureStorage.write(key: 'devicecookie_${username.toUpperCase()}', value: cookieValue);
    }
  }

// --- SECURE DATA clear ---
  static Future<void> clearSecureData() async {
    _instance._password = null;
    _instance._accessToken = null;
    _instance._refreshToken = null;
    await _secureStorage.deleteAll();
  }

  static bool getHasNetwork(){return _instance._hasNetwork;}

  static bool? getHasLogin(){return _instance._hasLogin;}
  static Future<void> setHasLogin(int? value) async {
    _instance._hasLogin = value != null && value != 0;
    await saveInt('HasLogin', value ?? 0);
  }

  static bool? getHasCachedCalendar(){return _instance._hasCachedCalendar;}
  static Future<void> setHasCachedCalendar(int? value) async {
    _instance._hasCachedCalendar = value != null && value != 0;
    await saveInt('HasCachedCalendar', value ?? 0);
  }

  static bool? getHasCachedMarkbook(){return _instance._hasCachedMarkbook;}
  static Future<void> setHasCachedMarkbook(int? value) async {
    _instance._hasCachedMarkbook = value != null && value != 0;
    await saveInt('HasCachedMarkbook', value ?? 0);
  }

  static bool? getHasCachedPayments(){return _instance._hasCachedPayments;}
  static Future<void> setHasCachedPayments(int? value) async{
    _instance._hasCachedPayments = value != null && value != 0;
    await saveInt('HasCachedPayments', value ?? 0);
  }

  static bool? getHasCachedPeriods(){return _instance._hasCachedPeriods;}
  static Future<void> setHasCachedPeriods(int? value) async{
    _instance._hasCachedPeriods = value != null && value != 0;
    await saveInt('HasCachedPeriods', value ?? 0);
  }

  static bool? getHasCachedMail(){return _instance._hasCachedMail;}
  static Future<void> setHasCachedMail(int? value) async{
    _instance._hasCachedMail = value != null && value != 0;
    await saveInt('HasCachedMail', value ?? 0);
  }

  static double? getAccountBalance() => _instance._accountBalance;
  static String getAccountBalanceCurrency() => _instance._accountBalanceCurrency ?? 'HUF';
  static Future<void> setAccountBalance(double? value, {String currency = 'HUF'}) async {
    _instance._accountBalance = value;
    _instance._accountBalanceCurrency = currency;
    if (value != null) {
      await saveDouble('ACCOUNT_Balance', value);
      await saveString('ACCOUNT_BalanceCurrency', currency);
    }
  }

  static int getUnreadMailCount() => _instance._unreadMailCount;
  static Future<void> setUnreadMailCount(int value) async {
    _instance._unreadMailCount = value;
    await saveInt('CachedMailsUnread', value);
  }

  /// Stable mail id set for What’s Changed (item 9). Empty until first successful refresh.
  static const String snapshotMailIdsKey = 'SNAPSHOT_MailIds';
  static const String snapshotMailReadyKey = 'SNAPSHOT_MailReady';
  static const String snapshotGradeKeysKey = 'SNAPSHOT_GradeKeys';
  static const String snapshotGradesReadyKey = 'SNAPSHOT_GradesReady';

  static int getWhatsChangedNewMails() => _instance._whatsChangedNewMails;
  static int getWhatsChangedGradeChanges() => _instance._whatsChangedGradeChanges;

  static Future<void> clearWhatsChangedNewMails() async {
    _instance._whatsChangedNewMails = 0;
    await saveInt('WHATSCHANGED_NewMails', 0);
  }

  static Future<void> clearWhatsChangedGradeChanges() async {
    _instance._whatsChangedGradeChanges = 0;
    await saveInt('WHATSCHANGED_GradeChanges', 0);
  }

  /// Encode markbook row for snapshot diffs: `(subjectCode, grade, termId)`.
  static String gradeSnapshotKey({
    required String subjectCode,
    required int grade,
    required String termId,
  }) {
    final code = subjectCode.trim().isEmpty ? '_' : subjectCode.trim();
    final term = termId.trim().isEmpty ? '_' : termId.trim();
    return '$code|$grade|$term';
  }

  /// After a successful mail network refresh: first install seeds baseline (no banner);
  /// later refreshes set pending “N new messages” = ids in [currentIds] not in the prior snapshot.
  static Future<int> diffAndSaveMailSnapshot(Iterable<String> currentIds) async {
    final list = currentIds.where((id) => id.trim().isNotEmpty).toList();
    final ready = await _instance.getBool(snapshotMailReadyKey) ?? false;
    if (!ready) {
      await saveStringList(snapshotMailIdsKey, list);
      await _instance.saveBool(snapshotMailReadyKey, true);
      _instance._whatsChangedNewMails = 0;
      await saveInt('WHATSCHANGED_NewMails', 0);
      return 0;
    }
    final prev = (await getStringList(snapshotMailIdsKey) ?? []).toSet();
    final n = list.where((id) => !prev.contains(id)).length;
    await saveStringList(snapshotMailIdsKey, list);
    _instance._whatsChangedNewMails = n;
    await saveInt('WHATSCHANGED_NewMails', n);
    return n;
  }

  /// After a successful markbook network refresh: first install seeds baseline (no banner);
  /// later refreshes set pending “N grade changes” = triples not in the prior snapshot.
  static Future<int> diffAndSaveGradeSnapshot(Iterable<String> currentKeys) async {
    final list = currentKeys.where((k) => k.trim().isNotEmpty).toList();
    final ready = await _instance.getBool(snapshotGradesReadyKey) ?? false;
    if (!ready) {
      await saveStringList(snapshotGradeKeysKey, list);
      await _instance.saveBool(snapshotGradesReadyKey, true);
      _instance._whatsChangedGradeChanges = 0;
      await saveInt('WHATSCHANGED_GradeChanges', 0);
      return 0;
    }
    final prev = (await getStringList(snapshotGradeKeysKey) ?? []).toSet();
    final n = list.where((k) => !prev.contains(k)).length;
    await saveStringList(snapshotGradeKeysKey, list);
    _instance._whatsChangedGradeChanges = n;
    await saveInt('WHATSCHANGED_GradeChanges', n);
    return n;
  }

  static bool? getHasCachedFirstWeekEpoch(){return _instance._hasCachedFirstWeekEpoch;}
  static Future<void> setHasCachedFirstWeekEpoch(int? value) async{
    _instance._hasCachedFirstWeekEpoch = value != null && value != 0;
    await saveInt('HasCachedFirstWeekEpoch', value ?? 0);
  }

  static int? getFirstWeekEpoch(){return _instance._firstweekOfSemesterEpoch;}
  static Future<void> setFirstWeekEpoch(int? value) async{
    _instance._firstweekOfSemesterEpoch = value ?? 0;
    await saveInt('FirstWeekOfSemesterEpoch', value ?? 0);
  }

  static bool? getIsDemoAccount(){return _instance._isDemoAccount;}
  static Future<void> setIsDemoAccount(int? value) async{
    _instance._isDemoAccount = value != null && value != 0;
    await saveInt('IsDemoAccount', value ?? 0);
  }

  static bool? getRememberPasswordOnDevice() =>
      _instance._persistentSetting_rememberPasswordOnDevice;

  static Future<void> setRememberPasswordOnDevice(int? value) async {
    final on = value != null && value != 0;
    _instance._persistentSetting_rememberPasswordOnDevice = on;
    await saveInt('SETTING_RememberPasswordOnDevice', on ? 1 : 0);
    if (!on) {
      await setPassword(null);
    }
  }

  static bool? getNeedFamilyFriendlyComments(){return _instance._persistentSetting_familyFriendlyLoadingComments;}
  static Future<void> setNeedFamilyFriendlyComments(int? value) async{
    _instance._persistentSetting_familyFriendlyLoadingComments = value != null && value != 0;
    await saveInt('SETTING_IsFamilyFriendlyLoading', value ?? 0);
  }

  static bool? getNeedExamNotifications(){return _instance._persistentSetting_showExamNotifications;}
  static Future<void> setNeedExamNotifications(int? value) async{
    _instance._persistentSetting_showExamNotifications = value != null && value != 0;
    await saveInt('SETTING_IsNeedExamNotifications', value ?? 1);
  }

  static bool? getNeedClassNotifications(){return _instance._persistentSetting_showClassNotifications;}
  static Future<void> setNeedClassNotifications(int? value) async{
    _instance._persistentSetting_showClassNotifications = value != null && value != 0;
    await saveInt('SETTING_IsNeedClassNotifications', value ?? 1);
  }

  static bool? getClassNotif10(){return _instance._persistentSetting_classNotif10;}
  static Future<void> setClassNotif10(int? value) async{
    _instance._persistentSetting_classNotif10 = value == null || value != 0;
    await saveInt('SETTING_ClassNotif10', value ?? 1);
  }

  static bool? getClassNotif5(){return _instance._persistentSetting_classNotif5;}
  static Future<void> setClassNotif5(int? value) async{
    _instance._persistentSetting_classNotif5 = value == null || value != 0;
    await saveInt('SETTING_ClassNotif5', value ?? 1);
  }

  static bool? getClassNotif0(){return _instance._persistentSetting_classNotif0;}
  static Future<void> setClassNotif0(int? value) async{
    _instance._persistentSetting_classNotif0 = value == null || value != 0;
    await saveInt('SETTING_ClassNotif0', value ?? 1);
  }

  static bool? getNeedPaymentsNotifications(){return _instance._persistentSetting_showPaymentsNotifications;}
  static Future<void> setNeedPaymentsNotifications(int? value) async{
    _instance._persistentSetting_showPaymentsNotifications = value != null && value != 0;
    await saveInt('SETTING_IsNeedPaymentsNotifications', value ?? 1);
  }

  static bool? getNeedPeriodsNotifications(){return _instance._persistentSetting_showPeriodsNotifications;}
  static Future<void> setNeedPeriodsNotifications(int? value) async{
    _instance._persistentSetting_showPeriodsNotifications = value != null && value != 0;
    await saveInt('SETTING_IsNeedPeriodsNotifications', value ?? 1);
  }

  static int? getUserWeekOffset(){return _instance._persistentSetting_weekOffset;}
  static Future<void> setUserWeekOffset(int? value)async{
    _instance._persistentSetting_weekOffset = value ?? 0;
    await saveInt('SETTING_UserWeekOffset', value ?? 0);
  }

  static int? getUserSelectedLanguage(){return _instance._persistentSetting_userSelectedLanguage;}
  static Future<void> setUserSelectedLanguage(int? value)async{
    _instance._persistentSetting_userSelectedLanguage = value ?? -1;
    await saveInt('SETTING_UserSelectedLanguage', value ?? -1);
  }

  static String? getUserSelectedLanguageCode() => _instance._persistentSetting_userSelectedLanguageCode;
  static Future<void> setUserSelectedLanguageCode(String? value) async {
    _instance._persistentSetting_userSelectedLanguageCode = value;
    if (value == null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('SETTING_UserSelectedLanguageCode');
    } else {
      await saveString('SETTING_UserSelectedLanguageCode', value);
    }
  }

  static String? getSelectedTermId() => _instance._selectedTermId;
  static Future<void> setSelectedTermId(String? value) async {
    _instance._selectedTermId = value;
    if (value == null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('SELECTED_TermId');
    } else {
      await saveString('SELECTED_TermId', value);
    }
  }

  static String? getSelectedTermName() => _instance._selectedTermName;
  static Future<void> setSelectedTermName(String? value) async {
    _instance._selectedTermName = value;
    if (value == null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('SELECTED_TermName');
    } else {
      await saveString('SELECTED_TermName', value);
    }
  }

  static List<String> getCachedTermsRaw() => _instance._cachedTermsList;
  static Future<void> setCachedTermsRaw(List<String> value) async {
    _instance._cachedTermsList = value;
    await saveStringList('CACHED_TermsList', value);
  }

  static String? getStudentTrainingId() => _instance._studentTrainingId;
  static Future<void> setStudentTrainingId(String? value) async {
    _instance._studentTrainingId = value;
    if (value == null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('STUDENT_TrainingId');
    } else {
      await saveString('STUDENT_TrainingId', value);
    }
  }

  static String? getStudentDisplayName() => _instance._studentDisplayName;
  static Future<void> setStudentDisplayName(String? value) async {
    _instance._studentDisplayName = value;
    if (value == null || value.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('STUDENT_DisplayName');
    } else {
      await saveString('STUDENT_DisplayName', value);
    }
  }

  static String? getStudentTrainingName() => _instance._studentTrainingName;
  static Future<void> setStudentTrainingName(String? value) async {
    _instance._studentTrainingName = value;
    if (value == null || value.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('STUDENT_TrainingName');
    } else {
      await saveString('STUDENT_TrainingName', value);
    }
  }

  /// Base64 JPEG from HWEB `userAvatar.image` / `GetUserAvatar` (no `data:` URI prefix).
  static String? getStudentAvatarBase64() => _instance._studentAvatarBase64;
  static Future<void> setStudentAvatarBase64(String? value) async {
    _instance._studentAvatarBase64 = value;
    if (value == null || value.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('STUDENT_AvatarBase64');
    } else {
      await saveString('STUDENT_AvatarBase64', value);
    }
  }

  static String getTrainingLabelsJson() => _instance._trainingLabelsJson ?? '{}';
  static Future<void> setTrainingLabelsJson(String? value) async {
    _instance._trainingLabelsJson = value ?? '{}';
    await saveString('STUDENT_TrainingLabelsJson', _instance._trainingLabelsJson!);
  }

  /// Cached non-secret claim/bank flags for offline drawer/Settings (plan item 12).
  static String? getStudentCardCacheJson() => _instance._studentCardCacheJson;
  static Future<void> setStudentCardCacheJson(String? value) async {
    _instance._studentCardCacheJson = value;
    if (value == null || value.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('STUDENT_CardCacheJson');
    } else {
      await saveString('STUDENT_CardCacheJson', value);
    }
  }

  static bool? getNeedsHaptics(){return _instance._persistentSetting_needBetterHaptics;}
  static Future<void> setNeedsHaptics(int? value)async{
    _instance._persistentSetting_needBetterHaptics =  value != null && value != 0;
    await saveInt('SETTING_NeedHaptics', value ?? 1);
  }

  static int? getIsInstalledFromGPlay({bool excludeDefaultState = true}){return _instance._permanentConfiguration_isInstalledFromGooglePlay! - (excludeDefaultState ? 1 : 0);}
  static Future<void> setIsInstalledFromGPlay(int? value)async{
    _instance._permanentConfiguration_isInstalledFromGooglePlay = value ?? 0;
    await saveInt('CONFIG_IsInstalledFromGPlay', value ?? 0);
  }

  static List<String> getDownloadedSupportedLanguages(){return _instance._languageJsonSupportedLangs;}
  static Future<void> setDownloadedSupportedLanguages(List<String>? value)async{
    _instance._languageJsonSupportedLangs = value ?? [];
    await saveStringList('LANGUAGE_DownloadedSupportedLangs', value ?? []);
  }

  static List<String> getDownloadedSupportedLanguagesData(){return _instance._languageJsonBatch;}
  static Future<void> setDownloadedSupportedLanguagesData(List<String>? value)async{
    _instance._languageJsonBatch = value ?? [];
    await saveStringList('LANGUAGE_DownloadedLanguagesJsonBatch', value ?? []);
  }

  static String? getPreferredAppTheme(){return _instance._themePreference;}
  static Future<void> setPreferredAppTheme(String? value)async{
    _instance._themePreference = value ?? 'Dark';
    await saveString('THEME_AppTheme', value ?? 'Dark');
  }

  static List<String> getAllDownloadedAppThemes(){return _instance._themesJsonBatch;}
  static Future<void> setAllDownloadedAppThemes(List<String>? value)async{
    _instance._themesJsonBatch = value ?? [];
    await saveStringList('THEME_ThemesJsonBatch', value ?? []);
  }

  static String? getICSFileLocation(){return _instance._icsLocationPath;}
  static Future<void> setICSFileLocation(String? value)async{
    _instance._icsLocationPath = value ?? '';
    await saveString('ICS_FileLocation', value ?? '');
  }

  static bool? getHasICSFile(){return _instance._icsIsUploaded;}
  static Future<void> setHasICSFile(bool? value)async{
    _instance._icsIsUploaded = value ?? false;
    await saveInt('ICS_HasIcsUpload', value == true ? 1 : 0);
  }
  // Saját memóriaváltozók, hogy ne kelljen a _prefs-re támaszkodni
  static bool? _displayClasses = true;
  static bool? _displayExams = true;
  static bool? _displayPeriods = true;
  static bool _hasSeenMailTranslateDisclaimer = false;

  static bool? getDisplayClasses() => _displayClasses;
  static Future<void> setDisplayClasses(bool? value) async {
    _displayClasses = value ?? true;
    // Saját mentés közvetlenül a SharedPreferences-be (nem kell hozzá saveBool)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('CALENDAR_DisplayClasses', _displayClasses!);
  }

  static bool? getDisplayExams() => _displayExams;
  static Future<void> setDisplayExams(bool? value) async {
    _displayExams = value ?? true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('CALENDAR_DisplayExams', _displayExams!);
  }

  static bool? getDisplayPeriods() => _displayPeriods;
  static Future<void> setDisplayPeriods(bool? value) async {
    _displayPeriods = value ?? true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('CALENDAR_DisplayPeriods', _displayPeriods!);
  }

  /// First-time mail machine-translate inaccuracy notice (device-level).
  static bool getHasSeenMailTranslateDisclaimer() => _hasSeenMailTranslateDisclaimer;
  static Future<void> setHasSeenMailTranslateDisclaimer(bool value) async {
    _hasSeenMailTranslateDisclaimer = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenMailTranslateDisclaimer', value);
  }

}
