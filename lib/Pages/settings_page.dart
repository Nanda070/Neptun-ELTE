import 'dart:io';
import 'package:flutter/material.dart';
import 'package:neptun2/Pages/main_page.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../API/api_coms.dart';
import '../colors.dart';
import '../haptics.dart';
import '../language.dart';
import '../storage.dart';
import '../Misc/emojirich_text.dart';
import '../Pages/startup_page.dart';
import '../Misc/auto_updater.dart';
import '../Pages/student_card_page.dart';


class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late String _languageCurrSelect;
  late String _themesCurrSelect;
  late double _currentFontScale;
  List<LangPackMap> _availableLanguages = Language.getAllLanguagesWithNative();
  String _appVersionLabel = '';

  @override
  void initState() {
    super.initState();

    // loading defaults
    _currentFontScale = DataCache.getFontScale();
    final preferred = DataCache.getPreferredAppTheme() ?? 'Dark';
    _themesCurrSelect = AppColors.getSelectableThemeNames().contains(preferred)
        ? preferred
        : (AppColors.getSelectableThemeNames().contains(AppColors.getTheme().paletteName)
            ? AppColors.getTheme().paletteName
            : 'Dark');

    _initLanguageSelection();
    _loadOnlineLanguages();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        // User-facing marketing version only (1.x.y) — do not show +build.
        _appVersionLabel = info.version;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _appVersionLabel = '1.5.4';
      });
    }
  }

  void _showContactsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.getTheme().rootBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        Widget contactTile(IconData icon, String label, String url) {
          return ListTile(
            leading: Icon(icon, color: AppColors.getTheme().textColor),
            title: Text(label, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
            onTap: () {
              AppHaptics.lightImpact();
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            },
          );
        }
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              contactTile(Icons.code_rounded, 'GitHub: Nanda070', 'https://github.com/Nanda070'),
              contactTile(Icons.chat_rounded, 'Discord: nandak070', 'https://discord.com/users/nandak070'),
              contactTile(Icons.send_rounded, 'Telegram: nanda070', 'https://t.me/nanda070'),
              contactTile(Icons.email_rounded, 'Email', 'mailto:adnan.huseynli1@gmail.com'),
              contactTile(Icons.language_rounded, 'nanda.is-a.dev', 'https://nanda.is-a.dev/'),
              contactTile(Icons.language_rounded, 'cheterin.online', 'https://cheterin.online'),
              contactTile(Icons.language_rounded, 'chetmedia.com', 'https://chetmedia.com'),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _initLanguageSelection() {
    final selectedCode = DataCache.getUserSelectedLanguageCode();
    final selectedIdx = DataCache.getUserSelectedLanguage() ?? -1;
    final allCodes = _availableLanguages.map((l) => l.langId).toList();

    int targetIdx = -1;
    if (selectedCode != null && selectedCode.isNotEmpty) {
      targetIdx = allCodes.indexOf(selectedCode);
    }
    if (targetIdx == -1 && selectedIdx >= 0 && selectedIdx < _availableLanguages.length) {
      targetIdx = selectedIdx;
    }
    if (targetIdx == -1) {
      final deviceCode = Platform.localeName.split('_')[0].toLowerCase();
      targetIdx = allCodes.indexOf(deviceCode);
    }
    if (targetIdx == -1) {
      targetIdx = 0;
    }

    final targetLang = _availableLanguages[targetIdx];
    _languageCurrSelect = "${targetLang.langFlag} ${targetLang.langName}";
  }

  Future<void> _loadOnlineLanguages() async {
    if (DataCache.getHasNetwork()) {
      final onlineLangs = await Language.getAllLanguages();
      if (onlineLangs != null && mounted) {
        setState(() {
          _availableLanguages = Language.getAllLanguagesWithNative();
          _initLanguageSelection();
        });
      }
    }
  }

  // header helpers
  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.getTheme().secondary, size: 20),
          const SizedBox(width: 10),
          Text(
            title.toUpperCase(),
            style: TextStyle(
                color: AppColors.getTheme().secondary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1.2
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getTheme().rootBackground,
      appBar: AppBar(
        backgroundColor: AppColors.getTheme().rootBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.getTheme().textColor),
          onPressed: () {
            AppHaptics.lightImpact();
            Navigator.pop(context);
          },
        ),
        title: Text(
          stripLeadingEmoji(AppStrings.getLanguagePack().topmenu_buttons_Settings),
          style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          // --- 1. appearance and language ---
          _buildSectionHeader(AppStrings.getLanguagePack().settings_section_AppearanceLanguage, Icons.palette_rounded),

          ListTile(
            title: Text(AppStrings.getLanguagePack().popup_case1_settingOption9_ThemeSwap, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
            trailing: Container(
              width: 160,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                  color: AppColors.getTheme().textColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12)
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: AppColors.getSelectableThemeNames().contains(_themesCurrSelect)
                      ? _themesCurrSelect
                      : AppColors.getSelectableThemeNames().first,
                  dropdownColor: AppColors.getTheme().rootBackground,
                  icon: Icon(Icons.arrow_drop_down_rounded, color: AppColors.getTheme().textColor),
                  isExpanded: true,
                  style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600),
                  items: AppColors.getSelectableThemeNames().map((String value) {
                    return DropdownMenuItem<String>(
                        value: value,
                        child: Row(
                          children: [
                            Icon(Icons.circle, color: AppColors.getThemePopupAccentByName(value), size: 16),
                            const SizedBox(width: 10),
                            Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
                          ],
                        )
                    );
                  }).toList(),
                  onChanged: (String? value) {
                    if (value == null) return;
                    AppHaptics.lightImpact();
                    DataCache.setPreferredAppTheme(value);
                    setState(() {
                      _themesCurrSelect = value;
                      AppColors.setUserThemeByName(value, context);
                      AppColors.refreshThemeIndexing();
                    });
                  },
                ),
              ),
            ),
          ),

          ListTile(
            title: Text(AppStrings.getLanguagePack().popup_case1_settingOption8_LangaugeSelection, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
            trailing: Container(
              width: 160,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                  color: AppColors.getTheme().textColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12)
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _availableLanguages.any((l) => "${l.langFlag} ${l.langName}" == _languageCurrSelect)
                      ? _languageCurrSelect
                      : "${_availableLanguages.first.langFlag} ${_availableLanguages.first.langName}",
                  dropdownColor: AppColors.getTheme().rootBackground,
                  icon: Icon(Icons.arrow_drop_down_rounded, color: AppColors.getTheme().textColor),
                  isExpanded: true,
                  items: _availableLanguages.map((LangPackMap item) {
                    final strValue = "${item.langFlag} ${item.langName}";
                    return DropdownMenuItem<String>(
                        value: strValue,
                        child: EmojiRichText(
                          text: strValue,
                          defaultStyle: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600, fontSize: 14),
                          emojiStyle: TextStyle(color: AppColors.getTheme().textColor, fontSize: 18, fontFamily: "Noto Color Emoji"),
                        )
                    );
                  }).toList(),
                  onChanged: (String? value) async {
                    if (value == null) return;
                    AppHaptics.lightImpact();

                    final selected = _availableLanguages.firstWhere(
                      (l) => "${l.langFlag} ${l.langName}" == value,
                      orElse: () => _availableLanguages.first,
                    );

                    if (!AppStrings.hasLanguageDownloaded(selected.langId) && selected.langURL.isNotEmpty) {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => Center(
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.getTheme().rootBackground,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const CircularProgressIndicator(),
                          ),
                        ),
                      );

                      final allLangs = await Language.getAllLanguages();
                      await Language.getLanguagePackById(allLangs, selected.langId);
                      AppStrings.saveDownloadedLanguageData();
                      if (mounted && Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    }

                    final allCodes = AppStrings.getAllLangCodes();
                    final newIdx = allCodes.indexOf(selected.langId);
                    await DataCache.setUserSelectedLanguage(newIdx >= 0 ? newIdx : 0);
                    await DataCache.setUserSelectedLanguageCode(selected.langId);

                    if (mounted) {
                      Navigator.popUntil(context, (route) => route.isFirst);
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const Splitter()));
                    }
                  },
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.getLanguagePack().settings_section_FontScale, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600, fontSize: 16)),
                Slider(
                  value: _currentFontScale,
                  min: 0.8,
                  max: 1.4,
                  divisions: 6,
                  label: "${(_currentFontScale * 100).toInt()}%",
                  activeColor: AppColors.getTheme().secondary,
                  inactiveColor: AppColors.getTheme().textColor.withValues(alpha: 0.1),
                  onChanged: (val) {
                    setState(() { _currentFontScale = val; });
                  },
                  onChangeEnd: (val) {
                    AppHaptics.lightImpact();
                    DataCache.setFontScale(val);
                    // ui update!
                    setState((){});
                  },
                ),
              ],
            ),
          ),

          // --- 2. notifications ---
          _buildSectionHeader(AppStrings.getLanguagePack().settings_section_Notifications, Icons.notifications_active_rounded),

          SwitchListTile(
            title: Text(AppStrings.getLanguagePack().popup_case1_settingOption2_ExamNotifications, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
            activeThumbColor: AppColors.getTheme().secondary,
            value: DataCache.getNeedExamNotifications()!,
            onChanged: (b) {
              AppHaptics.lightImpact();
              DataCache.setNeedExamNotifications(b ? 1 : 0);
              b ? HomePageState.setupExamNotifications() : HomePageState.cancelExamNotifications();
              setState(() {});
            },
          ),
          SwitchListTile(
            title: Text(AppStrings.getLanguagePack().popup_case1_settingOption3_ClassNotifications, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
            activeThumbColor: AppColors.getTheme().secondary,
            value: DataCache.getNeedClassNotifications()!,
            onChanged: (b) {
              AppHaptics.lightImpact();
              DataCache.setNeedClassNotifications(b ? 1 : 0);
              b ? HomePageState.setupClassesNotifications() : HomePageState.cancelClassesNotifications();
              setState(() {});
            },
          ),
          if (DataCache.getNeedClassNotifications()!) ...[
            CheckboxListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 28, right: 16),
              activeColor: AppColors.getTheme().secondary,
              title: Text(AppStrings.getLanguagePack().settings_classNotif_10min, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w500, fontSize: 14)),
              value: DataCache.getClassNotif10() ?? true,
              onChanged: (b) {
                AppHaptics.lightImpact();
                DataCache.setClassNotif10((b ?? true) ? 1 : 0);
                HomePageState.setupClassesNotifications();
                setState(() {});
              },
            ),
            CheckboxListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 28, right: 16),
              activeColor: AppColors.getTheme().secondary,
              title: Text(AppStrings.getLanguagePack().settings_classNotif_5min, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w500, fontSize: 14)),
              value: DataCache.getClassNotif5() ?? true,
              onChanged: (b) {
                AppHaptics.lightImpact();
                DataCache.setClassNotif5((b ?? true) ? 1 : 0);
                HomePageState.setupClassesNotifications();
                setState(() {});
              },
            ),
            CheckboxListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 28, right: 16),
              activeColor: AppColors.getTheme().secondary,
              title: Text(AppStrings.getLanguagePack().settings_classNotif_atStart, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w500, fontSize: 14)),
              value: DataCache.getClassNotif0() ?? true,
              onChanged: (b) {
                AppHaptics.lightImpact();
                DataCache.setClassNotif0((b ?? true) ? 1 : 0);
                HomePageState.setupClassesNotifications();
                setState(() {});
              },
            ),
          ],
          SwitchListTile(
            title: Text(AppStrings.getLanguagePack().popup_case1_settingOption4_PaymentNotifications, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
            activeThumbColor: AppColors.getTheme().secondary,
            value: DataCache.getNeedPaymentsNotifications()!,
            onChanged: (b) {
              AppHaptics.lightImpact();
              DataCache.setNeedPaymentsNotifications(b ? 1 : 0);
              b ? HomePageState.setupPaymentsNotifications() : HomePageState.cancelPaymentsNotifications();
              setState(() {});
            },
          ),
          SwitchListTile(
            title: Text(AppStrings.getLanguagePack().popup_case1_settingOption5_PeriodsNotifications, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
            activeThumbColor: AppColors.getTheme().secondary,
            value: DataCache.getNeedPeriodsNotifications()!,
            onChanged: (b) {
              AppHaptics.lightImpact();
              DataCache.setNeedPeriodsNotifications(b ? 1 : 0);
              b ? HomePageState.setupPeriodsNotifications() : HomePageState.cancelPeriodsNotifications();
              setState(() {});
            },
          ),

          // --- Calendar display filters (API GetCalendarEvents flags) ---
          _buildSectionHeader(AppStrings.getLanguagePack().settings_section_CalendarFilters, Icons.filter_alt_rounded),
          SwitchListTile(
            title: Text(AppStrings.getLanguagePack().settings_calendar_ShowClasses, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
            activeThumbColor: AppColors.getTheme().secondary,
            value: DataCache.getDisplayClasses() ?? true,
            onChanged: (b) async {
              AppHaptics.lightImpact();
              await DataCache.setDisplayClasses(b);
              await DataCache.setHasCachedCalendar(0);
              HomePageState.onSemesterChanged();
              setState(() {});
            },
          ),
          SwitchListTile(
            title: Text(AppStrings.getLanguagePack().settings_calendar_ShowExams, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
            activeThumbColor: AppColors.getTheme().secondary,
            value: DataCache.getDisplayExams() ?? true,
            onChanged: (b) async {
              AppHaptics.lightImpact();
              await DataCache.setDisplayExams(b);
              await DataCache.setHasCachedCalendar(0);
              HomePageState.onSemesterChanged();
              setState(() {});
            },
          ),
          SwitchListTile(
            title: Text(AppStrings.getLanguagePack().settings_calendar_ShowPeriods, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
            activeThumbColor: AppColors.getTheme().secondary,
            value: DataCache.getDisplayPeriods() ?? true,
            onChanged: (b) async {
              AppHaptics.lightImpact();
              await DataCache.setDisplayPeriods(b);
              await DataCache.setHasCachedCalendar(0);
              HomePageState.onSemesterChanged();
              setState(() {});
            },
          ),

          // --- 3. operation and others ---
          _buildSectionHeader(AppStrings.getLanguagePack().settings_section_BehaviorOther, Icons.build_circle_rounded),

          SwitchListTile(
            title: Text(AppStrings.getLanguagePack().popup_case1_settingOption1_FamilyFriendlyLoadingText, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
            activeThumbColor: AppColors.getTheme().secondary,
            value: DataCache.getNeedFamilyFriendlyComments()!,
            onChanged: (b) {
              AppHaptics.lightImpact();
              DataCache.setNeedFamilyFriendlyComments(b ? 1 : 0);
              setState(() {});
            },
          ),
          SwitchListTile(
            title: Text(AppStrings.getLanguagePack().popup_case1_settingOption6_AppHaptics, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
            activeThumbColor: AppColors.getTheme().secondary,
            value: DataCache.getNeedsHaptics()!,
            onChanged: (b) {
              AppHaptics.lightImpact();
              DataCache.setNeedsHaptics(b ? 1 : 0);
              setState(() {});
            },
          ),

          ListTile(
            title: Text(AppStrings.getLanguagePack().popup_case1_settingOption7_WeekOffset, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
            trailing: Container(
              width: 120,
              decoration: BoxDecoration(color: AppColors.getTheme().textColor.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
              child: Row(
                 children: [
                   IconButton(
                     icon: Icon(Icons.remove, color: AppColors.getTheme().textColor, size: 18),
                     onPressed: () { AppHaptics.lightImpact(); HomePageState.settingsUserWeekOffsetAdd(-1); setState((){}); },
                   ),
                   Expanded(
                     child: Text(HomePageState.getUserWeekOffsetTextController().text.isEmpty ? AppStrings.getLanguagePack().popup_case1_settingOption7_WeekOffsetAuto : HomePageState.getUserWeekOffsetTextController().text, textAlign: TextAlign.center, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.bold)),
                   ),
                   IconButton(
                     icon: Icon(Icons.add, color: AppColors.getTheme().textColor, size: 18),
                     onPressed: () { AppHaptics.lightImpact(); HomePageState.settingsUserWeekOffsetAdd(1); setState((){}); },
                   ),
                 ],
              ),
            ),
          ),
          if (Platform.isAndroid)
            ListTile(
              leading: Icon(Icons.system_update_rounded, color: AppColors.getTheme().textColor),
              title: Text(AppStrings.getLanguagePack().popup_case7_ButtonUpdateNow, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
              trailing: Icon(Icons.chevron_right_rounded, color: AppColors.getTheme().textColor.withValues(alpha: 0.4)),
              onTap: () {
                AppHaptics.lightImpact();
                AppUpdater.checkAndInstallUpdate(context, force: true);
              },
            ),

          // --- Contacts + app version (bottom of Settings) ---
          ListTile(
            leading: Icon(Icons.badge_outlined, color: AppColors.getTheme().textColor),
            title: Text(AppStrings.getLanguagePack().studentCard_Title, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
            trailing: Icon(Icons.chevron_right_rounded, color: AppColors.getTheme().textColor.withValues(alpha: 0.4)),
            onTap: () {
              AppHaptics.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StudentCardPage()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.link_rounded, color: AppColors.getTheme().textColor),
            title: Text(AppStrings.getLanguagePack().topmenu_buttons_Contacts, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
            trailing: Icon(Icons.chevron_right_rounded, color: AppColors.getTheme().textColor.withValues(alpha: 0.4)),
            onTap: () {
              AppHaptics.lightImpact();
              _showContactsSheet();
            },
          ),
          if (_appVersionLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                _appVersionLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.getTheme().textColor.withValues(alpha: 0.45),
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}