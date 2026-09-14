import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';
import 'package:neptun2/API/ics_calendar.dart';
import 'package:neptun2/MailElements/mail_element_widget.dart';
import 'package:neptun2/app_navigator.dart';
import 'package:neptun2/colors.dart';
import 'package:neptun2/language.dart';
import 'package:neptun2/notifications.dart';
import 'package:neptun2/Misc/emojirich_text.dart';
import 'package:neptun2/PaymentsElements/payment_element_widget.dart';
import '../API/api_coms.dart' as api;
import '../Misc/auto_updater.dart';
import '../haptics.dart';
import '../storage.dart' as storage;
import '../TimetableElements/timetable_element_widget.dart' as t_table;
import '../MarkbookElements/markbook_element_widget.dart' as mbook;
import '../PeriodsElements/periods_element_widget.dart' as priods;
import '../Navigator/bottomnavigator.dart' as bottomnav;
import '../Navigator/topnavigator.dart' as topnav;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../Pages/startup_page.dart' as root_page;
import '../Misc/app_drawer.dart';
import '../Misc/markbook_math.dart';

class HomePage extends StatefulWidget{
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> with TickerProviderStateMixin, WidgetsBindingObserver{

  final List<Widget> _confettiList = [];
  final List<ConfettiHelper> _confettiHelperList = [];

  late AnimationController _confettiController;
  late Animation<double> _confettiAnimation;

  bool _confettiCanGetFreshAnim = true;
  bool _confettiCanBePlayed = false;
  bool _confettiRefreshRetrigger = true;

  double _fbPosX = 0;
  double _fbPosY = 0;
  bool _fbNeedAnimate = false;

  static HomePageState? _instance;
  HomePageState(){
    _instance = this;
  }

  static BuildContext? getContext() => _instance?.context;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  static void showBlurPopup(bool b){
    _instance?.setBlurComplex(b);
  }

  /// Bottom tabs: 0 Calendar, 1 Markbook, 2 Periods, 3 Mail.
  /// Drawer-only: [viewPayments]=4.
  static void navigateToView(int to) {
    _instance?.switchView(to);
  }

  /// Page indices (bottom 0–3; Payments drawer-only).
  static const int viewMarkbook = 1;
  static const int viewPeriods = 2;
  static const int viewMail = 3;
  static const int viewPayments = 4;

  /// Drawer / banner: open mail with unread filter and clear the new-mail chip.
  static void openWhatsChangedMails() {
    _instance?._openWhatsChangedMails();
  }

  /// Drawer / banner: open markbook and clear the grade-change chip.
  static void openWhatsChangedMarkbook() {
    _instance?._openWhatsChangedMarkbook();
  }

  bool _showBlur = false;
  void setBlur(bool state){
    setState(() {
      _showBlur = state;
    });
  }

  late AnimationController blurController;
  late Animation<double> blurAnimation;

  void setBlurComplex(bool state){
    setState(() {
      if(state) {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
            statusBarIconBrightness: AppColors.isDarktheme() ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: AppColors.getTheme().navbarNavibarColor, // navigation bar color
            statusBarColor: AppColors.getTheme().navbarStatusBarColor, // status bar color
        ));
        blurController.forward();
        _showBlur = true;
        return;
      }
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarIconBrightness: AppColors.isDarktheme() ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: AppColors.getTheme().rootBackground, // navigation bar color
        statusBarColor: AppColors.getTheme().rootBackground, // status bar color
      ));
      blurController.reverse().whenComplete((){
        setState(() {
          _showBlur = false;
        });
      });
    });
  }

  late List<api.CalendarEntry> calendarEntries = <api.CalendarEntry>[].toList();
  late List<api.Subject> markbookEntries = <api.Subject>[].toList();
  late List<api.CashinEntry> paymentsEntries = <api.CashinEntry>[].toList();
  late List<api.CollectiveInvoice> invoiceEntries = <api.CollectiveInvoice>[].toList();
  late List<api.PeriodEntry> periodEntries = <api.PeriodEntry>[].toList();
  late List<api.MailEntry> mailEntries = <api.MailEntry>[].toList();

  late final List<Widget> mondayCalendar = <Widget>[].toList();
  late final List<Widget> tuesdayCalendar = <Widget>[].toList();
  late final List<Widget> wednessdayCalendar = <Widget>[].toList();
  late final List<Widget> thursdayCalendar = <Widget>[].toList();
  late final List<Widget> fridayCalendar = <Widget>[].toList();
  late final List<Widget> saturdayCalendar = <Widget>[].toList();
  late final List<Widget> sundayCalendar = <Widget>[].toList();

  late final List<Widget> markbookList = <Widget>[].toList();

  late final List<Widget> paymentsList = <Widget>[].toList();
  late final List<Widget> periodList = <Widget>[].toList();
  late final List<Widget> mailList = <Widget>[].toList();

  late final LinkedScrollControllerGroup bottomnavScrollCntroller;
  late final ScrollController bottomnavController;

  late final TextEditingController settingsUserWeekOffset;
  late int settingsUserWeekOffsetPrev;
  String prevSettingsUserWeekOffset = '';
  static TextEditingController getUserWeekOffsetTextController(){
    return _instance!.settingsUserWeekOffset;
  }
  static Timer? settingsUserWeekOffsetPeriodicLooper = null;

  bool canDoCalendarPaging = false;
  int weeksSinceStart = 1;
  int currentWeekOffset = 1;
  late TabController calendarTabController;
  int currentView = 0;
  String calendarGreetText = "";

  int totalCredits = 0;
  /// Completed credits across terms (deduped) — app-computed, not official diploma.
  int accumulatedCredits = 0;
  int totalMoney = 0;
  double totalAvg = 0;
  double totalAvg30 = 0;

  /// True when at least one home surface is painting from cache without a fresh network paint.
  bool showingCachedData = false;

  /// Pending What’s Changed counts (mirrored from [storage.DataCache] after refresh).
  int whatsChangedNewMails = 0;
  int whatsChangedGradeChanges = 0;

  int currentSemester = -1;
  int countActivePeriods = 0;
  int countFuturePeriods = 0;
  int countExpiredPeriods = 0;

  int unreadMailCount = 0;
  int totalMailCount = 0;
  int allLoadedMailCount = 0;
  /// Local inbox search (subject / sender / loaded body preview). Never logged.
  String mailSearchQuery = '';
  /// Client-side unread-only chip (`MailEntry.isRead`). API keeps `filterType=0`.
  bool mailUnreadOnly = false;
  late final TextEditingController mailSearchController;
  /// True when the last network mail page returned a full page (20) — used when totalRowCount is unknown.
  bool _lastMailPageWasFull = false;

  double bottomNavSwitchValue = 0.0;
  bool bottomNavCanNavigate = true;
  /// Bottom bar cycles Calendar | Markbook | Periods | Mail (Payments via drawer).
  static const int maxBottomNavWidgets = 4;

  double calendarWeekSwitchValue = 0.0;
  bool calendarWeekCanNavigate = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    FlutterNativeSplash.remove();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarIconBrightness: AppColors.isDarktheme() ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: AppColors.getTheme().rootBackground, // navigation bar color
      statusBarColor: AppColors.getTheme().rootBackground, // status bar color
    ));

    api.Generic.setupDaylightSavingsTime();

    if(storage.DataCache.getHasICSFile() ?? false){
      ICSCalendar.initialize();
    }

    api.SessionGuard.registerNavigator((message) async {
      if (!mounted) return;
      await AppNotifications.cancelScheduledNotifs();
      // Replace-all — never popUntil the only Home route into a blank stack.
      navigateToLoginRoot();
    });
    // Participant session entry: 10-minute wall-clock auto-logout (not JWT-401-only).
    api.SessionGuard.startSessionWallClock();

    Future.microtask(() => api.CalendarRequest.refreshUserProfile());

    whatsChangedNewMails = storage.DataCache.getWhatsChangedNewMails();
    whatsChangedGradeChanges = storage.DataCache.getWhatsChangedGradeChanges();

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final hasConn = results.any((r) => r != ConnectivityResult.none);
      if (hasConn && mounted) {
        // Csendes háttérbeli frissítés kapcsolat visszatérésekor
        Future.microtask(() => onCalendarRefresh(false));
      }
    });

    Future.delayed(const Duration(seconds: 4), () async {
      await LanguageManager.suggestLang(context, null, null);
    });
    Future.delayed(const Duration(seconds: 1), () async {
      await LanguageManager.refreshAllDownloadedLangs();
    });

    if(Platform.isAndroid){
      Future.delayed(Duration.zero, () async {
        try {
          tz.initializeTimeZones();
          final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
          final String timeZone = timeZoneInfo.identifier;
          tz.setLocalLocation(tz.getLocation(timeZone));
        } catch (_) {
          try {
            tz.setLocalLocation(tz.getLocation('Europe/Budapest'));
          } catch (_) {
            tz.setLocalLocation(tz.UTC);
          }
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppUpdater.checkAndInstallUpdate(context);
      });
    }

    if(Platform.isAndroid && storage.DataCache.getIsInstalledFromGPlay() != 0){
      Future.delayed(const Duration(seconds: 4), ()async{
        final cacheTime = await storage.getInt('UpdateCacheTime') ?? -1;
        if(cacheTime <= 0){ // fresh app version
          storage.saveInt('UpdateCacheTime', DateTime.now().millisecondsSinceEpoch);
          return;
        }

        if((DateTime.now().millisecondsSinceEpoch - cacheTime) > const Duration(hours: 24).inMilliseconds || // once a day update check
        await Connectivity().checkConnectivity() == ConnectivityResult.none) // only check for updates, if there is internet
        {return;}

        final appupdateInfo = await InAppUpdate.checkForUpdate();
        storage.saveInt('UpdateCacheTime', DateTime.now().millisecondsSinceEpoch); // save last checked update time
        if(appupdateInfo.updateAvailability == UpdateAvailability.updateAvailable){ // has new version
          AppHaptics.attentionImpact();
          await InAppUpdate.startFlexibleUpdate().then((value) async { // install update
            await InAppUpdate.completeFlexibleUpdate();
          });
        }
      });
    }

    bottomnavScrollCntroller = LinkedScrollControllerGroup();
    bottomnavController = bottomnavScrollCntroller.addAndGet();

    final userWeekOffserValue = storage.DataCache.getUserWeekOffset()!;
    settingsUserWeekOffset = TextEditingController(text: (userWeekOffserValue == 0 ? '' : userWeekOffserValue.toString()));
    prevSettingsUserWeekOffset = settingsUserWeekOffset.text;
    settingsUserWeekOffsetPrev = storage.DataCache.getUserWeekOffset()!;
    settingsUserWeekOffset.addListener(() {
      if(settingsUserWeekOffset.text != prevSettingsUserWeekOffset){
        _instance!.changedSettingsUserWeekOffset = true;
        _instance!.settingsUserWeekOffsetSetup();
      }
    });

    _fbController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fbTween = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fbController, curve: Curves.decelerate),
    );

    blurController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 350),
    );
    blurAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: blurController, curve: Curves.linear),
    );

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    );
    _confettiAnimation = Tween<double>(begin: -0.2, end: 1.0).animate(
      CurvedAnimation(parent: _confettiController, curve: Curves.linear)
    );

    mailSearchController = TextEditingController();
    currentMailPageController = ScrollController();
    currentMailPageController.addListener(() {
      if(currentMailPageController.position.atEdge && currentMailPageController.position.userScrollDirection == ScrollDirection.reverse && canLoadMoreMails){
        if(currentMailLoadingDebounce){
          return;
        }
        currentMailLoadingDebounce = true;
        Future.delayed(Duration.zero, ()async{
          currentMailPage++;
          await fetchMails(force: true);
          rebuildMailList();
        }).whenComplete((){
          currentMailLoadingDebounce = false;
        });
      }
    });

    AppNotifications.initialize();
    Future.delayed(Duration.zero, ()async{
      // Always recompute study-week start when online — stale FirstWeekOfSemesterEpoch
      // (registration/May anchors) produced inflated education weeks (36 → 16).
      if (storage.DataCache.getHasNetwork()) {
        final firstWeekOfSemester = await api.InstitutesRequest.getFirstStudyweek();
        if (firstWeekOfSemester != null) {
          await storage.DataCache.setFirstWeekEpoch(firstWeekOfSemester);
          storage.DataCache.setHasCachedFirstWeekEpoch(1);
        }
        storage.saveInt('NextFirstWeekCacheTime', DateTime.now().add(Duration(days: 1)).millisecondsSinceEpoch);
      } else if(((await storage.getInt('NextFirstWeekCacheTime')) ?? 0) < DateTime.now().millisecondsSinceEpoch){
        storage.DataCache.setHasCachedFirstWeekEpoch(0);
        storage.saveInt('NextFirstWeekCacheTime', DateTime.now().add(Duration(days: 1)).millisecondsSinceEpoch);
      }
      if (mounted) {
        setState(() {weeksSinceStart = calcPassedWeeks();});
      }
    }).whenComplete((){
      Future.delayed(const Duration(seconds: 1), (){
        if (mounted) {
          setState(() {weeksSinceStart = calcPassedWeeks();});
        }
      });
    });

    Future.delayed(Duration.zero,() async{
      await AppNotifications.cancelScheduledNotifs();
    }).whenComplete((){
      Future.microtask(() async {
        await fetchCalendar();
        if(storage.DataCache.getNeedExamNotifications() ?? false){
          if(storage.DataCache.getHasNetwork()){
            await _skimForExams();
          }
        }
        setupCalendar(true);
      });

      Future.microtask(() async {
        await fetchMarkbook();
        setupMarkbook();
        await _refreshAccumulatedCredits();
      });

      Future.microtask(() async {
        await fetchPayments();
        setupPayments();
      });

      Future.microtask(() async {
        await fetchPeriods();
        setupPeriods();
      });

      Future.microtask(() async {
        await fetchMails();
        setupMails();
      });
    });

    setupCalendarGreetText();
    setupCalendarController(true, true);

    Future.delayed(const Duration(seconds: 1), (){
      final size = MediaQuery.of(context).size;

      setState(() {
        _fbPosX = size.width - 90;
        _fbPosY = size.height - 140;
      });
    });
    AppColors.clearThemeChangeCallbacks();
    AppColors.subThemeChangeCallback((){
      if(!mounted){
        return;
      }
      setState(() {

      });
      Future.delayed(Duration.zero, (){
        onCalendarRefresh(false);
        onMarkbookRefresh();
        onPaymentsRefresh();
        onPeriodsRefresh();
        onMailRefresh();
      });
    });
  }

  void userUnavailableAccountLogout(){
    Future.delayed(Duration.zero, ()async{
      await api.SessionGuard.userInitiatedLogout();
      await AppNotifications.cancelScheduledNotifs();
    }).whenComplete((){
      Navigator.popUntil(context, (route) => route.willHandlePopInternally);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const root_page.Splitter()),
      );
    });
  }

  bool changedSettingsUserWeekOffset = false;

  void settingsUserWeekOffsetSetup(){
    if(settingsUserWeekOffset.text == '-'){
      return;
    }
    var newVal = int.tryParse(settingsUserWeekOffset.text);
    var correctedVal = 0;
    if(newVal == null || newVal == 0){
      settingsUserWeekOffset.text = '';
      prevSettingsUserWeekOffset = settingsUserWeekOffset.text;
      Future.delayed(Duration.zero, ()async{
        await storage.DataCache.setUserWeekOffset(correctedVal);
      });
      return;
    }
    correctedVal = clampDouble(newVal.toDouble(), -calcPassedWeekOffsetless().toDouble(), 51 - calcPassedWeekOffsetless().toDouble()).toInt();
    settingsUserWeekOffset.text = correctedVal.toString();
    settingsUserWeekOffset.text = correctedVal.toString();
    prevSettingsUserWeekOffset = settingsUserWeekOffset.text;
    Future.delayed(Duration.zero, ()async{
      await storage.DataCache.setUserWeekOffset(correctedVal);
    });
  }

  static void settingsUserWeekOffsetAdd(int val){
    _instance!.changedSettingsUserWeekOffset = true;
    final oldVal = storage.DataCache.getUserWeekOffset()!;
    var correctedVal = oldVal + val;
    correctedVal = clampDouble(correctedVal.toDouble(), -_instance!.calcPassedWeekOffsetless().toDouble(), 51 - _instance!.calcPassedWeekOffsetless().toDouble()).toInt();
    _instance!.settingsUserWeekOffset.text = correctedVal.toString();
    _instance!.prevSettingsUserWeekOffset = _instance!.settingsUserWeekOffset.text;
    Future.delayed(Duration.zero, ()async{
      await storage.DataCache.setUserWeekOffset(correctedVal);
    });
  }

  static void settingsUserWeekOffsetChangeDetect(){
    _instance?._settingsUserWeekOffsetChangeDetect();
  }

  static void onSemesterChanged(){
    _instance?._onSemesterChanged();
  }

  void _onSemesterChanged(){
    Future.delayed(Duration.zero, () async {
      await storage.DataCache.setHasCachedMarkbook(0);
      await storage.DataCache.setHasCachedPeriods(0);
      await storage.DataCache.setHasCachedCalendar(0);
      await storage.DataCache.setHasCachedFirstWeekEpoch(0);

      final firstWeekOfSemester = await api.InstitutesRequest.getFirstStudyweek();
      if (firstWeekOfSemester != null) {
        await storage.DataCache.setFirstWeekEpoch(firstWeekOfSemester);
        storage.DataCache.setHasCachedFirstWeekEpoch(1);
      }

      if (mounted) {
        setState(() {
          weeksSinceStart = calcPassedWeeks();
        });
      }

      await Future.wait([
        onMarkbookRefresh(),
        onPeriodsRefresh(),
        onCalendarRefresh(false),
      ]);
    });
  }

  void _settingsUserWeekOffsetChangeDetect(){
    final currentOffset = storage.DataCache.getUserWeekOffset()!;
    if(settingsUserWeekOffsetPrev != currentOffset){
      settingsUserWeekOffsetPrev = currentOffset;
      Future.delayed(Duration.zero,() async{
        await storage.DataCache.setHasCachedCalendar(0);
        await AppNotifications.cancelScheduledNotifs();
      }).whenComplete(()async{
        await onCalendarRefresh(false);
      });
    }
  }

  void setupCalendarGreetText(){
    final currentTimeHour = DateTime.now().hour;
    if(currentTimeHour > 1 && currentTimeHour <= 6){
      setState(() {
        calendarGreetText = AppStrings.getLanguagePack().topheader_calendar_greetMessage_1to6;
      });
    }
    else if(currentTimeHour > 6 && currentTimeHour <= 9){
      setState(() {
        calendarGreetText = AppStrings.getLanguagePack().topheader_calendar_greetMessage_6to9;
      });
    }
    else if(currentTimeHour > 9 && currentTimeHour <= 13){
      setState(() {
        calendarGreetText = AppStrings.getLanguagePack().topheader_calendar_greetMessage_9to13;
      });
    }
    else if(currentTimeHour > 13 && currentTimeHour <= 17){
      setState(() {
        calendarGreetText = AppStrings.getLanguagePack().topheader_calendar_greetMessage_13to17;
      });
    }
    else if(currentTimeHour > 17 && currentTimeHour <= 21){
      setState(() {
        calendarGreetText = AppStrings.getLanguagePack().topheader_calendar_greetMessage_17to21;
      });
    }
    else if(currentTimeHour > 21 || currentTimeHour <= 1){
      setState(() {
        calendarGreetText = AppStrings.getLanguagePack().topheader_calendar_greetMessage_21to1;
      });
    }
  }

  void clearCalendar(){
    setState(() {
      weeksSinceStart = calcPassedWeeks();
      calendarEntries.clear();
      mondayCalendar.clear();
      tuesdayCalendar.clear();
      wednessdayCalendar.clear();
      thursdayCalendar.clear();
      fridayCalendar.clear();
      saturdayCalendar.clear();
      sundayCalendar.clear();
    });
  }

  void clearMarkbook(){
    setState(() {
      markbookEntries.clear();
      markbookList.clear();
    });
  }

  void clearPayments(){
    setState(() {
      paymentsEntries.clear();
      invoiceEntries.clear();
      paymentsList.clear();
    });
  }
  void clearPeriods(){
    setState(() {
      periodEntries.clear();
      periodList.clear();
      currentSemester = -1;
      countActivePeriods = 0;
      countExpiredPeriods = 0;
      countFuturePeriods = 0;
    });
  }

  void clearMails(){
    setState(() {
      mailEntries.clear();
      mailList.clear();
      currentMailPage = 1;
      currentMailLoadingDebounce = false;
      unreadMailCount = 0;
      totalMailCount = 0;
      allLoadedMailCount = 0;
      _lastMailPageWasFull = false;
    });
  }

  bool get canLoadMoreMails {
    if (api.SessionGuard.isAuthBlocked || !storage.DataCache.getHasNetwork()) {
      return false;
    }
    if (totalMailCount > 0) {
      return mailEntries.length < totalMailCount;
    }
    return _lastMailPageWasFull;
  }

  List<api.MailEntry> filteredMailEntries() {
    Iterable<api.MailEntry> list = mailEntries;
    if (mailUnreadOnly) {
      list = list.where((m) => !m.isRead);
    }
    final q = mailSearchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((m) {
        return m.subject.toLowerCase().contains(q) ||
            m.senderName.toLowerCase().contains(q) ||
            m.detail.toLowerCase().contains(q);
      });
    }
    return list.toList();
  }

  void setMailSearchQuery(String value) {
    mailSearchQuery = value;
    rebuildMailList();
  }

  void setMailUnreadOnly(bool value) {
    mailUnreadOnly = value;
    rebuildMailList();
  }

  void rebuildMailList() {
    setState(() {
      mailList.clear();
      allLoadedMailCount = mailEntries.length;
      _setupMails();
    });
  }

  void setupCalendar(bool thisweekCalendar){
    setState(() {
      _setupCalendar(thisweekCalendar);
      canDoCalendarPaging = true;
      setupCalendarController(false, false);
    });
  }
  void setupMarkbook(){
    setState(() {
      _setupMarkbook();
    });
  }

  void setupPayments(){
    setState(() {
      _setupPayments();
    });
  }

  void setupPeriods(){
    setState(() {
      _setupPeriods();
    });
  }

  void setupMails({bool clear = false}){
    setState(() {
      mailList.clear();
      allLoadedMailCount = mailEntries.length;
      _setupMails();
    });
  }

  static void setupExamNotifications(){
    Future.delayed(Duration.zero, ()async{
      await _instance!._setupExamNotifications(_instance!._examNotificationList);
    });
  }

  static void cancelExamNotifications(){
    Future.delayed(Duration.zero, ()async{
      await _instance!._cancelExamNotifications();
    });
  }

  final _examNotificationList = <api.CalendarEntry>[];
  
  Future<void> _skimForExams()async{
    _examNotificationList.clear();
    for(int i = 0; i < 3; i++){
      final result = await fetchCalendarToList(i);
      _examNotificationList.addAll(result);
    }

    _setupExamNotifications(_examNotificationList);
  }
  
  Future<void> _setupExamNotifications(List<api.CalendarEntry> items)async{
    await _cancelExamNotifications();
    if(_examNotificationList.isEmpty){
      return;
    }
    final now = DateTime.now();
    for(var item in items){ // add notifiers for exams
      if(!item.isExam || now.millisecondsSinceEpoch > item.startEpoch){
        continue;
      }
      await _setupNotificationsForSkimmedExams(item, now);
    }
  }

  Future<void> _setupNotificationsForSkimmedExams(api.CalendarEntry item, DateTime now)async{
    final daysTillExam = (Duration(milliseconds: item.startEpoch) - Duration(milliseconds: now.millisecondsSinceEpoch)).inDays;
    final lang = AppStrings.getLanguagePack();
    final examTitle = lang.notif_title_Exam;
    for(int i = 1; i <= daysTillExam + 1; i++){
      if(i == 1){
        await AppNotifications.scheduleNotification(examTitle, AppStrings.getStringWithParams(lang.notif_exam_BodyToday, [item.title]), DateTime(now.year, now.month, now.day + daysTillExam - i + 2, 06, 00), 0);
        continue;
      }
      else if(i == 2){
        await AppNotifications.scheduleNotification(examTitle, AppStrings.getStringWithParams(lang.notif_exam_BodyTomorrow, [item.title]), DateTime(now.year, now.month, now.day + daysTillExam - i + 2, 09, 00), 0);
        continue;
      }
      await AppNotifications.scheduleNotification(examTitle, AppStrings.getStringWithParams(lang.notif_exam_BodyInDays, [item.title, i]), DateTime(now.year, now.month, now.day + daysTillExam - i + 2, 09, 00), 0);
    }
  }

  Future<void> _cancelExamNotifications()async{
    await AppNotifications.cancelScheduledNotifsId(0);
  }

  static void setupClassesNotifications(){
    Future.delayed(Duration.zero, ()async{
      await _instance!._setupClassesNotifications(_instance!._classesNotificationList);
    });
  }

  static void cancelClassesNotifications(){
    Future.delayed(Duration.zero, ()async{
      await _instance!._cancelClassesNotifications();
    });
  }

  final List<api.CalendarEntry> _classesNotificationList = <api.CalendarEntry>[].toList();

  Future<void> _setupClassesNotifications(List<api.CalendarEntry> items)async{
    await _cancelClassesNotifications();
    if(!storage.DataCache.getNeedClassNotifications()!){
      return;
    }
    for(var item in items){
      // set up notifications for today
      final now = DateTime.now();
      if(now.millisecondsSinceEpoch < item.startEpoch && !item.isExam){ // did not pass them in time

        String finalRoom = item.location;
        if (item.classInstanceId != null && item.classInstanceId!.isNotEmpty) {
          String? cachedRoom = await storage.getString('room_${item.classInstanceId}');
          if (cachedRoom != null && cachedRoom.isNotEmpty && !AppStrings.isMissingRoomValue(cachedRoom)) {
            finalRoom = cachedRoom;
          }
        }
        // -------------------------------------------------------------------------------

        final lang = AppStrings.getLanguagePack();
        final classTitle = lang.notif_title_Class;
        await AppNotifications.scheduleNotification(classTitle, AppStrings.getStringWithParams(lang.notif_class_BodyIn10Min, [item.title, finalRoom]), DateTime.fromMillisecondsSinceEpoch((Duration(milliseconds: item.startEpoch) - const Duration(minutes: 10)).inMilliseconds), 1);
        await AppNotifications.scheduleNotification(classTitle, AppStrings.getStringWithParams(lang.notif_class_BodyIn5Min, [item.title, finalRoom]), DateTime.fromMillisecondsSinceEpoch((Duration(milliseconds: item.startEpoch) - const Duration(minutes: 5)).inMilliseconds), 1);
        await AppNotifications.scheduleNotification(classTitle, AppStrings.getStringWithParams(lang.notif_class_BodyNow, [item.title, finalRoom]), DateTime.fromMillisecondsSinceEpoch(item.startEpoch), 1);
      }
    }
  }
  
  Future<void> _cancelClassesNotifications()async{
    await AppNotifications.cancelScheduledNotifsId(1);
  }

  static void setupPaymentsNotifications(){
    Future.delayed(Duration.zero, ()async{
      await _instance!._setupPaymentsNotification(_instance!._paymentsNotificationList);
    });
  }

  static void cancelPaymentsNotifications(){
    Future.delayed(Duration.zero, ()async{
      await _instance!._cancelPaymentsNotifications();
    });
  }

  final List<api.CashinEntry> _paymentsNotificationList = <api.CashinEntry>[].toList();

  Future<void> _setupPaymentsNotification(List<api.CashinEntry> items)async{
    await _cancelPaymentsNotifications();
    if(!storage.DataCache.getNeedPaymentsNotifications()! || _paymentsNotificationList.isEmpty){
      return;
    }
    final now = DateTime.now();
    final lang = AppStrings.getLanguagePack();
    final paymentTitle = lang.notif_title_Payment;
    final huf = lang.payment_currencyHuf;
    for(var item in items){
      final amountLabel = '${item.ammount} $huf';
      if(item.dueDateMs == 0){
        final body = AppStrings.getStringWithParams(lang.notif_payment_BodyNoDeadline, [amountLabel]);
        for(int i = 0; i <= 31; i++){
          await AppNotifications.scheduleNotification(paymentTitle, body, DateTime(now.year, now.month, now.day + i, 11, 00),2 );
        }
        continue;
      }
      final daysRemaining = (Duration(milliseconds: item.dueDateMs) - Duration(milliseconds: now.millisecondsSinceEpoch)).inDays;
      final time = DateTime.fromMillisecondsSinceEpoch(item.dueDateMs);
      final datePart = '${daysRemaining > 61 ? "(${time.year}) " : ""}${api.Generic.monthToText(time.month)} ${time.day}';
      final body = AppStrings.getStringWithParams(lang.notif_payment_BodyWithDeadline, [amountLabel, datePart]);
      for(int i = 0; i <= daysRemaining; i++){
        await AppNotifications.scheduleNotification(paymentTitle, body, DateTime(now.year, now.month, now.day + i, 11, 00), 2);
      }
    }
  }

  Future<void> _cancelPaymentsNotifications()async{
    await AppNotifications.cancelScheduledNotifsId(2);
  }
  
  static void setupPeriodsNotifications(){
    Future.delayed(Duration.zero, ()async{
      await _instance!._setupPeriodsNotification(_instance!._periodsNotificationList);
    });
  }

  static void cancelPeriodsNotifications(){
    Future.delayed(Duration.zero, ()async{
      await _instance!._cancelPeriodsNotifications();
    });
  }

  final List<api.PeriodEntry> _periodsNotificationList = <api.PeriodEntry>[].toList();
  
  Future<void> _setupPeriodsNotification(List<api.PeriodEntry> items)async{
    await _cancelPeriodsNotifications();
    if(!storage.DataCache.getNeedPeriodsNotifications()! || _periodsNotificationList.isEmpty){
      return;
    }

    for(var item in items){
      final time = DateTime.fromMillisecondsSinceEpoch(item.startEpoch);
      final periodName = api.Generic.capitalizePeriodText(item.name);
      final lang = AppStrings.getLanguagePack();
      await AppNotifications.scheduleNotification(
        lang.notif_title_Period,
        AppStrings.getStringWithParams(lang.notif_period_Tomorrow, [periodName]),
        DateTime(time.year, time.month, time.day - 1, 11, 00),
        3,
      );
      await AppNotifications.scheduleNotification(
        lang.notif_title_Period,
        AppStrings.getStringWithParams(lang.notif_period_Today, [periodName]),
        DateTime(time.year, time.month, time.day, 06, 00),
        3,
      );
    }
  }

  Future<void> _cancelPeriodsNotifications()async{
    await AppNotifications.cancelScheduledNotifsId(3);
  }

  void _setupCalendar(bool thisweekCalendar){
    mondayCalendar.clear();
    tuesdayCalendar.clear();
    wednessdayCalendar.clear();
    thursdayCalendar.clear();
    fridayCalendar.clear();
    saturdayCalendar.clear();
    sundayCalendar.clear();

    if (thisweekCalendar) {
      _classesNotificationList.clear();
    }

    // Sort entries chronologically
    calendarEntries.sort((a, b) => a.startEpoch.compareTo(b.startEpoch));

    int idx = 1;
    int prev = 0;
    api.CalendarEntry? prevEntry;
    final currWeekday = DateTime.now().weekday;
    final now = DateTime.now();
    final Map<int, api.CalendarEntry> prevClassPerWkday = {};

    for(var item in calendarEntries){
      if (item.isPeriodBanner) {
        continue; // period banners shown in dedicated strip, not day lists
      }
      final wkday = DateTime.fromMillisecondsSinceEpoch(item.startEpoch).weekday;
      if(prev != wkday){
        idx = 1;
        prev = wkday;
        prevEntry = item;
      } else if (prevEntry != null && item.startEpoch == prevEntry.startEpoch) {
        // Same timeslot
      } else {
        idx++;
      }
      prevEntry = item;

      if(thisweekCalendar && currWeekday == wkday && !item.isExam){
        _classesNotificationList.add(item);
      }

      // Gap between consecutive classes on the *same calendar day* only
      // (weekday-only keys wrongly linked last Monday → next Monday).
      final prevClass = prevClassPerWkday[wkday];
      if (prevClass != null && !prevClass.isExam && !item.isExam) {
        final prevDay = DateTime.fromMillisecondsSinceEpoch(prevClass.startEpoch);
        final itemDay = DateTime.fromMillisecondsSinceEpoch(item.startEpoch);
        final sameDay = prevDay.year == itemDay.year &&
            prevDay.month == itemDay.month &&
            prevDay.day == itemDay.day;
        final breakStart = prevClass.endEpoch;
        final breakEnd = item.startEpoch;
        final breakMs = breakEnd - breakStart;
        // 5 min … 12 h — skip overnight / cross-week artefacts
        if (sameDay &&
            breakMs >= 5 * 60 * 1000 &&
            breakMs <= 12 * 60 * 60 * 1000) {
          final isCurrentBreak = now.millisecondsSinceEpoch >= breakStart &&
              now.millisecondsSinceEpoch < breakEnd &&
              wkday == currWeekday &&
              currentWeekOffset == 1;

          final breakWidget = t_table.BreakElementWidget(
            startEpoch: breakStart,
            endEpoch: breakEnd,
            isCurrent: isCurrentBreak,
            nextClassTitle: item.title,
          );

          switch(wkday){
            case 1: mondayCalendar.add(breakWidget); break;
            case 2: tuesdayCalendar.add(breakWidget); break;
            case 3: wednessdayCalendar.add(breakWidget); break;
            case 4: thursdayCalendar.add(breakWidget); break;
            case 5: fridayCalendar.add(breakWidget); break;
            case 6: saturdayCalendar.add(breakWidget); break;
            case 7: sundayCalendar.add(breakWidget); break;
          }
        }
      }

      prevClassPerWkday[wkday] = item;

      final isCurrent = !item.isExam && now.millisecondsSinceEpoch >= item.startEpoch && now.millisecondsSinceEpoch <= item.endEpoch && wkday == currWeekday && currentWeekOffset == 1;

      final widget = t_table.TimetableElementWidget(
        entry: item,
        position: idx,
        isCurrent: isCurrent,
      );

      switch(wkday){
        case 1:
          mondayCalendar.add(widget);
          break;
        case 2:
          tuesdayCalendar.add(widget);
          break;
        case 3:
          wednessdayCalendar.add(widget);
          break;
        case 4:
          thursdayCalendar.add(widget);
          break;
        case 5:
          fridayCalendar.add(widget);
          break;
        case 6:
          saturdayCalendar.add(widget);
          break;
        case 7:
          sundayCalendar.add(widget);
          break;
      }
    }
    calendarTabController.index = currentWeekOffset == 1 ? (currWeekday - 1 > 6 ? 0 : currWeekday - 1) : calendarTabController.index;
  }

  List<Widget> calendarTabs = <Widget>[].toList();
  List<Widget> calendarTabViews = <Widget>[].toList();

  void setupCalendarController(bool replaceController, bool isLoading){
    calendarTabs = <Widget>[].toList();
    calendarTabViews = <Widget>[].toList();
    getCalendarTabViews(context, isLoading);
    if(replaceController) {
      calendarTabController = TabController(length: calendarTabs.length, vsync: this);
    }
    setState(() {
      isLoadingCalendar = isLoading;
    });
  }

  void _fillOneCalendarElement(BuildContext context, List<Widget> w, String name, bool isLoading){
    calendarTabs.add(Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Tab(
        child: Text(
          name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12
          ),
        ),
      ),
    ));
    calendarTabViews.add(RefreshIndicator(
      onRefresh: ()async{AppHaptics.lightImpact(); onCalendarRefresh(false);},
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        scrollDirection: Axis.vertical,
        child: Container(
          margin: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: w.isNotEmpty ? AppColors.getTheme().textColor.withValues(alpha: 0.03) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: KeyedSubtree(
              key: ValueKey<String>('day_${name}_${weeksSinceStart}_${w.length}_$isLoading'),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.max,
                children: w.isNotEmpty ? w : isLoading ? <Widget>[
                  Center(
                    child: CircularProgressIndicator(
                      color: AppColors.getTheme().textColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    api.Generic.randomLoadingComment(storage.DataCache.getNeedFamilyFriendlyComments()!),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.getTheme().textColor.withValues(alpha: .2),
                      fontWeight: FontWeight.w300,
                      fontSize: 10
                    ),
                  )
                ] : <Widget>[const t_table.FreedayElementWidget()],
              ),
            ),
          ),
        ),
      ),
    ));
  }

  void getCalendarTabViews(BuildContext context, bool isLoading){
    _fillOneCalendarElement(context, mondayCalendar, AppStrings.getLanguagePack().api_dayMon_Universal, isLoading);
    _fillOneCalendarElement(context, tuesdayCalendar, AppStrings.getLanguagePack().api_dayTue_Universal, isLoading);
    _fillOneCalendarElement(context, wednessdayCalendar, AppStrings.getLanguagePack().api_dayWed_Universal, isLoading);
    _fillOneCalendarElement(context, thursdayCalendar, AppStrings.getLanguagePack().api_dayThu_Universal, isLoading);
    _fillOneCalendarElement(context, fridayCalendar, AppStrings.getLanguagePack().api_dayFri_Universal, isLoading);
    _fillOneCalendarElement(context, saturdayCalendar, AppStrings.getLanguagePack().api_daySat_Universal, isLoading);
    _fillOneCalendarElement(context, sundayCalendar, AppStrings.getLanguagePack().api_daySun_Universal, isLoading);
  }

  void _mbookPopupResult(int result, int idx){
    if(result == -1){
      setState(() {
        final e = markbookList[idx] as mbook.MarkbookElementWidget;
        setState(() {
          markbookList[idx] = mbook.MarkbookElementWidget(
            name: e.name,
            credit: e.credit,
            completed: e.completed,
            grade: e.grade,
            isFailed: e.isFailed,
            onPopupResult: e.onPopupResult,
            listIndex: e.listIndex,
            ghostGrade: -1,
            subjectCode: e.subjectCode,
          );
          _markbookCalcGhostAvg();
        });
      });
      return;
    }

    final grade = result + 1;
    final e = markbookList[idx] as mbook.MarkbookElementWidget;
    setState(() {
      markbookList[idx] = mbook.MarkbookElementWidget(
        name: e.name,
        credit: e.credit,
        completed: e.completed,
        grade: e.grade,
        isFailed: e.isFailed,
        onPopupResult: e.onPopupResult,
        listIndex: e.listIndex,
        ghostGrade: grade,
        subjectCode: e.subjectCode,
      );
      _markbookCalcGhostAvg();
    });
  }
  
  void _setupMarkbook(){
    markbookList.clear();
    totalCredits = 0;
    totalAvg = 5;
    totalAvg30 = 5;
    if(markbookEntries.isEmpty){
      markbookList.add(Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Center(
          child: EmojiRichText(
            text: AppStrings.getLanguagePack().markbookPage_Empty,
            defaultStyle: TextStyle(
              color: AppColors.getTheme().onPrimaryContainer,
              fontWeight: FontWeight.w900,
              fontSize: 26.0,
            ),
            emojiStyle: TextStyle(
                color: AppColors.getTheme().onPrimaryContainer,
                fontSize: 26.0,
                fontFamily: "Noto Color Emoji"
            ),
          ),
        ),
      ));
    }

    //order them
    for (int i = 0; i < markbookEntries.length; i++){
      for (int j = i; j < markbookEntries.length; j++){
        if(markbookEntries[j].credit > markbookEntries[i].credit){
          final tmp = markbookEntries[i];
          markbookEntries[i] = markbookEntries[j];
          markbookEntries[j] = tmp;
        }
      }
    }

    // set them up
    totalCredits = 0;
    totalAvg = 0;
    totalAvg30 = 0;
    var hasCompleted = false;
    var hasIncomplete = false;
    int idx = 0;
    for (var item in markbookEntries){
      totalCredits += item.credit;
      if(item.completed){
        hasCompleted = true;
        continue;
      }
      hasIncomplete = true;
      markbookList.add(mbook.MarkbookElementWidget(
        name: item.name,
        credit: item.credit,
        completed: item.completed,
        grade: item.grade,
        isFailed: item.failState == 1,
        onPopupResult: _mbookPopupResult,
        listIndex: idx,
        ghostGrade: -1,
        subjectCode: item.subjectCode,
      ));
      idx++;
    }
    if(hasCompleted) {
      if(hasIncomplete){
        markbookList.add(
            _getSeparatorLine(AppStrings.getLanguagePack().markbookPage_CompletedLine)
        );
        idx++;
      }

      for (var item in markbookEntries) {
        if (!item.completed) {
          continue;
        }
        markbookList.add(mbook.MarkbookElementWidget(
          name: item.name,
          credit: item.credit,
          completed: item.completed,
          grade: item.grade,
          isFailed: item.failState == 1,
          onPopupResult: _mbookPopupResult,
          listIndex: idx,
          ghostGrade: -1,
          subjectCode: item.subjectCode,
        ));
        idx++;
      }
    }
    _confettiCanBePlayed = !hasIncomplete && hasCompleted; // all finished
    _markbookCalcAvg();
  }

  void _markbookCalcAvg(){
    if(markbookEntries.isEmpty){
      return;
    }
    final grades = <int>[];
    final credits = <int>[];
    for (final item in markbookEntries) {
      if (!item.completed) continue;
      grades.add(item.grade);
      credits.add(item.credit);
    }
    final r = MarkbookMath.fromCompleted(grades: grades, credits: credits);
    totalAvg = r.average;
    totalAvg30 = r.per30;
  }

  void _markbookCalcGhostAvg(){
    if(markbookEntries.isEmpty){
      return;
    }
    final grades = <int>[];
    final credits = <int>[];
    for (final item in markbookList) {
      try {
        final itm = item as mbook.MarkbookElementWidget;
        if (!itm.completed && itm.ghostGrade == -1) {
          continue;
        }
        if (itm.completed && itm.grade >= 2) {
          grades.add(itm.grade);
          credits.add(itm.credit);
        } else if (itm.ghostGrade != -1) {
          grades.add(itm.ghostGrade);
          credits.add(itm.credit);
        }
      } catch (_) {}
    }
    final r = MarkbookMath.fromEffectiveGrades(effectiveGrades: grades, credits: credits);
    totalAvg = r.average;
    totalAvg30 = r.per30;
  }

  Future<void> _refreshAccumulatedCredits() async {
    final cached = await storage.getInt('CachedAccumulatedCredits');
    if (cached != null && cached > 0 && accumulatedCredits == 0) {
      if (mounted) setState(() => accumulatedCredits = cached);
    }
    if (api.SessionGuard.isAuthBlocked || !storage.DataCache.getHasNetwork()) {
      return;
    }
    try {
      final hist = await api.MarkbookRequest.getGradeHistoryAcrossTerms(maxTerms: 8);
      final rows = hist.map((h) => (
            subjectCode: h.subject.subjectCode,
            name: h.subject.name,
            credit: h.subject.credit,
            completed: h.subject.completed || h.subject.grade >= 2,
            grade: h.subject.grade,
          ));
      final sum = MarkbookMath.accumulatedCompletedCredits(rows);
      await storage.saveInt('CachedAccumulatedCredits', sum);
      if (mounted) setState(() => accumulatedCredits = sum);
    } catch (e) {
      debugPrint('accumulated credits: $e');
    }
  }

  /// Thin honesty banner when UI is serving cached academic data.
  Widget buildCacheHonestyBanner() {
    if (!showingCachedData) return const SizedBox.shrink();
    final lang = AppStrings.getLanguagePack();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.getTheme().textColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        lang.cache_showingFromCache,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.getTheme().onPrimaryContainer.withValues(alpha: 0.75),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Calendar strip / shared: “N new messages” / “N grade changes” after a refresh diff.
  Widget buildWhatsChangedBanner() {
    if (whatsChangedNewMails <= 0 && whatsChangedGradeChanges <= 0) {
      return const SizedBox.shrink();
    }
    final lang = AppStrings.getLanguagePack();
    final theme = AppColors.getTheme();
    final chips = <Widget>[];
    if (whatsChangedNewMails > 0) {
      chips.add(
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ActionChip(
            avatar: Icon(Icons.mark_email_unread_rounded, size: 16, color: theme.primary),
            label: Text(
              AppStrings.getStringWithParams(
                lang.whatsChanged_NewMessages,
                [whatsChangedNewMails],
              ),
              style: TextStyle(color: theme.primary, fontSize: 12, fontWeight: FontWeight.w700),
            ),
            backgroundColor: theme.primary.withValues(alpha: 0.1),
            side: BorderSide(color: theme.primary.withValues(alpha: 0.25)),
            onPressed: () {
              AppHaptics.lightImpact();
              _openWhatsChangedMails();
            },
          ),
        ),
      );
    }
    if (whatsChangedGradeChanges > 0) {
      chips.add(
        ActionChip(
          avatar: Icon(Icons.grade_rounded, size: 16, color: theme.secondary),
          label: Text(
            AppStrings.getStringWithParams(
              lang.whatsChanged_GradeChanges,
              [whatsChangedGradeChanges],
            ),
            style: TextStyle(color: theme.secondary, fontSize: 12, fontWeight: FontWeight.w700),
          ),
          backgroundColor: theme.secondary.withValues(alpha: 0.1),
          side: BorderSide(color: theme.secondary.withValues(alpha: 0.25)),
          onPressed: () {
            AppHaptics.lightImpact();
            _openWhatsChangedMarkbook();
          },
        ),
      );
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: chips),
      ),
    );
  }

  void _syncWhatsChangedFromCache() {
    final mails = storage.DataCache.getWhatsChangedNewMails();
    final grades = storage.DataCache.getWhatsChangedGradeChanges();
    if (mails == whatsChangedNewMails && grades == whatsChangedGradeChanges) return;
    if (mounted) {
      setState(() {
        whatsChangedNewMails = mails;
        whatsChangedGradeChanges = grades;
      });
    } else {
      whatsChangedNewMails = mails;
      whatsChangedGradeChanges = grades;
    }
  }

  Future<void> _openWhatsChangedMails() async {
    await storage.DataCache.clearWhatsChangedNewMails();
    _syncWhatsChangedFromCache();
    setMailUnreadOnly(true);
    switchView(viewMail);
  }

  Future<void> _openWhatsChangedMarkbook() async {
    await storage.DataCache.clearWhatsChangedGradeChanges();
    _syncWhatsChangedFromCache();
    switchView(viewMarkbook);
  }

  Future<void> _recordMailWhatsChanged() async {
    await storage.DataCache.diffAndSaveMailSnapshot(mailEntries.map((e) => e.ID));
    _syncWhatsChangedFromCache();
  }

  Future<void> _recordMarkbookWhatsChanged() async {
    final termId = storage.DataCache.getSelectedTermId() ?? '';
    final keys = markbookEntries.map(
      (s) => storage.DataCache.gradeSnapshotKey(
        subjectCode: s.subjectCode.isNotEmpty ? s.subjectCode : s.name,
        grade: s.grade,
        termId: termId,
      ),
    );
    await storage.DataCache.diffAndSaveGradeSnapshot(keys);
    _syncWhatsChangedFromCache();
  }

  void _setShowingCached(bool value) {
    if (showingCachedData == value) return;
    if (mounted) {
      setState(() => showingCachedData = value);
    } else {
      showingCachedData = value;
    }
  }

  void _setupPayments(){
    _paymentsNotificationList.clear();
    paymentsList.clear();
    totalMoney = 0;

    // Sort descending by date (newest first)
    paymentsEntries.sort((a, b) => b.dueDateMs.compareTo(a.dueDateMs));

    if (invoiceEntries.isNotEmpty) {
      paymentsList.add(Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: Text(
          AppStrings.getLanguagePack().payment_invoices_Header,
          style: TextStyle(color: AppColors.getTheme().secondary, fontWeight: FontWeight.w800, fontSize: 12),
        ),
      ));
      for (final inv in invoiceEntries) {
        final curr = (inv.currency.toUpperCase() == 'HUF' || inv.currency.toUpperCase() == 'FT')
            ? AppStrings.getLanguagePack().payment_currencyHuf
            : inv.currency;
        paymentsList.add(ListTile(
          dense: true,
          title: Text(inv.name, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w700, fontSize: 14)),
          trailing: Text(
            '${inv.balance.round()} $curr',
            style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ));
      }
      paymentsList.add(const SizedBox(height: 6));
    }

    for(var item in paymentsEntries){
      if(item.completed){
        totalMoney += item.ammount.abs();
      }
      if(!item.completed && (item.dueDateMs > DateTime.now().millisecondsSinceEpoch || item.dueDateMs == 0)){
        _paymentsNotificationList.add(item);
      }
      paymentsList.add(PaymentElementWidget(
        ammount: item.ammount,
        dueDateMs: item.dueDateMs,
        ID: item.ID,
        name: item.comment,
        completed: item.completed,
        direction: item.direction,
        note: item.note,
        currency: item.currency,
      ));
    }

    if(_paymentsNotificationList.isNotEmpty){
      Future.delayed(Duration.zero,()async{
        await _setupPaymentsNotification(_paymentsNotificationList);
      });
    }

    if(paymentsEntries.isEmpty && invoiceEntries.isEmpty){
      paymentsList.add(Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Center(
          child: EmojiRichText(
            text: AppStrings.getLanguagePack().paymentPage_Empty,
            defaultStyle: TextStyle(
              color: AppColors.getTheme().onPrimaryContainer,
              fontWeight: FontWeight.w900,
              fontSize: 26.0,
            ),
            emojiStyle: TextStyle(
                color: AppColors.getTheme().onPrimaryContainer,
                fontSize: 26.0,
                fontFamily: "Noto Color Emoji"
            ),
          ),
        ),
      ));
    }
  }

  Widget _getSeparatorLine(String text, {bool expired = false}){
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 30),
            color: expired ? AppColors.getTheme().errorRed.withValues(alpha: .3) : AppColors.getTheme().textColor.withValues(alpha: .3),
          ),
        ),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: expired ? AppColors.getTheme().errorRed.withValues(alpha: .6) : AppColors.getTheme().textColor.withValues(alpha: .6),
              fontWeight: FontWeight.w600,
              fontSize: 14
          ),
        ),
        Expanded(
          child: Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 30),
            color: expired ? AppColors.getTheme().errorRed.withValues(alpha: .3) : AppColors.getTheme().textColor.withValues(alpha: .3),
          ),
        ),
      ],
    );
  }

  void _setupPeriods(){
    _periodsNotificationList.clear();
    periodList.clear();
    countActivePeriods = 0;
    countFuturePeriods = 0;
    countExpiredPeriods = 0;
    //order them
    for (int i = 0; i < periodEntries.length; i++){
      for (int j = i; j < periodEntries.length; j++){
        if(periodEntries[j].startEpoch < periodEntries[i].startEpoch){
          final tmp = periodEntries[i];
          periodEntries[i] = periodEntries[j];
          periodEntries[j] = tmp;
        }
      }
    }

    int prevSemester = -1;

    List<api.PeriodEntry> expiredPeriods = [];
    bool hasFuturePeriodLine = false;
    //Map<String, List<api.PeriodType>> values = Map<String, List<api.PeriodType>>.identity();
    for(var item in periodEntries){
      if(item.isActive){
        countActivePeriods++;
      }
      else if(item.endEpoch > DateTime.now().millisecondsSinceEpoch){
        if(!hasFuturePeriodLine){
          hasFuturePeriodLine = true;
          periodList.add(
              const Padding(padding: EdgeInsets.only(top: 10))
          );
          periodList.add(
              _getSeparatorLine(AppStrings.getLanguagePack().topheader_periods_FutureText)
          );
        }
        countFuturePeriods++;
      }
      else{
        countExpiredPeriods++;
      }

      final starttime = DateTime.fromMillisecondsSinceEpoch(item.startEpoch);
      final endtime = DateTime.fromMillisecondsSinceEpoch(item.endEpoch);
      final now = DateTime.now().millisecondsSinceEpoch;
      if(now > endtime.millisecondsSinceEpoch){
        expiredPeriods.add(item);
        continue; // expired
      }
      if(prevSemester == -1 && countActivePeriods != 0){
        prevSemester = item.partofSemester;
        periodList.add(
            const Padding(padding: EdgeInsets.only(top: 10))
        );
        periodList.add(
            _getSeparatorLine(AppStrings.getLanguagePack().topheader_periods_ActiveText)
        );
      }
      else if(item.partofSemester != prevSemester){
        prevSemester = item.partofSemester;
      }
      if(!item.isActive){ // exclude today
        _periodsNotificationList.add(item);
      }
      periodList.add(priods.PeriodsElementWidget(
        displayName: api.Generic.capitalizePeriodText(item.name),
        formattedStartTime: '${api.Generic.monthToText(starttime.month)}. ${starttime.day}.',
        formattedStartTimeYear: '${starttime.year}',
        formattedEndTime: '${api.Generic.monthToText(endtime.month)}. ${endtime.day}.',
        formattedEndTimeYear: '${endtime.year}',
        isActive: item.isActive,
        periodType: item.type,
        startTime: item.startEpoch,
        endTime: (DateTime.fromMillisecondsSinceEpoch(item.endEpoch).millisecondsSinceEpoch),
        expired: false,
      ));
      if(currentSemester == -1) {
        currentSemester = item.partofSemester;
      }
    }

    if(expiredPeriods.isNotEmpty){
      periodList.add(
          const Padding(padding: EdgeInsets.only(top: 10))
      );

      periodList.add(
          _getSeparatorLine(AppStrings.getLanguagePack().topheader_periods_ExpiredText, expired: true)
      );
    }
    
    for(var item in expiredPeriods){
      final starttime = DateTime.fromMillisecondsSinceEpoch(item.startEpoch);
      final endtime = DateTime.fromMillisecondsSinceEpoch(item.endEpoch);
      periodList.add(priods.PeriodsElementWidget(
        displayName: api.Generic.capitalizePeriodText(item.name),
        formattedStartTime: '${api.Generic.monthToText(starttime.month)}. ${starttime.day}.',
        formattedStartTimeYear: '${starttime.year}',
        formattedEndTime: '${api.Generic.monthToText(endtime.month)}. ${endtime.day}.',
        formattedEndTimeYear: '${endtime.year}',
        isActive: item.isActive,
        periodType: item.type,
        startTime: item.startEpoch,
        endTime: (DateTime.fromMillisecondsSinceEpoch(item.endEpoch).millisecondsSinceEpoch),
        expired: true,
      ));
    }

    if(_periodsNotificationList.isNotEmpty){
      Future.delayed(Duration.zero,()async{
        await _setupPeriodsNotification(_periodsNotificationList);
      });
    }

    if(periodEntries.isEmpty){
      periodList.add(Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Center(
          child: EmojiRichText(
            text: AppStrings.getLanguagePack().periodPage_Empty,
            defaultStyle: TextStyle(
              color: AppColors.getTheme().onPrimaryContainer,
              fontWeight: FontWeight.w900,
              fontSize: 26.0,
            ),
            emojiStyle: TextStyle(
                color: AppColors.getTheme().onPrimaryContainer,
                fontSize: 26.0,
                fontFamily: "Noto Color Emoji"
            ),
          ),
        ),
      ));
    }
  }

  void _setupMails(){
    final visible = filteredMailEntries();
    final hasActiveFilter = mailUnreadOnly || mailSearchQuery.trim().isNotEmpty;

    if(mailEntries.isEmpty){
      mailList.add(Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Center(
          child: EmojiRichText(
            text: AppStrings.getLanguagePack().messagePage_Empty,
            defaultStyle: TextStyle(
              color: AppColors.getTheme().onPrimaryContainer,
              fontWeight: FontWeight.w900,
              fontSize: 26.0,
            ),
            emojiStyle: TextStyle(
                color: AppColors.getTheme().onPrimaryContainer,
                fontSize: 26.0,
                fontFamily: "Noto Color Emoji"
            ),
          ),
        ),
      ));
      return;
    }

    if (visible.isEmpty && hasActiveFilter) {
      mailList.add(Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Center(
          child: Text(
            AppStrings.getLanguagePack().mail_filter_NoMatches,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.getTheme().onPrimaryContainer.withValues(alpha: 0.7),
              fontWeight: FontWeight.w700,
              fontSize: 18.0,
            ),
          ),
        ),
      ));
      return;
    }

    int idx = 0;
    var prevDate = DateTime.fromMillisecondsSinceEpoch(0);
    mailList.add(
        const Padding(padding: EdgeInsets.only(top: 10))
    );
    for(var item in visible){
      final date = DateTime.fromMillisecondsSinceEpoch(item.sendDateMs);
      final currDate = DateTime(date.year, date.month, date.day);
      if(++idx == 1 || prevDate != currDate){
        prevDate = currDate;
        mailList.add(_getSeparatorLine('${currDate.year}. ${api.Generic.monthToText(date.month)}. ${date.day}.'));
      }
      mailList.add(MailElementWidget(subject: item.subject, details: item.detail, sender: item.senderName, sendTime: item.sendDateMs, isRead: item.isRead, mailID: item.ID, callback: (element){
        setState(() {
          if(element.isRead){
            return;
          }
          for (final entry in mailEntries) {
            if (entry.ID == element.mailID) {
              entry.isRead = true;
              break;
            }
          }
          unreadMailCount = unreadMailCount > 0 ? unreadMailCount - 1 : 0;
          storage.saveInt('CachedMailsUnread', unreadMailCount);
          mailList.clear();
          allLoadedMailCount = mailEntries.length;
          _setupMails();
          Future.delayed(Duration.zero, ()async{
            await api.MailRequest.setMailRead(MailPopupDisplayTexts.mailID);
            if(currentMailPage == 1){
              storage.DataCache.setHasCachedMail(0);
            }
          });
        });
      },));
    }
  }

  Future<void> stepCalendarBack() async{
    currentWeekOffset--;
    AppHaptics.lightImpact();
    await onCalendarRefresh(true);
  }
  Future<void> stepCalendarForward() async{
    currentWeekOffset++;
    AppHaptics.lightImpact();
    await onCalendarRefresh(true);
  }

  Future<List<api.CalendarEntry>> fetchCalendarToList(int offset) async{
    //final userOffset = storage.DataCache.getUserWeekOffset()!;
    final request = await api.CalendarRequest.makeCalendarRequest(api.CalendarRequest.getCalendarOneWeekJSON(storage.DataCache.getUsername()!, storage.DataCache.getPassword()!, currentWeekOffset + offset));
    final list = api.CalendarRequest.getCalendarEntriesFromJSON(request);
    //return list2;
    return list;
  }

  Future<void> fetchCalendar({bool allowCache = true, bool silentRefreshIfOnline = true}) async{
    if(storage.DataCache.getHasICSFile() ?? false){
      final DateTime now = DateTime.now();
      final mondayThisWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
      final int deltaWeeks = currentWeekOffset - 1;

      final startOfTargetWeek = mondayThisWeek.add(Duration(days: deltaWeeks * 7));
      final endOfTargetWeek = startOfTargetWeek.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59, milliseconds: 999));

      final epochStart = startOfTargetWeek.millisecondsSinceEpoch;
      final epochEnd = endOfTargetWeek.millisecondsSinceEpoch;

      calendarEntries.clear();
      calendarEntries = ICSCalendar.getCalendarInterval(epochStart, epochEnd);

      storage.DataCache.setHasCachedFirstWeekEpoch(1);
      return;
    }

    final activeTerm = storage.DataCache.getSelectedTermId() ?? '';
    final cachedTerm = await storage.getString('CalendarCacheTermId');
    final bool hasNetwork = storage.DataCache.getHasNetwork();
    bool paintedFromCache = false;

    // 1. Cache first (including empty weeks — len==0 means loaded-empty, not missing).
    if (allowCache) {
      final weekKey = 'CachedCalendar_w$currentWeekOffset';
      int? len = await storage.getInt('${weekKey}_len');
      if (len == null && currentWeekOffset == 1) {
        len = await storage.getInt('CachedCalendarLength');
      }

      if (len != null && (cachedTerm == activeTerm || activeTerm.isEmpty || !hasNetwork || cachedTerm == null)) {
        final List<api.CalendarEntry> cached = [];
        for (int i = 0; i < len; i++) {
          final calEntry = await storage.getString('${weekKey}_$i') ?? (currentWeekOffset == 1 ? await storage.getString('CachedCalendar_$i') : null);
          if (calEntry != null) {
            cached.add(api.CalendarEntry('0', '0', 'NULL', 'NULL', false).fillWithExisting(calEntry));
          }
        }
        // Accept empty cache (honest free week) as well as non-empty.
        calendarEntries = cached;
        paintedFromCache = true;
        storage.DataCache.setHasCachedFirstWeekEpoch(1);
        if (cached.isNotEmpty) {
          api.CalendarRequest.fillMissingDetails(calendarEntries, () {
            if (mounted) setState(() {});
          });
        }

        if (currentWeekOffset == 1 && cached.isNotEmpty) {
          Future.delayed(Duration.zero, () async {
            await _setupClassesNotifications(_classesNotificationList);
          });
        }

        if (!hasNetwork || !silentRefreshIfOnline || api.SessionGuard.isAuthBlocked) {
          _setShowingCached(paintedFromCache && (!hasNetwork || api.SessionGuard.isAuthBlocked));
          return;
        }
      }
    }

    if (!hasNetwork || api.SessionGuard.isAuthBlocked) {
      _setShowingCached(paintedFromCache);
      return;
    }

    try {
      final request = await api.CalendarRequest.makeCalendarRequest(
        api.CalendarRequest.getCalendarOneWeekJSON(
          storage.DataCache.getUsername()!,
          storage.DataCache.getPassword()!,
          currentWeekOffset,
        ),
      );
      final list = api.CalendarRequest.getCalendarEntriesFromJSON(request);

      // Replace only when we got a real response (empty week OK if request body present).
      if (list.isNotEmpty || request.isNotEmpty) {
        calendarEntries = list;

        api.CalendarRequest.fillMissingDetails(calendarEntries, () {
          if (mounted) setState(() {});
        });

        final weekKey = 'CachedCalendar_w$currentWeekOffset';
        await storage.saveInt('${weekKey}_len', calendarEntries.length);
        for (int i = 0; i < calendarEntries.length; i++) {
          await storage.saveString('${weekKey}_$i', calendarEntries[i].toString());
        }

        if (currentWeekOffset == 1) {
          await storage.saveInt('CachedCalendarLength', calendarEntries.length);
          await storage.saveString('CalendarCacheTermId', activeTerm);
          for (int i = 0; i < calendarEntries.length; i++) {
            await storage.saveString('CachedCalendar_$i', calendarEntries[i].toString());
          }
          final now = DateTime.now();
          await storage.saveString('CalendarCacheTime', DateTime(now.year, now.month, now.day, 0, 0, 0).toString());
          await storage.DataCache.setHasCachedCalendar(1);
          Future.delayed(Duration.zero, () async {
            await _setupClassesNotifications(_classesNotificationList);
          });
        }
        _setShowingCached(false);
      } else if (paintedFromCache) {
        _setShowingCached(true);
      }
    } catch (e) {
      debugPrint("Hiba a naptár hálózati lekérésekor: $e");
      _setShowingCached(paintedFromCache);
    }
  }

  Future<bool> _loadMarkbookFromCache() async {
    final len = await storage.getInt('CachedMarkbookLength');
    if (len == null || len <= 0) return false;
    final loaded = <api.Subject>[];
    for (int i = 0; i < len; i++) {
      final calEntry = await storage.getString('CachedMarkbook_$i');
      if (calEntry != null) {
        loaded.add(api.Subject(false, 0, 'NULL', 0, 0, 0).fillWithExisting(calEntry));
      }
    }
    if (loaded.isEmpty) return false;
    markbookEntries = loaded;
    return true;
  }

  Future<void> fetchMarkbook() async{
    final cacheTime = await storage.getString('MarkbookCacheTime');
    final cachedTerm = await storage.getString('MarkbookCacheTermId');
    final currentTerm = storage.DataCache.getSelectedTermId() ?? '';
    final hasCached = storage.DataCache.getHasCachedMarkbook() ?? false;
    final cacheFresh = hasCached &&
        (cachedTerm == currentTerm || currentTerm.isEmpty) &&
        cacheTime != null &&
        (DateTime.now().millisecondsSinceEpoch - DateTime.parse(cacheTime).millisecondsSinceEpoch) <
            const Duration(hours: 24).inMilliseconds;

    bool paintedFromCache = false;
    if (hasCached && (cachedTerm == currentTerm || currentTerm.isEmpty || !storage.DataCache.getHasNetwork())) {
      paintedFromCache = await _loadMarkbookFromCache();
    }

    if (cacheFresh && paintedFromCache) {
      _setShowingCached(false);
      return;
    }

    if (!storage.DataCache.getHasNetwork() || api.SessionGuard.isAuthBlocked) {
      if (!paintedFromCache) {
        // Do not leave a cleared list if we somehow wiped first.
        paintedFromCache = await _loadMarkbookFromCache();
      }
      _setShowingCached(paintedFromCache);
      return;
    }

    try {
      final request = await api.MarkbookRequest.getMarkbookSubjects(termId: currentTerm.isNotEmpty ? currentTerm : null);
      if (request != null) {
        markbookEntries = request;
        storage.saveInt('CachedMarkbookLength', markbookEntries.length);
        for (int i = 0; i < markbookEntries.length; i++) {
          storage.saveString('CachedMarkbook_$i', markbookEntries[i].toString());
        }
        storage.saveString('MarkbookCacheTime', DateTime.now().toString());
        storage.saveString('MarkbookCacheTermId', currentTerm);
        storage.DataCache.setHasCachedMarkbook(1);
        await _recordMarkbookWhatsChanged();
        _setShowingCached(false);
      } else if (!paintedFromCache) {
        markbookEntries = [];
      } else {
        _setShowingCached(true);
      }
    } catch (e) {
      debugPrint('fetchMarkbook network: $e');
      if (!paintedFromCache) {
        paintedFromCache = await _loadMarkbookFromCache();
      }
      _setShowingCached(paintedFromCache);
    }
  }

  Future<bool> _loadPaymentsFromCache() async {
    final len = await storage.getInt('CachedPaymentsLength');
    if (len == null || len <= 0) return false;
    final loaded = <api.CashinEntry>[];
    for (int i = 0; i < len; i++) {
      final calEntry = await storage.getString('CachedPayments_$i');
      if (calEntry != null) {
        loaded.add(api.CashinEntry(0, 0, "ERROR", "ERROR", "").fillWithExisting(calEntry));
      }
    }
    if (loaded.isEmpty) return false;
    paymentsEntries = loaded;
    return true;
  }

  Future<void> fetchPayments() async{
    final cacheTime = await storage.getString('PaymentsCacheTime');
    final hasCached = storage.DataCache.getHasCachedPayments() ?? false;
    final cacheFresh = hasCached &&
        cacheTime != null &&
        (DateTime.now().millisecondsSinceEpoch - DateTime.parse(cacheTime).millisecondsSinceEpoch) <
            const Duration(hours: 24).inMilliseconds;

    bool paintedFromCache = false;
    if (hasCached) {
      paintedFromCache = await _loadPaymentsFromCache();
    }

    if (cacheFresh && paintedFromCache) {
      try {
        invoiceEntries = await api.CashinRequest.getCollectiveInvoices();
      } catch (_) {}
      _setShowingCached(false);
      return;
    }

    if (!storage.DataCache.getHasNetwork() || api.SessionGuard.isAuthBlocked) {
      if (!paintedFromCache) paintedFromCache = await _loadPaymentsFromCache();
      _setShowingCached(paintedFromCache);
      return;
    }

    try {
      final request = await api.CashinRequest.getAllCashins();
      invoiceEntries = await api.CashinRequest.getCollectiveInvoices();
      await api.CashinRequest.getCollectiveInvoiceBalance();
      if (request != null) {
        paymentsEntries = request;
        storage.saveInt('CachedPaymentsLength', paymentsEntries.length);
        for (int i = 0; i < paymentsEntries.length; i++) {
          storage.saveString('CachedPayments_$i', paymentsEntries[i].toString());
        }
        storage.saveString('PaymentsCacheTime', DateTime.now().toString());
        storage.DataCache.setHasCachedPayments(1);
        _setShowingCached(false);
      } else if (!paintedFromCache) {
        paymentsEntries = [];
      } else {
        _setShowingCached(true);
      }
    } catch (e) {
      debugPrint('fetchPayments network: $e');
      if (!paintedFromCache) paintedFromCache = await _loadPaymentsFromCache();
      _setShowingCached(paintedFromCache);
    }
  }

  Future<bool> _loadPeriodsFromCache() async {
    final len = await storage.getInt('CachedPeriodsLength');
    if (len == null || len <= 0) return false;
    final loaded = <api.PeriodEntry>[];
    for (int i = 0; i < len; i++) {
      final calEntry = await storage.getString('CachedPeriods_$i');
      if (calEntry != null) {
        loaded.add(api.PeriodEntry("ERROR", 0, 0, 0).fillWithExisting(calEntry));
      }
    }
    if (loaded.isEmpty) return false;
    periodEntries = loaded;
    return true;
  }

  Future<void> fetchPeriods() async{
    final cacheTime = await storage.getString('PeriodsCacheTime');
    final cachedTerm = await storage.getString('PeriodsCacheTermId');
    final currentTerm = storage.DataCache.getSelectedTermId() ?? '';
    final hasCached = storage.DataCache.getHasCachedPeriods() ?? false;
    final cacheFresh = hasCached &&
        (cachedTerm == currentTerm || currentTerm.isEmpty) &&
        cacheTime != null &&
        (DateTime.now().millisecondsSinceEpoch - DateTime.parse(cacheTime).millisecondsSinceEpoch) <
            const Duration(hours: 24).inMilliseconds;

    bool paintedFromCache = false;
    if (hasCached && (cachedTerm == currentTerm || currentTerm.isEmpty || !storage.DataCache.getHasNetwork())) {
      paintedFromCache = await _loadPeriodsFromCache();
    }

    if (cacheFresh && paintedFromCache) {
      _setShowingCached(false);
      return;
    }

    if (!storage.DataCache.getHasNetwork() || api.SessionGuard.isAuthBlocked) {
      if (!paintedFromCache) paintedFromCache = await _loadPeriodsFromCache();
      _setShowingCached(paintedFromCache);
      return;
    }

    try {
      final request = await api.PeriodsRequest.getPeriods(termId: currentTerm.isNotEmpty ? currentTerm : null);
      if (request != null) {
        periodEntries = request;
        storage.saveInt('CachedPeriodsLength', periodEntries.length);
        for (int i = 0; i < periodEntries.length; i++) {
          storage.saveString('CachedPeriods_$i', periodEntries[i].toString());
        }
        storage.saveString('PeriodsCacheTime', DateTime.now().toString());
        storage.saveString('PeriodsCacheTermId', currentTerm);
        storage.DataCache.setHasCachedPeriods(1);
        _setShowingCached(false);
      } else if (!paintedFromCache) {
        periodEntries = [];
      } else {
        _setShowingCached(true);
      }
    } catch (e) {
      debugPrint('fetchPeriods network: $e');
      if (!paintedFromCache) paintedFromCache = await _loadPeriodsFromCache();
      _setShowingCached(paintedFromCache);
    }
  }

  int currentMailPage = 1;
  bool currentMailLoadingDebounce = false;
  late ScrollController currentMailPageController;
  Future<void> fetchMails({bool force = false})async{
    final hasCachedMails = storage.DataCache.getHasCachedMail() ?? false;
    final cacheTime = await storage.getString('MailCacheTime');
    final cacheFresh = !force &&
        hasCachedMails &&
        cacheTime != null &&
        (DateTime.now().millisecondsSinceEpoch - DateTime.parse(cacheTime).millisecondsSinceEpoch) <
            const Duration(hours: 24).inMilliseconds;

    Future<bool> loadMailCache() async {
      final len = await storage.getInt('CachedMailsLength');
      if (len == null || len < 0) return false;
      unreadMailCount = (await storage.getInt('CachedMailsUnread')) ?? 0;
      totalMailCount = (await storage.getInt('CachedMailsTotal')) ?? 0;
      final loaded = <api.MailEntry>[];
      for (int i = 0; i < len; i++) {
        final calEntry = await storage.getString('CachedMails_$i');
        if (calEntry != null) {
          loaded.add(api.MailEntry("ERROR", "ERROR", "ERROR", 0, false,"").fillWithExisting(calEntry));
        }
      }
      if (loaded.isEmpty && len > 0) return false;
      if (!force || currentMailPage <= 1) {
        mailEntries = loaded;
        allLoadedMailCount = loaded.length;
        _lastMailPageWasFull = loaded.length >= 20 && (totalMailCount == 0 || loaded.length < totalMailCount);
      }
      return hasCachedMails;
    }

    bool paintedFromCache = false;
    if (hasCachedMails && (cacheFresh || !storage.DataCache.getHasNetwork() || api.SessionGuard.isAuthBlocked)) {
      paintedFromCache = await loadMailCache();
      if (cacheFresh && paintedFromCache) {
        _setShowingCached(false);
        return;
      }
      if (!storage.DataCache.getHasNetwork() || api.SessionGuard.isAuthBlocked) {
        _setShowingCached(paintedFromCache);
        return;
      }
    }

    if (!storage.DataCache.getHasNetwork() && !force) {
      if (!paintedFromCache) paintedFromCache = await loadMailCache();
      _setShowingCached(paintedFromCache);
      return;
    }

    if (api.SessionGuard.isAuthBlocked) {
      if (!paintedFromCache) paintedFromCache = await loadMailCache();
      _setShowingCached(paintedFromCache);
      return;
    }

    try {
      final request = await api.MailRequest.getMails(currentMailPage);
      if (request == null) {
        if (!paintedFromCache) paintedFromCache = await loadMailCache();
        _setShowingCached(paintedFromCache);
        return;
      }
      if (request.isEmpty && currentMailPage <= 1) {
        if (!paintedFromCache) paintedFromCache = await loadMailCache();
        _setShowingCached(paintedFromCache);
        return;
      }

      _lastMailPageWasFull = request.length >= 20;
      if (currentMailPage <= 1) {
        mailEntries = request;
      } else {
        final seen = mailEntries.map((e) => e.ID).toSet();
        for (final m in request) {
          if (!seen.contains(m.ID)) {
            mailEntries.add(m);
            seen.add(m.ID);
          }
        }
      }
      allLoadedMailCount = mailEntries.length;

      if (force && currentMailPage > 1) {
        final apiTotal = api.MailRequest.lastTotalRowCount;
        if (apiTotal > 0) {
          totalMailCount = apiTotal;
        }
        return;
      }

      final nums = await api.MailRequest.getUnreadMessagesAndAllMessages();
      unreadMailCount = nums[0];
      final apiTotal = api.MailRequest.lastTotalRowCount;
      if (apiTotal > 0) {
        totalMailCount = apiTotal;
      } else if (nums[1] > 0) {
        totalMailCount = nums[1];
      } else if (totalMailCount < mailEntries.length) {
        totalMailCount = mailEntries.length;
      }

      storage.saveInt('CachedMailsLength', mailEntries.length);
      storage.saveInt('CachedMailsUnread', unreadMailCount);
      storage.saveInt('CachedMailsTotal', totalMailCount);
      for (int i = 0; i < mailEntries.length; i++) {
        storage.saveString('CachedMails_$i', mailEntries[i].toString());
      }
      storage.saveString('MailCacheTime', DateTime.now().toString());
      storage.DataCache.setHasCachedMail(1);
      await _recordMailWhatsChanged();
      _setShowingCached(false);
    } catch (e) {
      debugPrint('fetchMails network: $e');
      if (!paintedFromCache) paintedFromCache = await loadMailCache();
      _setShowingCached(paintedFromCache);
    }
  }

  Timer? _calendarTimer;

  bool _calendarDebounce = false;
  bool isLoadingCalendar = true;

  bool keepHomeButtonHidden = true;

  bool _noRefreshCalendar = false;

  Future<void> onCalendarRefresh(bool isPaging) async{
    if(_noRefreshCalendar){
      Future.delayed(const Duration(seconds: 2), (){
        _noRefreshCalendar = false;
      });
    }
    if(_calendarDebounce || _noRefreshCalendar){
      return;
    }
    _calendarTimer?.cancel();
    _calendarDebounce = true;
    keepHomeButtonHidden = false;
    // Keep existing day lists painted; only show week-nav loading hint.
    setState(() {
      weeksSinceStart = calcPassedWeeks();
      canDoCalendarPaging = false;
      isLoadingCalendar = true;
    });

    try {
      // Prefer cache paint first so pull-to-refresh never blanks the week.
      await fetchCalendar(allowCache: true, silentRefreshIfOnline: true);
      setupCalendar(false);
    } catch (e) {
      debugPrint("Hiba az onCalendarRefresh során: $e");
    } finally {
      _calendarDebounce = false;
      if (mounted) {
        setState(() {
          isLoadingCalendar = false;
          canDoCalendarPaging = true;
        });
      }
    }
  }

  bool _markbookDebounce = false;
  bool _noRefreshMarkbook = false;
  Future<void> onMarkbookRefresh() async{
    if(_noRefreshMarkbook){
      Future.delayed(Duration(seconds: 2), (){
        _noRefreshMarkbook = false;
      });
    }
    if(!storage.DataCache.getHasNetwork() || _markbookDebounce || _noRefreshMarkbook){
      return;
    }
    _markbookDebounce = true;
    clearMarkbook();
    await storage.DataCache.setHasCachedMarkbook(0);
    await api.TermsRequest.getTerms(forceRefresh: true);
    await fetchMarkbook();
    setupMarkbook();
    _markbookDebounce = false;
  }

  bool _paymentsDebounce = false;
  bool _noRefreshPayments = false;

  Future<void> onPaymentsRefresh() async{
    if(_noRefreshPayments){
      Future.delayed(Duration(seconds: 2), (){
        _noRefreshPayments = false;
      });
    }
    if(!storage.DataCache.getHasNetwork() || _paymentsDebounce || _noRefreshPayments){
      return;
    }
    _paymentsDebounce = true;
    clearPayments();
    await storage.DataCache.setHasCachedPayments(0);
    await fetchPayments();
    setupPayments();
    _paymentsDebounce = false;
  }

  bool _periodsDebounce = false;
  bool _noRefreshPeriods = false;

  Future<void> onPeriodsRefresh()async{
    if(_noRefreshPeriods){
      Future.delayed(Duration(seconds: 2), (){
        _noRefreshPeriods = false;
      });
    }
    if(!storage.DataCache.getHasNetwork() || _periodsDebounce || _noRefreshPeriods){
      return;
    }
    _periodsDebounce = true;
    clearPeriods();
    await storage.DataCache.setHasCachedPeriods(0);
    await api.TermsRequest.getTerms(forceRefresh: true);
    await fetchPeriods();
    setupPeriods();
    _periodsDebounce = false;
  }

  bool _mailsDebounce = false;
  bool _noRefreshMail = false;

  Future<void> onMailRefresh()async{
    if(_noRefreshMail){
      Future.delayed(Duration(seconds: 2), (){
        _noRefreshMail = false;
      });
    }
    if(!storage.DataCache.getHasNetwork() || _mailsDebounce || _noRefreshMail){
      return;
    }
    _mailsDebounce = true;
    clearMails();
    await storage.DataCache.setHasCachedMail(0);
    await fetchMails();
    setupMails();
    _mailsDebounce = false;
  }

  DateTime getClosestMondayTo(DateTime time){
    // Monday on or before [time] (study-week aligned).
    return DateTime(time.year, time.month, time.day)
        .subtract(Duration(days: time.weekday - DateTime.monday));
  }

  int calcPassedWeeks() {
    // Displayed education week for the *viewed* calendar page:
    // weeks from firstMonday to this week's Monday + currentWeekOffset
    // (offset 1 = current week). So firstMonday = week containing Sep 1 →
    // prev page (1–7 Sep) = 1, current (7–14 Sep) = 2.
    final epochsemester = storage.DataCache.getFirstWeekEpoch()!;
    final now = DateTime.now();
    late final DateTime firstMonday;
    if (epochsemester > 0) {
      final d = DateTime.fromMillisecondsSinceEpoch(epochsemester);
      firstMonday = DateTime(d.year, d.month, d.day);
    } else {
      final sep = DateTime(
        now.year - (now.isBefore(DateTime(now.year, 9, 1)) ? 1 : 0),
        9,
        1,
      );
      firstMonday = getClosestMondayTo(sep);
    }
    final thisMonday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - DateTime.monday));
    final weeksPassed = thisMonday.difference(firstMonday).inDays ~/ 7;
    final userOffset = storage.DataCache.getUserWeekOffset()!;
    return weeksPassed + currentWeekOffset + userOffset;
  }
  
  int calcPassedWeekOffsetless(){
    final epochsemester = storage.DataCache.getFirstWeekEpoch()!;
    final now = DateTime.now();
    late final DateTime firstMonday;
    if (epochsemester > 0) {
      final d = DateTime.fromMillisecondsSinceEpoch(epochsemester);
      firstMonday = DateTime(d.year, d.month, d.day);
    } else {
      final sep = DateTime(
        now.year - (now.isBefore(DateTime(now.year, 9, 1)) ? 1 : 0),
        9,
        1,
      );
      firstMonday = getClosestMondayTo(sep);
    }
    final thisMonday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - DateTime.monday));
    return thisMonday.difference(firstMonday).inDays ~/ 7;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Wall-clock across background: Timer often pauses while suspended.
      api.SessionGuard.checkSessionWallClockOnResume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (identical(_instance, this)) {
      _instance = null;
    }
    _connectivitySubscription?.cancel();
    _calendarTimer?.cancel();
    super.dispose();
    calendarEntries.clear();
    mondayCalendar.clear();
    tuesdayCalendar.clear();
    wednessdayCalendar.clear();
    thursdayCalendar.clear();
    fridayCalendar.clear();
    saturdayCalendar.clear();
    sundayCalendar.clear();
    markbookEntries.clear();
    markbookList.clear();
    calendarTabController.dispose();
    paymentsEntries.clear();
    invoiceEntries.clear();
    paymentsList.clear();
    periodList.clear();
    periodEntries.clear();
    mailList.clear();
    mailEntries.clear();
    _fbController.dispose();
    currentMailPageController.dispose();
    mailSearchController.dispose();
    blurController.dispose();
  }

  static Container getSeparatorLine(BuildContext context){
    return Container(
      width: MediaQuery.of(context).size.width / 1.2,
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.getTheme().textColor.withValues(alpha: 0),
            AppColors.getTheme().textColor.withValues(alpha: 0.2),
            AppColors.getTheme().textColor.withValues(alpha: 0.4),
            AppColors.getTheme().textColor.withValues(alpha: 0.4),
            AppColors.getTheme().textColor.withValues(alpha: 0.2),
            AppColors.getTheme().textColor.withValues(alpha: 0),
          ]
        ),
      ),
    );
  }

  void switchView(int to){
    // 0–3 bottom tabs; 4 Payments from drawer.
    if (to < 0 || to > 4) return;
    if(currentView == to){
      return;
    }
    setState(() {
      currentView = to;
    });
  }

  late AnimationController _fbController;
  late Animation<double> _fbTween;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        drawer: AppDrawer(
            loggedInUsername: storage.DataCache.getUsername()!,
            loggedInURL: storage.DataCache.getInstituteUrl()!.replaceAll(RegExp(r'/hallgato/MobileService\.svc'), '').replaceAll("https://", '')
        ),
      body: SafeArea(
        child: Stack(
        children: [
          Visibility(
              visible: currentView == 0,
              child: CalendarPageWidget(homePage: this, greetText: calendarGreetText, calendarTabs: calendarTabs, calendarTabViews: calendarTabViews)
          ),
          Visibility(
              visible: currentView == 1,
              child: MarkbookPageWidget(homePage: this, totalCredits: totalCredits, totalAvg: totalAvg, totalAvg30: totalAvg30,)
          ),
          Visibility(
            visible: currentView == 2,
            child: PeriodsPageWidget(homePage: this, currentSemester: currentSemester),
          ),
          Visibility(
            visible: currentView == 3,
            child: MailsPageWidget(homePage: this),
          ),
          Visibility(
              visible: currentView == 4,
              child: PaymentsPageWidget(homePage: this, totalMoney: totalMoney)
          ),
          Visibility(
            visible: currentView == 0 && currentWeekOffset != 1 && canDoCalendarPaging && !keepHomeButtonHidden,
            child: GestureDetector(
              onPanEnd: (_){
                setState(() {
                  _fbNeedAnimate = true;
                });
                _fbController.forward(from: 0).whenComplete(() {
                  final size = MediaQuery.of(context).size;

                  setState(() {
                    _fbPosX = size.width - 90;
                    _fbPosY = size.height - 140;
                  });
                });
              },
              onPanStart: (_){
                setState(() {
                  _fbNeedAnimate = false;
                });
              },
              onPanUpdate: (details){
                final size = MediaQuery.of(context).size;

                setState(() {
                  _fbPosX += details.delta.dx;
                  _fbPosY += details.delta.dy;

                  _fbPosX = _fbPosX < 20 ? 20 : (_fbPosX > size.width - 80 ? size.width - 80 : _fbPosX);
                  _fbPosY = _fbPosY < 120 ? 120 : (_fbPosY > size.height - 140 ? size.height - 140 : _fbPosY);
                });
              },
              child: AnimatedBuilder(
                animation: _fbController,
                builder: (context, child) {
                  return Padding(
                    padding: EdgeInsets.only(left: _fbNeedAnimate ? (lerpDouble(_fbPosX, MediaQuery.of(context).size.width - 90, _fbTween.value))! : _fbPosX, top: _fbNeedAnimate ? ((lerpDouble(_fbPosY, MediaQuery.of(context).size.height - 140, _fbTween.value))!) : _fbPosY),
                    child: IconButton(
                      onPressed: (() async {
                        AppHaptics.lightImpact();
                        keepHomeButtonHidden = true;
                        currentWeekOffset = 1;
                        await onCalendarRefresh(false);
                      }),
                      icon: Icon(
                        Icons.home_outlined,
                        color: AppColors.getTheme().onPrimary,
                      ),
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(const EdgeInsets.all(15)),
                        backgroundColor: WidgetStateProperty.all(AppColors.getTheme().primary)
                      ),
                    ),
                  );
                }
              ),
            ),
          ),
          Visibility(
            visible: _showBlur,
            child: AnimatedBuilder(
              animation: blurController,
              builder: (context, widget) {
                return Positioned.fill(
                  child: BackdropFilter(
                     filter: ImageFilter.blur(sigmaX: blurAnimation.value * 15, sigmaY: blurAnimation.value * 15),
                     child: Container(
                       color: Colors.black.withValues(alpha: blurAnimation.value * 0.4),
                     ),
                   ),
                );
              },
            ),
          ),
        ],
      ),
      )
    );
  }
}

