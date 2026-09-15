import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neptun2/app_navigator.dart';
import 'package:neptun2/colors.dart';
import 'package:neptun2/haptics.dart';
import 'package:neptun2/language.dart';

typedef TwoFactorCodeCallback = void Function(dynamic code);

/// Full-screen TOTP entry after portal password ([Login2FA]).
///
/// Uses an opaque [Scaffold] on the root navigator so Android does not show a
/// blank/white window behind the old transparent popup overlay (`opaque: false`
/// + async [PackageInfo]/[Language.getAllLanguages] gate).
class TwoFactorCodePage extends StatefulWidget {
  const TwoFactorCodePage({
    super.key,
    required this.onCode,
  });

  final TwoFactorCodeCallback onCode;

  @override
  State<TwoFactorCodePage> createState() => _TwoFactorCodePageState();
}

class _TwoFactorCodePageState extends State<TwoFactorCodePage> {
  final TextEditingController _controller = TextEditingController();
  bool _delivered = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _deliver(dynamic code) {
    if (_delivered) return;
    _delivered = true;
    widget.onCode(code);
  }

  void _submit(String code) {
    if (_delivered || code.length != 6) return;
    AppHaptics.lightImpact();
    _delivered = true;
    // Pop first (this route), then deliver — same order as popup mode 9.
    Navigator.of(context).pop();
    widget.onCode(code);
  }

  void _cancel() {
    if (_delivered) return;
    AppHaptics.lightImpact();
    _delivered = true;
    Navigator.of(context).pop();
    widget.onCode(null);
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppStrings.getLanguagePack();
    final theme = AppColors.getTheme();
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop || _delivered) return;
        _deliver(null);
      },
      child: Scaffold(
        backgroundColor: theme.rootBackground,
        appBar: AppBar(
          backgroundColor: theme.rootBackground,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.close_rounded, color: theme.textColor),
            onPressed: _cancel,
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Text(
                  lang.popup_case9_2faHeader,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  lang.popup_case9_2faDescription,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.textColor.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 28,
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: theme.textColor.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    counterText: '',
                  ),
                  onChanged: (val) {
                    if (val.length == 6) _submit(val);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Push opaque 2FA page via root [appNavigatorKey] (safe after async login).
void openTwoFactorCodePage({required TwoFactorCodeCallback onCode}) {
  final nav = appNavigatorKey.currentState;
  if (nav == null) return;
  nav.push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => TwoFactorCodePage(onCode: onCode),
    ),
  );
}
