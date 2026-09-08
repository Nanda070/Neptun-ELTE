import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';
import '../API/api_coms.dart';
import '../Pages/main_page.dart';
import '../colors.dart';
import '../haptics.dart';
import '../storage.dart' as storage;
import '../Pages/startup_page.dart' as root_page;
import '../Misc/emojirich_text.dart';
import '../language.dart';
import '../notifications.dart';
import '../Pages/settings_page.dart';

class AppDrawer extends StatefulWidget {
  final String loggedInUsername;
  final String loggedInURL;

  const AppDrawer({super.key, required this.loggedInUsername, required this.loggedInURL});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  List<Term> _terms = [];
  String? _selectedTermId;
  bool _isLoadingTerms = true;
  double? _accountBalance;
  String _accountCurrency = 'HUF';
  bool _isLoadingBalance = true;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _selectedTermId = storage.DataCache.getSelectedTermId();
    _accountBalance = storage.DataCache.getAccountBalance();
    _accountCurrency = storage.DataCache.getAccountBalanceCurrency();
    _unreadCount = storage.DataCache.getUnreadMailCount();
    _isLoadingBalance = _accountBalance == null;
    _loadTerms();
    _loadFinancialAndMessages();
  }

  Future<void> _loadTerms() async {
    final terms = await TermsRequest.getTerms();
    if (mounted) {
      setState(() {
        _terms = terms;
        _selectedTermId = storage.DataCache.getSelectedTermId() ?? (_terms.isNotEmpty ? _terms.last.id : null);
        _isLoadingTerms = false;
      });
    }
  }

  Future<void> _loadFinancialAndMessages() async {
    try {
      final balanceFuture = CashinRequest.getCollectiveInvoiceBalance();
      final unreadFuture = MailRequest.getUnreadMessageCount();
      final results = await Future.wait([balanceFuture, unreadFuture]);
      if (mounted) {
        setState(() {
          _accountBalance = results[0] as double?;
          _accountCurrency = storage.DataCache.getAccountBalanceCurrency();
          _unreadCount = (results[1] as int?) ?? 0;
          _isLoadingBalance = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingBalance = false;
        });
      }
    }
  }

  String _formatBalance(double amount, String currency) {
    int intVal = amount.round();
    String s = intVal.toString();
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String formatted = s.replaceAllMapped(reg, (Match m) => '${m[1]} ');
    String currSymbol = currency == 'HUF' ? 'Ft' : currency;
    return '$formatted $currSymbol';
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.getTheme().rootBackground,
      child: SafeArea( // this solves navbar overlap!
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- header (welcome) ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: AppColors.getTheme().textColor.withValues(alpha: 0.05),
                  border: Border(bottom: BorderSide(color: AppColors.getTheme().textColor.withValues(alpha: 0.1), width: 1))
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.getTheme().currentClassGreen,
                    radius: 30,
                    child: Text(
                      widget.loggedInUsername.isNotEmpty ? widget.loggedInUsername[0].toUpperCase() : '?',
                      style: TextStyle(color: AppColors.getTheme().rootBackground, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 15),
                  EmojiRichText(
                    text: AppStrings.getStringWithParams(AppStrings.getLanguagePack().topmenu_Greet, [widget.loggedInUsername]),
                    defaultStyle: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.bold, fontSize: 18),
                    emojiStyle: TextStyle(color: AppColors.getTheme().textColor, fontSize: 20, fontFamily: "Noto Color Emoji"),
                  ),
                  const SizedBox(height: 5),
                  EmojiRichText(
                    text: AppStrings.getStringWithParams(AppStrings.getLanguagePack().topmenu_LoginPlace, [widget.loggedInURL]),
                    defaultStyle: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: 0.7), fontSize: 13),
                    emojiStyle: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: 0.7), fontSize: 13, fontFamily: "Noto Color Emoji"),
                  ),
                ],
              ),
            ),

            // --- Scrollable middle section ---
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),

                    // --- School Account Balance Card ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            AppHaptics.lightImpact();
                            Navigator.pop(context);
                            HomePageState.navigateToView(2); // Payments view
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.getTheme().textColor.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.getTheme().textColor.withValues(alpha: 0.08)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.getTheme().currentClassGreen.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.account_balance_wallet_rounded, size: 20, color: AppColors.getTheme().currentClassGreen),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        AppStrings.getLanguagePack().topmenu_AccountBalance,
                                        style: TextStyle(
                                          color: AppColors.getTheme().textColor.withValues(alpha: 0.7),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      if (_isLoadingBalance && _accountBalance == null)
                                        SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.getTheme().currentClassGreen),
                                        )
                                      else
                                        Text(
                                          _accountBalance != null
                                              ? _formatBalance(_accountBalance!, _accountCurrency)
                                              : '0 Ft',
                                          style: TextStyle(
                                            color: AppColors.getTheme().textColor,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.getTheme().textColor.withValues(alpha: 0.3)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // --- Unread Messages Card ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            AppHaptics.lightImpact();
                            Navigator.pop(context);
                            HomePageState.navigateToView(4); // Messages view
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: _unreadCount > 0
                                  ? AppColors.getTheme().primary.withValues(alpha: 0.08)
                                  : AppColors.getTheme().textColor.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _unreadCount > 0
                                    ? AppColors.getTheme().primary.withValues(alpha: 0.3)
                                    : AppColors.getTheme().textColor.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _unreadCount > 0
                                        ? AppColors.getTheme().primary.withValues(alpha: 0.2)
                                        : AppColors.getTheme().textColor.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _unreadCount > 0 ? Icons.mark_email_unread_rounded : Icons.mail_outline_rounded,
                                    size: 20,
                                    color: _unreadCount > 0 ? AppColors.getTheme().primary : AppColors.getTheme().textColor.withValues(alpha: 0.7),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        AppStrings.getLanguagePack().topmenu_MessagesTitle,
                                        style: TextStyle(
                                          color: AppColors.getTheme().textColor.withValues(alpha: 0.7),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _unreadCount > 0
                                            ? AppStrings.getStringWithParams(AppStrings.getLanguagePack().topmenu_UnreadMessagesBadge, ['$_unreadCount'])
                                            : AppStrings.getLanguagePack().topmenu_NoUnreadMessages,
                                        style: TextStyle(
                                          color: _unreadCount > 0 ? AppColors.getTheme().primary : AppColors.getTheme().textColor,
                                          fontSize: 14,
                                          fontWeight: _unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_unreadCount > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.getTheme().errorRed,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$_unreadCount',
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  )
                                else
                                  Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.getTheme().textColor.withValues(alpha: 0.3)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 4),

                    // --- Semester Selector ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.getTheme().textColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.getTheme().textColor.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.getTheme().secondary),
                                const SizedBox(width: 8),
                                Text(
                                  AppStrings.getLanguagePack().topmenu_SemesterSelectorTitle.toUpperCase(),
                                  style: TextStyle(
                                    color: AppColors.getTheme().secondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (_isLoadingTerms)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.getTheme().secondary),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      "...",
                                      style: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: 0.6), fontSize: 13),
                                    ),
                                  ],
                                ),
                              )
                            else if (_terms.isEmpty)
                              Text(
                                "-",
                                style: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: 0.6), fontSize: 13),
                              )
                            else
                              DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _terms.any((t) => t.id == _selectedTermId)
                                      ? _selectedTermId
                                      : (_terms.isNotEmpty ? _terms.last.id : null),
                                  dropdownColor: AppColors.getTheme().rootBackground,
                                  icon: Icon(Icons.arrow_drop_down_rounded, color: AppColors.getTheme().textColor),
                                  isExpanded: true,
                                  isDense: true,
                                  style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600, fontSize: 14),
                                  items: _terms.map((Term term) {
                                    return DropdownMenuItem<String>(
                                      value: term.id,
                                      child: Text(
                                        term.termName,
                                        style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600, fontSize: 14),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (String? val) async {
                                    if (val == null || val == _selectedTermId) return;
                                    AppHaptics.lightImpact();
                                    final chosenTerm = _terms.firstWhere(
                                      (t) => t.id == val,
                                      orElse: () => _terms.first,
                                    );
                                    setState(() {
                                      _selectedTermId = val;
                                    });
                                    await storage.DataCache.setSelectedTermId(chosenTerm.id);
                                    await storage.DataCache.setSelectedTermName(chosenTerm.termName);

                                    HomePageState.onSemesterChanged();

                                    if (Platform.isAndroid) {
                                      Fluttertoast.showToast(
                                        msg: AppStrings.getStringWithParams(AppStrings.getLanguagePack().topmenu_SemesterToast, [chosenTerm.termName]),
                                        toastLength: Toast.LENGTH_SHORT,
                                        gravity: ToastGravity.SNACKBAR,
                                        backgroundColor: AppColors.getTheme().rootBackground,
                                        textColor: AppColors.getTheme().textColor,
                                      );
                                    }
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 4),

                    // --- menus ---
                    ListTile(
                      leading: Icon(Icons.settings_rounded, color: AppColors.getTheme().textColor),
                      title: Text(AppStrings.getLanguagePack().topmenu_buttons_Settings, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
                      onTap: () {
                        AppHaptics.lightImpact();
                        Navigator.pop(context); // closes drawer

                        // open new page >> old popup dart
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SettingsPage()),
                        ).then((_) {
                          // check if calendar needs to refresh if closing menu
                          HomePageState.settingsUserWeekOffsetChangeDetect();
                        });
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.favorite_rounded, color: Colors.pinkAccent),
                      title: Text(AppStrings.getLanguagePack().topmenu_buttons_SupportDev, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
                      onTap: () {
                        AppHaptics.lightImpact();
                        Navigator.pop(context);
                        if(Platform.isAndroid){
                          launchUrl(Uri.parse('https://buymeacoffee.com/zoligamer')).whenComplete(() {
                            Fluttertoast.showToast(msg: '❤️', toastLength: Toast.LENGTH_SHORT, gravity: ToastGravity.SNACKBAR, backgroundColor: AppColors.getTheme().rootBackground, textColor: AppColors.getTheme().textColor);
                          });
                        }
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.bug_report_rounded, color: AppColors.getTheme().textColor),
                      title: Text(AppStrings.getLanguagePack().topmenu_buttons_Bugreport, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
                      onTap: () {
                        AppHaptics.lightImpact();
                        Navigator.pop(context);
                        if(Platform.isAndroid){
                          launchUrl(Uri.parse('https://github.com/zoligamer/Neptun-Mobile-fork/issues/new/choose'));
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            // --- bottom (logout) ---
            Divider(color: AppColors.getTheme().textColor.withValues(alpha: 0.1), height: 1),
            ListTile(
              leading: Icon(Icons.logout_rounded, color: AppColors.getTheme().errorRed),
              title: Text(AppStrings.getLanguagePack().topmenu_buttons_Logout, style: TextStyle(color: AppColors.getTheme().errorRed, fontWeight: FontWeight.w700)),
              onTap: () {
                AppHaptics.lightImpact();
                Future.delayed(Duration.zero, ()async{
                  await storage.DataCache.dataWipe();
                  await AppNotifications.cancelScheduledNotifs();
                }).whenComplete((){
                  Navigator.popUntil(context, (route) => route.willHandlePopInternally);
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const root_page.Splitter()));
                });
                if(Platform.isAndroid){
                  Fluttertoast.showToast(msg: AppStrings.getLanguagePack().topmenu_buttons_LogoutSuccessToast, toastLength: Toast.LENGTH_SHORT, gravity: ToastGravity.SNACKBAR, backgroundColor: AppColors.getTheme().rootBackground, textColor: AppColors.getTheme().textColor);
                }
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}