class CalendarPageWidget extends StatelessWidget{
  final HomePageState homePage;
  final String greetText;
  final List<Widget> calendarTabs;
  final List<Widget> calendarTabViews;
  const CalendarPageWidget({super.key, required this.homePage, required this.greetText, required this.calendarTabs, required this.calendarTabViews});

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          color: AppColors.getTheme().secondary,
          fontWeight: FontWeight.w800,
          fontSize: 12,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _eventLine(api.CalendarEntry e) {
    final start = DateTime.fromMillisecondsSinceEpoch(e.startEpoch);
    final hh = start.hour.toString().padLeft(2, '0');
    final mm = start.minute.toString().padLeft(2, '0');
    final day = '${start.month}/${start.day}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              '$day $hh:$mm',
              style: TextStyle(
                color: AppColors.getTheme().textColor.withValues(alpha: 0.55),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              e.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.getTheme().textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _extraCalendarSections() {
    final lang = AppStrings.getLanguagePack();
    final now = DateTime.now().millisecondsSinceEpoch;
    final until = now + const Duration(hours: 48).inMilliseconds;

    List<api.CalendarEntry> sorted(Iterable<api.CalendarEntry> src) {
      final list = src.toList()..sort((a, b) => a.startEpoch.compareTo(b.startEpoch));
      return list;
    }

    // Next 48h: classes + exams only (no period banners, no ZH/tasks).
    final next48 = sorted(homePage.calendarEntries.where((e) =>
        e.startEpoch >= now &&
        e.startEpoch <= until &&
        !e.isPeriodBanner &&
        !e.isTask)).take(6).toList();

    // Upcoming tasks/ZH from now (not “first 8 in week” regardless of past).
    final tasks = sorted(homePage.calendarEntries.where((e) => e.isTask && e.startEpoch >= now)).take(8).toList();

    // Upcoming exams from now.
    final exams = sorted(homePage.calendarEntries.where((e) => e.isExam && e.startEpoch >= now)).take(8).toList();

    // Period banners only in this strip.
    final banners = sorted(homePage.calendarEntries.where((e) => e.isPeriodBanner)).take(8).toList();

    final out = <Widget>[];
    if (next48.isNotEmpty) {
      out.add(_sectionHeader(lang.calendar_next48h_Header));
      out.addAll(next48.map(_eventLine));
    }
    if (tasks.isNotEmpty) {
      out.add(_sectionHeader(lang.calendar_tasks_Header));
      out.addAll(tasks.map(_eventLine));
    }
    if (exams.isNotEmpty) {
      out.add(_sectionHeader(lang.calendar_exams_Header));
      out.addAll(exams.map(_eventLine));
    }
    if (banners.isNotEmpty) {
      out.add(_sectionHeader(lang.calendar_periods_Header));
      out.addAll(banners.map(_eventLine));
    }
    if (out.isNotEmpty) {
      out.add(const SizedBox(height: 4));
    }
    return out;
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      drawer: AppDrawer(
          loggedInUsername: storage.DataCache.getUsername()!,
          loggedInURL: storage.DataCache.getInstituteUrl()!.replaceAll(RegExp(r'/hallgato/MobileService\.svc'), '').replaceAll("https://", '')
      ),
      body: SafeArea(
        child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              topnav.TopNavigatorWidget(homePage: homePage, displayString: AppStrings.getLanguagePack().view_header_Calendar, smallHintText: greetText, loggedInUsername: storage.DataCache.getUsername()!, loggedInURL: storage.DataCache.getInstituteUrl()!.replaceAll(RegExp(r'/hallgato/MobileService\.svc'), '').replaceAll("https://", '')),
              homePage.buildCacheHonestyBanner(),
              homePage.buildWhatsChangedBanner(),
              ..._extraCalendarSections(),
              Container(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 6),
                color: AppColors.getTheme().rootBackground,
                width: MediaQuery.of(context).size.width,
                child: TabBar(
                  tabs: calendarTabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerColor: Colors.transparent,
                  automaticIndicatorColorAdjustment: true,
                  controller: homePage.calendarTabController,
                  enableFeedback: true,
                  physics: const BouncingScrollPhysics(
                    decelerationRate: ScrollDecelerationRate.fast,
                  ),
                  indicator: BoxDecoration(
                    color: AppColors.getTheme().textColor.withValues(alpha: .1),
                    borderRadius: const BorderRadius.all(Radius.circular(26))
                  ),
                  onTap: (index){
                    return;
                  },
                ),
              ),
              HomePageState.getSeparatorLine(context),
              Container(
                width: MediaQuery.of(context).size.width,
                child: t_table.WeekoffseterElementWidget(
                  week: homePage.weeksSinceStart,
                  from: homePage.calendarEntries.isEmpty ? null : DateTime.fromMillisecondsSinceEpoch(homePage.calendarEntries[0].startEpoch),
                  to: homePage.calendarEntries.isEmpty ? DateTime.now() : DateTime.fromMillisecondsSinceEpoch(homePage.calendarEntries[homePage.calendarEntries.length - 1].endEpoch),
                  onBackPressed: homePage.stepCalendarBack,
                  onForwardPressed: homePage.stepCalendarForward,
                  canDoPaging: homePage.canDoCalendarPaging,
                  homePage: homePage,
                  isLoading: homePage.isLoadingCalendar,
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: homePage.calendarTabController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: calendarTabViews,
                ),
              ),
              HomePageState.getSeparatorLine(context),
              bottomnav.BottomNavigatorWidget(homePage: homePage),
            ],
          ),
          ],
        ),
      ),
    );
  }
}

