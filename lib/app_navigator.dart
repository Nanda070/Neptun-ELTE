import 'package:flutter/material.dart';

/// Root navigator key — shared so login/logout can replace the stack without
/// relying on a page [BuildContext] that may be disposed (black screen risk).
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Built once from [main]/[startup_page] — login root after session wipe.
WidgetBuilder? _loginRootBuilder;

/// Built once — Home after successful login/2FA.
WidgetBuilder? _homeRootBuilder;

void registerAppRoots({
  required WidgetBuilder loginRoot,
  required WidgetBuilder homeRoot,
}) {
  _loginRootBuilder = loginRoot;
  _homeRootBuilder = homeRoot;
}

/// Replace entire stack with the login/startup root (session expired / logout).
void navigateToLoginRoot() {
  final nav = appNavigatorKey.currentState;
  final builder = _loginRootBuilder;
  if (nav == null || builder == null) return;
  nav.pushAndRemoveUntil(
    MaterialPageRoute(builder: builder),
    (route) => false,
  );
}

/// Replace entire stack with Home after login/2FA.
/// Post-frame so any popup route can finish popping first.
void navigateToHomeRoot() {
  final go = () {
    final nav = appNavigatorKey.currentState;
    final builder = _homeRootBuilder;
    if (nav == null || builder == null) return;
    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: builder),
      (route) => false,
    );
  };
  WidgetsBinding.instance.addPostFrameCallback((_) => go());
}
