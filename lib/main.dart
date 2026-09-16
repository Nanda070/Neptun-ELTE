import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:neptun2/app_navigator.dart';
import 'package:neptun2/colors.dart';
import 'package:neptun2/storage.dart';
import 'package:provider/provider.dart';
import 'API/api_coms.dart' as api;
import 'Pages/main_page.dart';
import 'Pages/startup_page.dart';
import 'language.dart';
import 'Misc/hallgato_background_keepalive.dart';

void main() {
  //DataCache.dataWipeNoKeep();
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  HallgatoBackgroundKeepAlive.registerHeadlessEntryPoints();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  DataCache.loadThemeOnly().whenComplete(() async {
    AppColors.initialize();
    await AppStrings.loadBundledLanguagePacks();
    AppStrings.initialize();
    await HallgatoBackgroundKeepAlive.initialize();
    api.SessionGuard.registerAuthWipedHook(
      HallgatoBackgroundKeepAlive.cancelScheduledTasks,
    );
    registerAppRoots(
      loginRoot: (_) => const Splitter(),
      homeRoot: (_) => const HomePage(),
    );
    final app = const NeptunApp();
    final themeNotifier = ThemeNotifier(ThemeNotifier._initialTheme(AppColors.getTheme().basedOnDark));
    runApp(
      ChangeNotifierProvider(
        create: (_) => themeNotifier,
        child: app,
      ),
    );
    WidgetsBinding.instance.addObserver(app);
  });
}

class NeptunApp extends StatelessWidget with WidgetsBindingObserver {
  const NeptunApp({super.key});

  @override
  void didChangePlatformBrightness(){
    // Keep the user-selected Light/Dark theme; do not overwrite preference from system brightness.
    super.didChangePlatformBrightness();
  }

  static bool _themeSetup = false;

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    if(!_themeSetup){
      _themeSetup = true;
      WidgetsBinding.instance.addPostFrameCallback((_)async{
        // Remote theme packs are no longer offered; keep Light/Dark only.
        var userTheme = DataCache.getPreferredAppTheme() ?? 'Dark';
        if (userTheme != 'Light' && userTheme != 'Dark') {
          userTheme = 'Dark';
          await DataCache.setPreferredAppTheme(userTheme);
        }
        if (appNavigatorKey.currentContext != null) {
          AppColors.setUserThemeByName(userTheme, appNavigatorKey.currentContext!);
          AppColors.refreshThemeIndexing();
          AppColors.setCurrentSystemTheme(AppColors.getTheme().basedOnDark);
        }
      });
    }
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Neptun ELTE',
      theme: themeNotifier._themeData,
      home: const Splitter(),
    );
  }
}

class ThemeNotifier extends ChangeNotifier {

  static ThemeNotifier? _instance;

  ThemeData _themeData;
  ThemeNotifier(this._themeData){
    _instance = this;
  }

  static ThemeNotifier? getInstance(){
    return _instance;
  }

  void createNewThemeData(){
    _themeData = _buildTheme(AppColors.isDarktheme());
    notifyListeners();
  }

  ThemeData _buildTheme(bool isDark) {
    return ThemeData(
      colorScheme: isDark ? ColorScheme.dark(
        primary: AppColors.getTheme().primary,
        onPrimary: AppColors.getTheme().onPrimary,
        onPrimaryContainer: AppColors.getTheme().onSecondaryContainer,
        secondary: AppColors.getTheme().secondary,
        onSecondary: AppColors.getTheme().onSecondary,
        onSecondaryContainer: AppColors.getTheme().onSecondaryContainer,
      ) : ColorScheme.light(
        primary: AppColors.getTheme().primary,
        onPrimary: AppColors.getTheme().onPrimary,
        onPrimaryContainer: AppColors.getTheme().onSecondaryContainer,
        secondary: AppColors.getTheme().secondary,
        onSecondary: AppColors.getTheme().onSecondary,
        onSecondaryContainer: AppColors.getTheme().onSecondaryContainer,
      ),
      useMaterial3: true,
    );
  }

  static ThemeData _initialTheme(bool isDark){
    return ThemeData(
      colorScheme: isDark ? ColorScheme.dark(
        primary: AppColors.getTheme().primary,
        onPrimary: AppColors.getTheme().onPrimary,
        onPrimaryContainer: AppColors.getTheme().onSecondaryContainer,
        secondary: AppColors.getTheme().secondary,
        onSecondary: AppColors.getTheme().onSecondary,
        onSecondaryContainer: AppColors.getTheme().onSecondaryContainer,
      ) : ColorScheme.light(
        primary: AppColors.getTheme().primary,
        onPrimary: AppColors.getTheme().onPrimary,
        onPrimaryContainer: AppColors.getTheme().onSecondaryContainer,
        secondary: AppColors.getTheme().secondary,
        onSecondary: AppColors.getTheme().onSecondary,
        onSecondaryContainer: AppColors.getTheme().onSecondaryContainer,
      ),
      useMaterial3: true,
    );
  }
}