class MarkbookPageWidget extends StatelessWidget{
  final HomePageState homePage;
  final int totalCredits;
  final double totalAvg;
  final double totalAvg30;
  const MarkbookPageWidget({super.key, required this.homePage, required this.totalCredits, required this.totalAvg, required this.totalAvg30});

  Future<void> onRefresh() async{
    AppHaptics.lightImpact();
    homePage._confettiRefreshRetrigger = true;
    homePage.onMarkbookRefresh();
  }

  List<Widget> _getConfetti(BuildContext context){
    if(homePage._confettiList.isNotEmpty){
      return homePage._confettiList;
    }
    final confettiAmount = 55 + Random().nextInt(234243) % 30;
    for(int i = 0; i < confettiAmount; i++){
      final randomRed = 0xCC000000 + Random().nextInt(0x33000000);
      final randomGreen = 0x00CC0000 + Random().nextInt(0x0033000);
      final randomBlue = 0x0000CC00 + Random().nextInt(0x00003300);
      final alpha = 0x000000FF;
      final added = randomRed + randomBlue + randomGreen + alpha;
      final confetti = ConfettiHelper(
        confettiColor: Color(added),
        startOffset: Offset(lerpDouble(0, MediaQuery.of(context).size.width, Random().nextDouble() % 0.9999)!, lerpDouble(-MediaQuery.of(context).size.height, -50, Random().nextDouble() % 0.9999)!),
        startRotation: Random().nextDouble() % 360.0,
        rotationMultiplier: -60 + Random().nextInt(60*2),
        startSize: Size((8 + Random().nextInt(12)).toDouble(), (8 + Random().nextInt(12)).toDouble()),
        offsetMultiplier: -200 + Random().nextInt(200*2),
        startRadius: BorderRadius.only(topLeft: Radius.circular(4 + 12 * Random().nextDouble() % 0.999), topRight: Radius.circular(4 + 12 * Random().nextDouble() % 0.999), bottomRight: Radius.circular(4 + 12 * Random().nextDouble() % 0.999), bottomLeft: Radius.circular(4 + 12 * Random().nextDouble() % 0.999))
      );
      homePage._confettiHelperList.add(confetti);
      homePage._confettiList.add(
        IgnorePointer(
          child: AnimatedBuilder(
            animation: homePage._confettiController,
            builder: (context, _) {
              return Transform.translate(
                offset: Offset(
                    confetti.startOffset.dx + confetti.offsetMultiplier * homePage._confettiAnimation.value,
                    lerpDouble(confetti.startOffset.dy, confetti.startOffset.dy + MediaQuery.of(context).size.height * 2 + (confetti.offsetMultiplier < 0 ? -confetti.offsetMultiplier : confetti.offsetMultiplier) * 6 * homePage._confettiAnimation.value, homePage._confettiAnimation.value)!
                ),
                child: Transform.rotate(
                  angle: confetti.startRotation + confetti.rotationMultiplier * homePage._confettiAnimation.value,
                  child: Container(
                    decoration: BoxDecoration(
                      color: confetti.confettiColor,
                      borderRadius: confetti.startRadius
                    ),
                    width: confetti.startSize.width,
                    height: confetti.startSize.height,
                  ),
                ),
              );
            }
          ),
        )
      );
    }
    return homePage._confettiList;
  }

