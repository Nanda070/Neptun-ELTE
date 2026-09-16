import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:neptun2/CampusMap/bis_iig_credentials.dart';
import 'package:neptun2/CampusMap/campus_map_page.dart';
import 'package:neptun2/colors.dart';
import 'package:neptun2/haptics.dart';
import 'package:neptun2/language.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// In-app official BIS map (`bis.elte.hu`) via WebView + ELTE IIG / Caesar IdP.
///
/// Auth chain (from live HAR): bis → `/auth/login` → IdP `SSOService` →
/// `eltedbauth/authpage.php` (fields `username_iig` / `password_iig`) →
/// `resume.php` → POST `bis.elte.hu/auth/saml/callback` → map UI.
class BisCampusMapPage extends StatefulWidget {
  const BisCampusMapPage({super.key});

  /// Default entry after successful SAML (Budapest campus, English).
  static const mapUrl = 'https://bis.elte.hu/map/budapest?locale=en';
  static const rootUrl = 'https://bis.elte.hu/';

  @override
  State<BisCampusMapPage> createState() => _BisCampusMapPageState();
}

class _BisCampusMapPageState extends State<BisCampusMapPage> {
  late final WebViewController _controller;
  var _loading = true;
  var _onIdpLogin = false;
  var _autofillAttempted = false;
  var _sheetOpen = false;
  String? _statusUrl;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              _loading = true;
              _statusUrl = url;
              _onIdpLogin = _isIdpAuthPage(url);
              if (!_onIdpLogin) _autofillAttempted = false;
            });
          },
          onPageFinished: (url) async {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _statusUrl = url;
              _onIdpLogin = _isIdpAuthPage(url);
            });
            if (_isIdpAuthPage(url)) {
              await _maybeAutofillOrPrompt();
            }
          },
          onWebResourceError: (err) {
            if (kDebugMode) {
              debugPrint('BIS WebView error: ${err.description}');
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(BisCampusMapPage.mapUrl));

    _enableAndroidThirdPartyCookies();
  }

  Future<void> _enableAndroidThirdPartyCookies() async {
    final webPlatform = _controller.platform;
    if (webPlatform is AndroidWebViewController) {
      await AndroidWebViewController.enableDebugging(kDebugMode);
      await webPlatform.setMediaPlaybackRequiresUserGesture(false);
      final cookieMgr = WebViewCookieManager();
      final cookiePlatform = cookieMgr.platform;
      if (cookiePlatform is AndroidWebViewCookieManager) {
        // SAML hops IdP ↔ bis.elte.hu; third-party cookies help session stick.
        await cookiePlatform.setAcceptThirdPartyCookies(webPlatform, true);
      }
    }
  }

  static bool _isIdpAuthPage(String url) {
    final u = url.toLowerCase();
    return u.contains('idp.elte.hu') &&
        (u.contains('authpage.php') || u.contains('eltedbauth'));
  }

  static bool _isBisMap(String url) {
    final u = url.toLowerCase();
    return u.contains('bis.elte.hu') &&
        !u.contains('/auth/') &&
        (u.contains('/map/') || u == 'https://bis.elte.hu/' || u.startsWith('https://bis.elte.hu/?'));
  }

  Future<void> _maybeAutofillOrPrompt() async {
    if (_autofillAttempted || _sheetOpen) return;
    _autofillAttempted = true;
    final saved = await BisIigCredentials.read();
    if (saved != null) {
      await _injectCredentials(saved.username, saved.password, submit: true);
      return;
    }
    if (!mounted) return;
    await _showCredentialSheet();
  }

  Future<void> _injectCredentials(
    String username,
    String password, {
    required bool submit,
  }) async {
    final userJs = jsonEncode(username);
    final passJs = jsonEncode(password);
    final submitJs = submit ? 'true' : 'false';
    final script = '''
(function() {
  var u = document.getElementById('username_iig')
    || document.querySelector('input[name="username_iig"]');
  var p = document.getElementById('password_iig')
    || document.querySelector('input[name="password_iig"]');
  if (!u || !p) return 'no-form';
  u.value = $userJs;
  p.value = $passJs;
  try {
    u.dispatchEvent(new Event('input', { bubbles: true }));
    p.dispatchEvent(new Event('input', { bubbles: true }));
    u.dispatchEvent(new Event('change', { bubbles: true }));
    p.dispatchEvent(new Event('change', { bubbles: true }));
  } catch (e) {}
  if ($submitJs) {
    var form = u.form || document.querySelector('form[name="login_iig"]')
      || document.querySelector('form');
    if (form) {
      form.submit();
      return 'submitted';
    }
    var btn = document.querySelector('input[type="submit"]')
      || document.querySelector('button[type="submit"]');
    if (btn) { btn.click(); return 'clicked'; }
  }
  return 'filled';
})();
''';
    try {
      await _controller.runJavaScriptReturningResult(script);
    } catch (e) {
      if (kDebugMode) debugPrint('BIS autofill JS failed: $e');
    }
  }

  Future<void> _showCredentialSheet({bool force = false}) async {
    if (_sheetOpen && !force) return;
    _sheetOpen = true;
    final lang = AppStrings.getLanguagePack();
    final theme = AppColors.getTheme();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    var remember = BisIigCredentials.getRememberEnabled();
    final existing = await BisIigCredentials.read();
    if (existing != null) {
      userCtrl.text = existing.username;
    }

    if (!mounted) {
      _sheetOpen = false;
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.rootBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (ctx, setSheet) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    lang.campusMap_IigLoginRequired,
                    style: TextStyle(
                      color: theme.textColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lang.campusMap_IigLoginHint,
                    style: TextStyle(
                      color: theme.textColor.withValues(alpha: 0.65),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: userCtrl,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.next,
                    style: TextStyle(color: theme.textColor),
                    decoration: InputDecoration(
                      labelText: lang.campusMap_IigUsername,
                      labelStyle: TextStyle(color: theme.textColor.withValues(alpha: 0.7)),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    style: TextStyle(color: theme.textColor),
                    decoration: InputDecoration(
                      labelText: lang.campusMap_IigPassword,
                      labelStyle: TextStyle(color: theme.textColor.withValues(alpha: 0.7)),
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) async {
                      Navigator.pop(ctx);
                      await _applyCredentials(
                        userCtrl.text,
                        passCtrl.text,
                        remember: remember,
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: remember,
                    activeColor: theme.secondary,
                    title: Text(
                      lang.campusMap_IigSaveCredentials,
                      style: TextStyle(color: theme.textColor, fontSize: 14),
                    ),
                    subtitle: Text(
                      lang.campusMap_IigSaveCredentialsSubtitle,
                      style: TextStyle(
                        color: theme.textColor.withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    ),
                    onChanged: (v) => setSheet(() => remember = v ?? true),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () async {
                      AppHaptics.lightImpact();
                      Navigator.pop(ctx);
                      await _applyCredentials(
                        userCtrl.text,
                        passCtrl.text,
                        remember: remember,
                      );
                    },
                    child: Text(lang.campusMap_IigSignIn),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    _sheetOpen = false;
    userCtrl.dispose();
    passCtrl.dispose();
  }

  Future<void> _applyCredentials(
    String username,
    String password, {
    required bool remember,
  }) async {
    final u = username.trim();
    if (u.isEmpty || password.isEmpty) return;
    await BisIigCredentials.save(
      username: u,
      password: password,
      remember: remember,
    );
    // Ensure we are on (or reload) the IdP form, then inject.
    final url = _statusUrl ?? '';
    if (!_isIdpAuthPage(url)) {
      _autofillAttempted = false;
      await _controller.loadRequest(Uri.parse(BisCampusMapPage.mapUrl));
      // Injection happens on next authpage finish via saved creds / sheet.
      return;
    }
    await _injectCredentials(u, password, submit: true);
  }

  Future<void> _clearSavedAndRelogin() async {
    AppHaptics.lightImpact();
    await BisIigCredentials.clear();
    _autofillAttempted = false;
    await WebViewCookieManager().clearCookies();
    await _controller.loadRequest(Uri.parse(BisCampusMapPage.rootUrl));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.getLanguagePack().campusMap_IigCleared)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppStrings.getLanguagePack();
    final theme = AppColors.getTheme();
    final showBanner = _onIdpLogin || (_statusUrl != null && !_isBisMap(_statusUrl!));

    return Scaffold(
      backgroundColor: theme.rootBackground,
      appBar: AppBar(
        backgroundColor: theme.rootBackground,
        foregroundColor: theme.textColor,
        title: Text(lang.campusMap_Title, style: TextStyle(color: theme.textColor)),
        actions: [
          if (_onIdpLogin)
            IconButton(
              tooltip: lang.campusMap_IigSignIn,
              icon: const Icon(Icons.login_rounded),
              onPressed: () {
                AppHaptics.lightImpact();
                _autofillAttempted = false;
                _showCredentialSheet(force: true);
              },
            ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: theme.textColor),
            onSelected: (v) async {
              switch (v) {
                case 'login':
                  _autofillAttempted = false;
                  await _showCredentialSheet(force: true);
                  break;
                case 'clear':
                  await _clearSavedAndRelogin();
                  break;
                case 'reload':
                  AppHaptics.lightImpact();
                  await _controller.reload();
                  break;
                case 'offline':
                  AppHaptics.lightImpact();
                  if (!mounted) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CampusMapPage(),
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(value: 'login', child: Text(lang.campusMap_IigEnterCredentials)),
              PopupMenuItem(value: 'clear', child: Text(lang.campusMap_IigClearCredentials)),
              PopupMenuItem(value: 'reload', child: Text(lang.campusMap_Reload)),
              PopupMenuItem(value: 'offline', child: Text(lang.campusMap_OfflineDebug)),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (showBanner)
            Material(
              color: theme.secondary.withValues(alpha: 0.15),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, size: 18, color: theme.textColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        lang.campusMap_IigLoginRequired,
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: WebViewWidget(controller: _controller),
          ),
        ],
      ),
    );
  }
}