  @override
  Widget build(BuildContext context){
    if(homePage._confettiCanBePlayed && homePage._confettiCanGetFreshAnim && homePage._confettiRefreshRetrigger){
      homePage._confettiCanGetFreshAnim = false;
      homePage._confettiRefreshRetrigger = false;
      homePage._confettiController.forward().whenComplete((){
        homePage._confettiCanGetFreshAnim = true;
        homePage._confettiList.clear();
        homePage._confettiHelperList.clear();
        homePage._confettiController.reset();
      });
    }
    return Scaffold(
      drawer: AppDrawer(
          loggedInUsername: storage.DataCache.getUsername()!,
          loggedInURL: storage.DataCache.getInstituteUrl()!.replaceAll(RegExp(r'/hallgato/MobileService\.svc'), '').replaceAll("https://", '')
      ),
      body: SafeArea(
        child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              topnav.TopNavigatorWidget(
                homePage: homePage,
                displayString: AppStrings.getLanguagePack().view_header_Subjects,
                smallHintText: AppStrings.getStringWithParams(
                  AppStrings.getLanguagePack().topheader_subjects_CreditsHeader,
                  [totalCredits, homePage.accumulatedCredits],
                ),
                loggedInUsername: storage.DataCache.getUsername()!,
                loggedInURL: storage.DataCache.getInstituteUrl()!.replaceAll(RegExp(r'/hallgato/MobileService\.svc'), '').replaceAll("https://", ''),
              ),
              homePage.buildCacheHonestyBanner(),
              HomePageState.getSeparatorLine(context),
              Expanded(
                  child: RefreshIndicator(
                    onRefresh: onRefresh,
                    child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        scrollDirection: Axis.vertical,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Visibility(
                              visible: homePage.markbookList.isNotEmpty,
                              child: Container(
                                margin: const EdgeInsets.only(top: 10, left: 10, right: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 12),
                                width: MediaQuery.of(context).size.width,
                                decoration: BoxDecoration(
                                  color: AppColors.getTheme().textColor.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(20),
                                  //border: Border.all(color: Colors.white.withOpacity(.2), width: 1)
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    EmojiRichText(
                                      text: AppStrings.getStringWithParams(AppStrings.getLanguagePack().markbookPage_AverageDisplay, [totalAvg.isNaN || totalAvg <= 0 ? AppStrings.getLanguagePack().markbookPage_NoGrades : totalAvg.toStringAsFixed(2), api.Generic.reactionForAvg(totalAvg)]),
                                      defaultStyle: TextStyle(
                                        color: AppColors.getTheme().onPrimaryContainer,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13.0,
                                      ),
                                      emojiStyle: TextStyle(
                                          color: AppColors.getTheme().onPrimaryContainer,
                                          fontSize: 14.0,
                                          fontFamily: "Noto Color Emoji"
                                      ),
                                    ),
                                    EmojiRichText(
                                      text: AppStrings.getStringWithParams(AppStrings.getLanguagePack().markbookPage_AverageScholarshipDisplay, [totalAvg30.isNaN || totalAvg30 <= 0 ? AppStrings.getLanguagePack().markbookPage_NoGrades : totalAvg30.toStringAsFixed(2), api.Generic.reactionForAvg(totalAvg30)]),
                                      defaultStyle: TextStyle(
                                        color: AppColors.getTheme().onPrimaryContainer,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13.0,
                                      ),
                                      emojiStyle: TextStyle(
                                          color: AppColors.getTheme().onPrimaryContainer,
                                          fontSize: 14.0,
                                          fontFamily: "Noto Color Emoji"
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        AppStrings.getLanguagePack().markbookPage_AppComputedNote,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: AppColors.getTheme().onPrimaryContainer.withValues(alpha: 0.55),
                                          fontWeight: FontWeight.w500,
                                          fontSize: 10.0,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            FutureBuilder<List<api.Subject>>(
                              future: api.MarkbookRequest.getRegisteredCourses(),
                              builder: (context, snap) {
                                final courses = snap.data ?? const <api.Subject>[];
                                if (courses.isEmpty) return const SizedBox.shrink();
                                final lang = AppStrings.getLanguagePack();
                                return Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.fromLTRB(15, 10, 15, 0),
                                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.getTheme().textColor.withValues(alpha: 0.03),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(lang.markbook_myCourses_Header, style: TextStyle(color: AppColors.getTheme().secondary, fontWeight: FontWeight.w800, fontSize: 12)),
                                      const SizedBox(height: 6),
                                      ...courses.take(12).map((c) => Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 3),
                                        child: Text(
                                          c.subjectCode.isNotEmpty && c.subjectCode != c.name
                                              ? '${c.subjectCode} · ${c.name} (${c.credit} ${lang.markbook_creditAbbrev})'
                                              : '${c.name} (${c.credit} ${lang.markbook_creditAbbrev})',
                                          style: TextStyle(color: AppColors.getTheme().textColor, fontSize: 13, fontWeight: FontWeight.w600),
                                        ),
                                      )),
                                    ],
                                  ),
                                );
                              },
                            ),
                            FutureBuilder<List<({String termName, api.Subject subject})>>(
                              future: api.MarkbookRequest.getGradeHistoryAcrossTerms(maxTerms: 6),
                              builder: (context, snap) {
                                final hist = snap.data ?? const [];
                                if (hist.isEmpty) return const SizedBox.shrink();
                                final lang = AppStrings.getLanguagePack();
                                return Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.fromLTRB(15, 10, 15, 0),
                                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.getTheme().textColor.withValues(alpha: 0.03),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(lang.markbook_gradeHistory_Header, style: TextStyle(color: AppColors.getTheme().secondary, fontWeight: FontWeight.w800, fontSize: 12)),
                                      const SizedBox(height: 6),
                                      ...hist.take(20).map((h) => Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 3),
                                        child: Text(
                                          '${h.termName}: ${h.subject.name}${h.subject.grade > 0 ? ' · ${h.subject.grade}' : ''}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: AppColors.getTheme().textColor, fontSize: 13, fontWeight: FontWeight.w600),
                                        ),
                                      )),
                                    ],
                                  ),
                                );
                              },
                            ),
                            Container(
                              margin: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: homePage.markbookList.isNotEmpty ? AppColors.getTheme().textColor.withValues(alpha: 0.03) : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                mainAxisSize: MainAxisSize.max,
                                children: homePage.markbookList.isNotEmpty ? homePage.markbookList : <Widget>[
                                  Center(
                                    child: SizedBox(
                                      height: MediaQuery.of(context).size.width < MediaQuery.of(context).size.height ? MediaQuery.of(context).size.width * 0.10 : MediaQuery.of(context).size.height * 0.10,
                                      width: MediaQuery.of(context).size.width < MediaQuery.of(context).size.height ? MediaQuery.of(context).size.width * 0.10 : MediaQuery.of(context).size.height * 0.10,
                                      child: CircularProgressIndicator(
                                      color: AppColors.getTheme().textColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    api.Generic.randomLoadingComment(storage.DataCache.getNeedFamilyFriendlyComments()!),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: AppColors.getTheme().textColor.withValues(alpha: .2),
                                        fontWeight: FontWeight.w300,
                                        fontSize: 10
                                    ),
                                  )
                                ]
                              ),
                            ),
                          ],
                        ),
                    )
                  )
              ),
              HomePageState.getSeparatorLine(context),
              bottomnav.BottomNavigatorWidget(homePage: homePage),
            ],
          ),
          Stack(
            children: _getConfetti(context),
          )
        ],
      ),
      ),
    );
  }
}

class ConfettiHelper{
  final Color confettiColor;
  final Offset startOffset;
  final double startRotation;
  final int rotationMultiplier;
  final Size startSize;
  final int offsetMultiplier;
  final BorderRadius startRadius;

  const ConfettiHelper({required this.startRadius, required this.confettiColor, required this.startOffset, required this.startRotation, required this.rotationMultiplier, required this.startSize, required this.offsetMultiplier});
}

class PaymentsPageWidget extends StatelessWidget{
  final HomePageState homePage;
  final int totalMoney;
  const PaymentsPageWidget({super.key, required this.homePage, required this.totalMoney});

  Future<void> onRefresh() async{
    AppHaptics.lightImpact();
    homePage.onPaymentsRefresh();
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
        drawer: AppDrawer(
            loggedInUsername: storage.DataCache.getUsername()!,
            loggedInURL: storage.DataCache.getInstituteUrl()!.replaceAll(RegExp(r'/hallgato/MobileService\.svc'), '').replaceAll("https://", '')
        ),
      body: SafeArea(
        child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              topnav.TopNavigatorWidget(homePage: homePage, displayString: AppStrings.getLanguagePack().view_header_Payments, smallHintText: AppStrings.getStringWithParams(AppStrings.getLanguagePack().topheader_payments_TotalMoneySpent, [totalMoney]), loggedInUsername: storage.DataCache.getUsername()!, loggedInURL: storage.DataCache.getInstituteUrl()!.replaceAll(RegExp(r'/hallgato/MobileService\.svc'), '').replaceAll("https://", '')),
              homePage.buildCacheHonestyBanner(),
              HomePageState.getSeparatorLine(context),
              Expanded(
                  child: RefreshIndicator(
                      onRefresh: onRefresh,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        scrollDirection: Axis.vertical,
                        child: Container(
                          margin: const EdgeInsets.all(15),
                          width: MediaQuery.of(context).size.width,
                          decoration: BoxDecoration(
                            color: homePage.paymentsList.isNotEmpty ? AppColors.getTheme().textColor.withValues(alpha: 0.03) : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              mainAxisSize: MainAxisSize.max,
                              children: homePage.paymentsList.isNotEmpty ? homePage.paymentsList : <Widget>[
                                Center(
                                  child: SizedBox(
                                    height: MediaQuery.of(context).size.width < MediaQuery.of(context).size.height ? MediaQuery.of(context).size.width * 0.10 : MediaQuery.of(context).size.height * 0.10,
                                    width: MediaQuery.of(context).size.width < MediaQuery.of(context).size.height ? MediaQuery.of(context).size.width * 0.10 : MediaQuery.of(context).size.height * 0.10,
                                    child: CircularProgressIndicator(
                                      color: AppColors.getTheme().textColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  api.Generic.randomLoadingComment(storage.DataCache.getNeedFamilyFriendlyComments()!),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: AppColors.getTheme().textColor.withValues(alpha: .2),
                                      fontWeight: FontWeight.w300,
                                      fontSize: 10
                                  ),
                                )
                              ]
                          ),
                        ),
                      )
                  )
              ),
              HomePageState.getSeparatorLine(context),
              bottomnav.BottomNavigatorWidget(homePage: homePage),
            ],
          ),
        ],
      ),
    )
    );
  }
}

class PeriodsPageWidget extends StatelessWidget{
  final HomePageState homePage;
  final int currentSemester;
  const PeriodsPageWidget({super.key, required this.homePage, required this.currentSemester});

  Future<void> onRefresh() async{
    AppHaptics.lightImpact();
    homePage.onPeriodsRefresh();
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
        drawer: AppDrawer(
            loggedInUsername: storage.DataCache.getUsername()!,
            loggedInURL: storage.DataCache.getInstituteUrl()!.replaceAll(RegExp(r'/hallgato/MobileService\.svc'), '').replaceAll("https://", '')
        ),
        body: SafeArea(
          child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                topnav.TopNavigatorWidget(homePage: homePage, displayString: AppStrings.getLanguagePack().view_header_Periods, smallHintText: AppStrings.getStringWithParams(AppStrings.getLanguagePack().topheader_periods_MainHeader, [homePage.countActivePeriods, AppStrings.getLanguagePack().topheader_periods_ActiveText, homePage.countFuturePeriods, AppStrings.getLanguagePack().topheader_periods_FutureText, homePage.countExpiredPeriods, AppStrings.getLanguagePack().topheader_periods_ExpiredText]), loggedInUsername: storage.DataCache.getUsername()!, loggedInURL: storage.DataCache.getInstituteUrl()!.replaceAll(RegExp(r'/hallgato/MobileService\.svc'), '').replaceAll("https://", '')),
                homePage.buildCacheHonestyBanner(),
                HomePageState.getSeparatorLine(context),
                Expanded(
                    child: RefreshIndicator(
                        onRefresh: onRefresh,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          scrollDirection: Axis.vertical,
                          child: Container(
                            margin: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: homePage.periodList.isNotEmpty ? AppColors.getTheme().textColor.withValues(alpha: .03) : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                mainAxisSize: MainAxisSize.max,
                                children: homePage.periodList.isNotEmpty ? homePage.periodList : <Widget>[
                                  Center(
                                    child: SizedBox(
                                      height: MediaQuery.of(context).size.width < MediaQuery.of(context).size.height ? MediaQuery.of(context).size.width * 0.10 : MediaQuery.of(context).size.height * 0.10,
                                      width: MediaQuery.of(context).size.width < MediaQuery.of(context).size.height ? MediaQuery.of(context).size.width * 0.10 : MediaQuery.of(context).size.height * 0.10,
                                      child: CircularProgressIndicator(
                                        color: AppColors.getTheme().textColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    api.Generic.randomLoadingComment(storage.DataCache.getNeedFamilyFriendlyComments()!),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: AppColors.getTheme().textColor.withValues(alpha: .2),
                                        fontWeight: FontWeight.w300,
                                        fontSize: 10
                                    ),
                                  )
                                ]
                            ),
                          ),
                        )
                    )
                ),
                HomePageState.getSeparatorLine(context),
                bottomnav.BottomNavigatorWidget(homePage: homePage),
              ],
            ),
          ],
        ),
        ),
        floatingActionButton: null
    );
  }
}

class MailsPageWidget extends StatelessWidget{
  final HomePageState homePage;
  const MailsPageWidget({super.key, required this.homePage});

  Future<void> onRefresh() async{
    AppHaptics.lightImpact();
    homePage.onMailRefresh();
  }

  Widget _mailToolbar(BuildContext context) {
    final theme = AppColors.getTheme();
    final lang = AppStrings.getLanguagePack();
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 8, 15, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: homePage.mailSearchController,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.search,
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              prefixIcon: Icon(Icons.search_rounded, color: theme.textColor.withValues(alpha: 0.55)),
              suffixIcon: homePage.mailSearchQuery.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(Icons.clear_rounded, color: theme.textColor.withValues(alpha: 0.55)),
                      onPressed: () {
                        homePage.mailSearchController.clear();
                        homePage.setMailSearchQuery('');
                      },
                    ),
              labelText: lang.mail_search_Hint,
              labelStyle: TextStyle(
                fontSize: 14,
                color: theme.textColor.withValues(alpha: 0.55),
                fontWeight: FontWeight.w400,
              ),
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: theme.textColor.withValues(alpha: 0.05),
            ),
            style: TextStyle(
              fontSize: 15,
              color: theme.textColor,
              fontWeight: FontWeight.w600,
            ),
            onChanged: (value) {
              AppHaptics.textEditingImpact();
              homePage.setMailSearchQuery(value);
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilterChip(
              selected: homePage.mailUnreadOnly,
              showCheckmark: false,
              avatar: Icon(
                homePage.mailUnreadOnly ? Icons.mark_email_unread_rounded : Icons.mail_outline_rounded,
                size: 18,
                color: homePage.mailUnreadOnly ? theme.primary : theme.textColor.withValues(alpha: 0.7),
              ),
              label: Text(lang.mail_filter_UnreadOnly),
              labelStyle: TextStyle(
                color: homePage.mailUnreadOnly ? theme.primary : theme.textColor,
                fontWeight: homePage.mailUnreadOnly ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
              selectedColor: theme.primary.withValues(alpha: 0.18),
              backgroundColor: theme.textColor.withValues(alpha: 0.05),
              side: BorderSide(
                color: homePage.mailUnreadOnly
                    ? theme.primary.withValues(alpha: 0.45)
                    : theme.textColor.withValues(alpha: 0.12),
              ),
              onSelected: (selected) {
                AppHaptics.lightImpact();
                homePage.setMailUnreadOnly(selected);
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        drawer: AppDrawer(
            loggedInUsername: storage.DataCache.getUsername()!,
            loggedInURL: storage.DataCache.getInstituteUrl()!.replaceAll(RegExp(r'/hallgato/MobileService\.svc'), '').replaceAll("https://", '')
        ),
        body: SafeArea(
          child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                topnav.TopNavigatorWidget(homePage: homePage, displayString: AppStrings.getLanguagePack().view_header_Messages, smallHintText: AppStrings.getStringWithParams(AppStrings.getLanguagePack().topheader_messages_UnreadMessages, [homePage.unreadMailCount]), loggedInUsername: storage.DataCache.getUsername()!, loggedInURL: storage.DataCache.getInstituteUrl()!.replaceAll(RegExp(r'/hallgato/MobileService\.svc'), '').replaceAll("https://", '')),
                homePage.buildCacheHonestyBanner(),
                HomePageState.getSeparatorLine(context),
                _mailToolbar(context),
                Expanded(
                    child: RefreshIndicator(
                        onRefresh: onRefresh,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          scrollDirection: Axis.vertical,
                          controller: homePage.currentMailPageController,
                          child: Container(
                            margin: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: homePage.mailList.isNotEmpty ? AppColors.getTheme().textColor.withValues(alpha: 0.03) : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                mainAxisSize: MainAxisSize.max,
                                children: homePage.mailList.isNotEmpty ? homePage.mailList : <Widget>[
                                  Center(
                                    child: SizedBox(
                                      height: MediaQuery.of(context).size.width < MediaQuery.of(context).size.height ? MediaQuery.of(context).size.width * 0.10 : MediaQuery.of(context).size.height * 0.10,
                                      width: MediaQuery.of(context).size.width < MediaQuery.of(context).size.height ? MediaQuery.of(context).size.width * 0.10 : MediaQuery.of(context).size.height * 0.10,
                                      child: CircularProgressIndicator(
                                        color: AppColors.getTheme().textColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    api.Generic.randomLoadingComment(storage.DataCache.getNeedFamilyFriendlyComments()!),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: AppColors.getTheme().textColor.withValues(alpha: .2),
                                        fontWeight: FontWeight.w300,
                                        fontSize: 10
                                    ),
                                  )
                                ]
                            ),
                          ),
                        )
                    )
                ),
                HomePageState.getSeparatorLine(context),
                bottomnav.BottomNavigatorWidget(homePage: homePage),
              ],
            ),
          ],
        ),
        )
    );
  }
}