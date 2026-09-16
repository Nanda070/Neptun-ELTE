import 'dart:async';
import 'dart:convert' as conv;
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:neptun2/API/ics_calendar.dart';
import 'package:neptun2/Misc/clickable_text_span.dart';
import 'package:neptun2/app_navigator.dart';
import 'package:neptun2/colors.dart';
import 'package:neptun2/language.dart';
import 'package:neptun2/Misc/markbook_math.dart';
import '../storage.dart' as storage;
import 'dart:developer' as debug;
import '../storage.dart';

enum _TokenRefreshOutcome { success, authRejected, transientFailure }

/// Session expiry / logout coordination. Prevents "logged in" UI with dead JWT.
class SessionGuard {
  /// App policy: force logout this long after entering the main (participant) session.
  /// Independent of JWT refresh — aligns roughly with short-lived Neptun access tokens (~10–15 min).
  static const Duration sessionWallClockLimit = Duration(minutes: 10);

  /// Persisted epoch ms so background suspend (paused Timer) still counts as wall clock.
  static const String _sessionStartedAtPrefsKey = 'SESSION_StartedAtMs';

  /// Re-check interval while the isolate is alive. Long one-shot [Timer]s are often
  /// delayed/paused on Android (Doze / background); a short ticker recovers in FG.
  static const Duration _wallClockTickInterval = Duration(seconds: 15);

  static bool _authBlocked = false;
  static bool _handlingExpired = false;
  static String? _pendingUserMessage;
  static Future<void> Function(String message)? _onNavigateToLogin;
  static Timer? _sessionWallTimer;
  static Timer? _sessionWallTicker;
  static DateTime? _sessionStartedAt;
  /// Set when login / 2FA succeeds — avoids stale [SESSION_StartedAtMs] or
  /// immediate 401 recovery forcing logout right after a fresh participant session.
  static DateTime? _authenticatedAt;
  static const Duration _postLoginGrace = Duration(seconds: 45);
  /// Monotonic write gen so async prefs `0` from cancel cannot clobber a newer start.
  static int _sessionPersistGen = 0;

  static bool get isAuthBlocked => _authBlocked;

  static bool get _inPostLoginGrace {
    final at = _authenticatedAt;
    if (at == null) return false;
    return DateTime.now().difference(at) < _postLoginGrace;
  }

  static void registerNavigator(Future<void> Function(String message) nav) {
    _onNavigateToLogin = nav;
  }

  static void clearAuthBlock() {
    _authBlocked = false;
  }

  static String? consumePendingMessage() {
    final m = _pendingUserMessage;
    _pendingUserMessage = null;
    return m;
  }

  /// Clear persisted wall-clock before a new login attempt (stale stamp after expiry).
  static void prepareForLoginAttempt() {
    cancelSessionWallClock();
    _authenticatedAt = null;
    clearAuthBlock();
  }

  /// Call when portal / API login succeeds, **before** navigating to Home.
  static Future<void> markParticipantSessionStarted() async {
    _handlingExpired = false;
    clearAuthBlock();
    _stopWallTimers();
    final now = DateTime.now();
    _sessionStartedAt = now;
    _authenticatedAt = now;
    await _persistSessionStartedAt(now.millisecondsSinceEpoch);
    _armSessionWallTimer();
  }

  /// Arm / continue the 10-minute wall clock after login or cold start into Home.
  ///
  /// Does **not** restart on token refresh. Does **not** reset an existing in-window
  /// start (Home entry must not grant a fresh 10 min). Persists the stamp so
  /// background time still counts (one-shot Timer alone often pauses while suspended).
  static Future<void> startSessionWallClock() async {
    if (_handlingExpired || _authBlocked) return;
    _stopWallTimers();

    DateTime? started = _sessionStartedAt;
    if (started == null) {
      final ms = await storage.getInt(_sessionStartedAtPrefsKey);
      if (ms != null && ms > 0) {
        started = DateTime.fromMillisecondsSinceEpoch(ms);
      }
    }
    final authAt = _authenticatedAt;
    if (authAt != null && (started == null || started.isBefore(authAt))) {
      started = authAt;
    }

    final now = DateTime.now();
    if (started != null) {
      final elapsed = now.difference(started);
      if (elapsed >= sessionWallClockLimit) {
        debug.log(
          'SessionGuard: wall-clock already expired on start — forceExpiredLogout',
        );
        await forceExpiredLogout();
        return;
      }
      _sessionStartedAt = started;
      // Repair prefs if a prior cancel→start race wrote 0 after the real stamp.
      await _persistSessionStartedAt(started.millisecondsSinceEpoch);
      _armSessionWallTimer();
      return;
    }

    // No stamp yet (legacy path) — begin wall clock now.
    _sessionStartedAt = now;
    _authenticatedAt ??= now;
    await _persistSessionStartedAt(now.millisecondsSinceEpoch);
    _armSessionWallTimer();
  }

  static void _stopWallTimers() {
    _sessionWallTimer?.cancel();
    _sessionWallTicker?.cancel();
    _sessionWallTimer = null;
    _sessionWallTicker = null;
  }

  static Future<void> _persistSessionStartedAt(int ms) async {
    final gen = ++_sessionPersistGen;
    await storage.saveInt(_sessionStartedAtPrefsKey, ms);
    // If a newer cancel/start raced past us, leave their write alone.
    if (gen != _sessionPersistGen) return;
  }

  static void _armSessionWallTimer() {
    _stopWallTimers();
    final started = _sessionStartedAt;
    if (started == null) return;
    final remaining = sessionWallClockLimit - DateTime.now().difference(started);
    if (remaining <= Duration.zero) {
      debug.log('SessionGuard: wall-clock already expired — forceExpiredLogout');
      forceExpiredLogout();
      return;
    }
    debug.log(
      'SessionGuard: wall-clock logout in ${remaining.inSeconds}s '
      '(from $started)',
    );
    _sessionWallTimer = Timer(remaining, () {
      debug.log('SessionGuard: wall-clock expired — forceExpiredLogout');
      forceExpiredLogout();
    });
    // Belt-and-suspenders: Android may delay the one-shot Timer; tick catches it.
    _sessionWallTicker = Timer.periodic(_wallClockTickInterval, (_) {
      _tickSessionWallClock();
    });
  }

  static void _tickSessionWallClock() {
    if (_handlingExpired || _authBlocked) return;
    final started = _sessionStartedAt;
    if (started == null) return;
    final elapsed = DateTime.now().difference(started);
    if (elapsed >= sessionWallClockLimit) {
      debug.log(
        'SessionGuard: tick after ${elapsed.inSeconds}s — forceExpiredLogout',
      );
      forceExpiredLogout();
    }
  }

  static void cancelSessionWallClock() {
    _stopWallTimers();
    _sessionStartedAt = null;
    final gen = ++_sessionPersistGen;
    storage.saveInt(_sessionStartedAtPrefsKey, 0).then((_) {
      // Ignore stale completion if a newer start already persisted.
      if (gen != _sessionPersistGen) return;
    });
  }

  static void _clearAuthenticatedAt() {
    _authenticatedAt = null;
  }

  /// Call on [AppLifecycleState.resumed] (and safe on other lifecycle pulses).
  /// If background/suspend time pushed the session past 10 minutes, force logout;
  /// otherwise re-arm the foreground Timer for the remaining wall-clock time.
  static Future<void> checkSessionWallClockOnResume() async {
    if (_handlingExpired || _authBlocked) return;
    DateTime? started = _sessionStartedAt;
    if (started == null) {
      final ms = await storage.getInt(_sessionStartedAtPrefsKey);
      if (ms != null && ms > 0) {
        started = DateTime.fromMillisecondsSinceEpoch(ms);
      }
    }
    final authAt = _authenticatedAt;
    if (authAt != null && (started == null || started.isBefore(authAt))) {
      started = authAt;
    }
    if (started == null) return;
    _sessionStartedAt = started;
    // Keep prefs honest after Android process death / SharedPreferences races.
    await _persistSessionStartedAt(started.millisecondsSinceEpoch);
    final elapsed = DateTime.now().difference(started);
    if (elapsed >= sessionWallClockLimit) {
      debug.log(
        'SessionGuard: resume after ${elapsed.inMinutes} min — forceExpiredLogout',
      );
      await forceExpiredLogout();
      return;
    }
    _armSessionWallTimer();
  }

  /// Full auth leftover wipe shared by manual + expired logout (and login start).
  /// Keeps academic cache (calendar / markbook / mail / payments / periods / terms)
  /// so home surfaces can show last data after re-login (plan item 1).
  static Future<void> _wipeAuthLeftovers() async {
    _APIRequest.resetRefreshLock();
    await InstitutesRequest.eltePortalLogoutBestEffort();
    InstitutesRequest.resetEltePortalState();
    CalendarRequest.clearTrainingIdCache();
    await storage.DataCache.sessionWipeKeepCache();
  }

  /// Manual logout from drawer/settings: wipe session + portal jar, keep username.
  static Future<void> userInitiatedLogout() async {
    cancelSessionWallClock();
    _clearAuthenticatedAt();
    _authBlocked = true;
    await _wipeAuthLeftovers();
  }

  /// Cold-start gate (shortcuts / Splitter): usable participant session only if
  /// [HasLogin], access token present, and wall-clock not already expired.
  /// On failure, wipes auth (keeps academic cache) and sets the pending
  /// sign-in message — never open Home with a dead JWT.
  static Future<bool> isColdStartSessionUsable() async {
    if (_authBlocked) return false;
    if (!(storage.DataCache.getHasLogin() ?? false)) return false;
    final token = storage.DataCache.getAccessToken();
    if (token == null || token.isEmpty) {
      _pendingUserMessage =
          AppStrings.getLanguagePack().auth_sessionExpired_PleaseSignIn;
      try {
        await _wipeAuthLeftovers();
      } catch (e) {
        debug.log('isColdStartSessionUsable wipe (no token): $e');
      }
      _authBlocked = true;
      return false;
    }
    final ms = await storage.getInt(_sessionStartedAtPrefsKey);
    if (ms != null && ms > 0) {
      final started = DateTime.fromMillisecondsSinceEpoch(ms);
      if (DateTime.now().difference(started) >= sessionWallClockLimit) {
        debug.log(
          'SessionGuard: cold start wall-clock expired — wipe, skip Home',
        );
        _pendingUserMessage =
            AppStrings.getLanguagePack().auth_sessionExpired_PleaseSignIn;
        cancelSessionWallClock();
        _clearAuthenticatedAt();
        _authBlocked = true;
        try {
          await _wipeAuthLeftovers();
        } catch (e) {
          debug.log('isColdStartSessionUsable wipe (expired): $e');
        }
        return false;
      }
    }
    return true;
  }

  /// Access token dead and refresh/silent re-auth cannot restore session,
  /// or the 10-minute session wall clock fired.
  static Future<void> forceExpiredLogout() async {
    if (_handlingExpired) return;
    _handlingExpired = true;
    cancelSessionWallClock();
    _clearAuthenticatedAt();
    _authBlocked = true;
    final msg = AppStrings.getLanguagePack().auth_sessionExpired_PleaseSignIn;
    _pendingUserMessage = msg;
    try {
      await _wipeAuthLeftovers();
    } catch (e) {
      debug.log('forceExpiredLogout wipe error: $e');
    }
    try {
      // Prefer root key + replace-all so we never pop the sole Home route into an
      // empty navigator (permanent black screen after login/2FA).
      if (appNavigatorKey.currentState != null) {
        navigateToLoginRoot();
      } else {
        final registered = _onNavigateToLogin;
        if (registered != null) {
          await registered(msg);
        }
      }
    } catch (e) {
      debug.log('forceExpiredLogout navigate error: $e');
    }
    _handlingExpired = false;
  }
}
  
  class URLs{
    static const String INSTITUTIONS_URL = "https://mobilecloudservice.cloudapp.net/MobileServiceLib/MobileCloudService.svc/GetAllNeptunMobileUrls";
    static const String TRAININGS_URL = "/api/GetTrainings";
    static const String CALENDAR_URL = "/api/GetCalendarData";
    static const String PERIODTERMS_URL = "/api/GetPeriodTerms";
    static const String PERIODS_URL = "/api/GetPeriods";
    static const String GETCASHIN_URL = "/api/GetCashinData";
    static const String CURRICULUMS_URL = "/api/GetCurriculums";
    static const String MARKBOOK_URL = "/api/GetMarkbookData";
    static const String MESSAGES_URL = "/api/GetMessages";
    static const String MESSAGE_SET_READ = "/api/SetReadedMessage";
  }
  
  class _APIRequest{
    // POST-REQUEST for old API and modern login
    static Future<String> postRequest(Uri url, String requestBody,{String? bearerToken}) async{
      HttpOverrides.global = NeptunCerts.getCerts();
  
      final client = http.Client();
      final request = http.Request('POST', url);

      request.headers['Content-Type'] = 'application/json';
      if (bearerToken != null && bearerToken.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $bearerToken';
      }
      request.body = requestBody;

      var response;
      try{
        response = await client.send(request).then((response) {
          // Read and return the response
          return response.stream.bytesToString();
        });

        if (response != null) {
          String responseString = response.toString().trim();
          if (responseString.startsWith('<!DOCTYPE html') || responseString.startsWith('<html')){
            client.close();
            return conv.jsonEncode({'ErrorMessage': AppStrings.getLanguagePack().api_error_InvalidUrlOrHtml});
          }
        }
      }
      catch(error){
        client.close();
        return conv.jsonEncode({'ErrorMessage': AppStrings.getStringWithParams(AppStrings.getLanguagePack().api_error_Network, [error])});
      }

      // Close the client when done
      client.close();
  
      return response ?? '{}';
    }

    static Future<http.Response> postRequestRaw(Uri url, String requestBody,{String? bearerToken, String? cookie, Duration? timeout}) async {
      HttpOverrides.global = NeptunCerts.getCerts();
  
      final client = http.Client();
      final request = http.Request('POST', url);

      request.headers['Content-Type'] = 'application/json';
      request.headers['Accept'] = 'application/json, text/plain, */*';
      if (bearerToken != null && bearerToken.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $bearerToken';
      }
      if (cookie != null && cookie.isNotEmpty) {
        request.headers['Cookie'] = cookie;
      }
      request.body = requestBody;

      try {
        final sendFuture = client.send(request).then((streamed) => http.Response.fromStream(streamed));
        final response = timeout == null
            ? await sendFuture
            : await sendFuture.timeout(timeout);
        client.close();
        return response;
      } catch (e) {
        client.close();
        rethrow;
      }
    }

    static void _extractAndSaveCookiesAndTokens(http.Response response, String username) {
      final setCookie = response.headers['set-cookie'];
      if (setCookie == null || setCookie.isEmpty) return;

      // Extract device cookie: devicecookie-<BASE64_NEPTUN_CODE>=<VALUE>
      final deviceCookieRegExp = RegExp(r'devicecookie-[a-zA-Z0-9+/=]+=([a-zA-Z0-9+/=]+)');
      final deviceCookieMatch = deviceCookieRegExp.firstMatch(setCookie);
      if (deviceCookieMatch != null) {
        final cookieValue = deviceCookieMatch.group(1);
        storage.DataCache.setDeviceCookie(username, cookieValue);
      }

      // Extract refresh token: <GUID>=<JWT_REFRESH_TOKEN>
      // The key is a 36-char GUID (optional check), value starts with eyJ
      final refreshTokenRegExp = RegExp(r'[^=;\s,]+=(eyJ[a-zA-Z0-9\-_\.]+)');
      final refreshTokenMatch = refreshTokenRegExp.firstMatch(setCookie);
      if (refreshTokenMatch != null) {
        final tokenValue = refreshTokenMatch.group(1);
        storage.DataCache.setRefreshToken(tokenValue);
      }
    }

    static bool _isRefreshingToken = false;

    static void resetRefreshLock() {
      _isRefreshingToken = false;
    }

    static bool _isUnauthorizedResponse(int statusCode, String body) {
      if (statusCode == 401 || statusCode == 403) return true;
      final lower = body.toLowerCase();
      return body.contains('"statusCode": 401') ||
          body.contains('"statusCode":401') ||
          body.contains('Authorization has been denied') ||
          lower.contains('unauthorized') ||
          body.contains('A megadott kérelem nem engedélyezett');
    }

    static Future<bool> tryTokenRefresh() async {
      try {
        if (SessionGuard.isAuthBlocked) return false;
        final refreshToken = storage.DataCache.getRefreshToken();
        if (refreshToken == null || refreshToken.isEmpty) {
          return false;
        }

        final baseUrl = storage.DataCache.getInstituteUrl();
        if (baseUrl == null || baseUrl.isEmpty) {
          return false;
        }

        final refreshUrl = Uri.parse("$baseUrl/api/Account/GetNewTokens");
        final response = await postRequestRaw(refreshUrl, "{}", bearerToken: refreshToken);

        if (response.statusCode == 200) {
          final bodyJson = conv.jsonDecode(response.body);
          if (bodyJson["data"] != null && bodyJson["data"]["accessToken"] != null) {
            final newAccessToken = bodyJson["data"]["accessToken"];
            await storage.DataCache.setAccessToken(newAccessToken);
            final maybeRefresh = bodyJson["data"]["refreshToken"]?.toString();
            if (maybeRefresh != null && maybeRefresh.isNotEmpty) {
              await storage.DataCache.setRefreshToken(maybeRefresh);
            }

            final username = storage.DataCache.getUsername();
            if (username != null) {
              _extractAndSaveCookiesAndTokens(response, username);
            }
            return true;
          }
        }
        // Failed GetNewTokens (401/empty) — session cannot be refreshed
        if (response.statusCode == 401 || response.statusCode == 403) {
          debug.log("GetNewTokens unauthorized (${response.statusCode})");
        }
      } catch (e) {
        debug.log("Error during token refresh: $e");
      }
      return false;
    }

    /// Password re-auth without interactive 2FA. Never runs ELTE portal login
    /// (that would need TOTP and pollute the cookie jar after logout).
    static Future<bool> trySilentReauth() async {
      if (SessionGuard.isAuthBlocked) return false;
      final username = storage.DataCache.getUsername() ?? '';
      final password = storage.DataCache.getPassword() ?? '';
      final baseUrl = storage.DataCache.getInstituteUrl() ?? '';
      if (username.isEmpty || password.isEmpty || baseUrl.isEmpty) {
        return false;
      }
      if (InstitutesRequest.isElteHost(baseUrl) || InstitutesRequest.isElteHost(InstitutesRequest.elteNeptunBaseUrl)) {
        // OuterLogin sessions need refreshToken or interactive portal+2FA — not silent.
        return false;
      }
      try {
        final result = await InstitutesRequest.validateLoginCredentialsUrl(baseUrl, username, password);
        return result == InstitutesRequest.loginOk;
      } catch (e) {
        debug.log("Silent reauth error: $e");
        return false;
      }
    }

    /// Refresh → silent reauth → force logout. Returns true if a usable access token exists.
    static Future<bool> ensureValidSession() async {
      if (SessionGuard.isAuthBlocked) return false;
      if (!(storage.DataCache.getHasLogin() ?? false)) return false;

      final existing = storage.DataCache.getAccessToken();
      if (existing != null && existing.isNotEmpty) {
        // Caller already got 401; still try refresh first.
      }

      bool ok = false;
      if (!_isRefreshingToken) {
        _isRefreshingToken = true;
        try {
          debug.log("Session recovery: trying GetNewTokens...");
          if (storage.DataCache.getIsModernApi()) {
            ok = await tryTokenRefresh();
          }
          if (!ok) {
            debug.log("Session recovery: trying silent reauth...");
            ok = await trySilentReauth();
          }
          if (!ok) {
            if (SessionGuard._inPostLoginGrace &&
                (storage.DataCache.getAccessToken() ?? '').isNotEmpty) {
              debug.log(
                'Session recovery: post-login grace — skip force logout',
              );
              ok = true;
            } else {
              debug.log("Session recovery failed — forcing logout");
              await SessionGuard.forceExpiredLogout();
            }
          }
        } finally {
          _isRefreshingToken = false;
        }
      } else {
        debug.log("Session recovery already in progress — waiting");
        var spins = 0;
        while (_isRefreshingToken && spins < 100) {
          await Future.delayed(const Duration(milliseconds: 100));
          spins++;
        }
        ok = !SessionGuard.isAuthBlocked &&
            (storage.DataCache.getAccessToken() ?? '').isNotEmpty &&
            (storage.DataCache.getHasLogin() ?? false);
      }
      return ok;
    }

    static Future<String> getRequest(Uri url, {required String bearerToken, bool isRetry = false}) async {
      HttpOverrides.global = NeptunCerts.getCerts();
      final client = http.Client();
      final request = http.Request('GET', url);
      request.headers['Authorization'] = 'Bearer $bearerToken';
      request.headers['Content-Type'] = 'application/json';
      request.headers['Accept-Language'] = AppStrings.getCurrentLangCode();

      try {
        final streamedResponse = await client.send(request);
        final response = await http.Response.fromStream(streamedResponse);
        client.close();

        if (_isUnauthorizedResponse(response.statusCode, response.body) && !isRetry) {
          if (SessionGuard.isAuthBlocked || !(storage.DataCache.getHasLogin() ?? false)) {
            return conv.jsonEncode({'ErrorMessage': AppStrings.getLanguagePack().auth_sessionExpired_PleaseSignIn});
          }

          final recovered = await ensureValidSession();
          if (!recovered) {
            return conv.jsonEncode({'ErrorMessage': AppStrings.getLanguagePack().auth_sessionExpired_PleaseSignIn});
          }

          final newToken = storage.DataCache.getAccessToken();
          if (newToken == null || newToken.isEmpty) {
            await SessionGuard.forceExpiredLogout();
            return conv.jsonEncode({'ErrorMessage': AppStrings.getLanguagePack().auth_sessionExpired_PleaseSignIn});
          }
          return await getRequest(url, bearerToken: newToken, isRetry: true);
        }

        return response.body;
      } catch (e) {
        client.close();
        return conv.jsonEncode({'ErrorMessage': '$e'});
      }
    }

    static String getGenericPostData(String username, String password){
      return
        '{'
          '"UserLogin":"$username",'
          '"Password":"$password"'
        '}';
    }
  }

  class TermsRequest{
    static List<Term> sortTerms(List<Term> termList) {
      termList.sort((a, b) {
        final reg = RegExp(r'(\d{4})/(?:\d{2}|\d{4})/(\d)');
        final matchA = reg.firstMatch(a.termName);
        final matchB = reg.firstMatch(b.termName);
        if (matchA != null && matchB != null) {
          int yearA = int.tryParse(matchA.group(1) ?? '0') ?? 0;
          int semA = int.tryParse(matchA.group(2) ?? '0') ?? 0;
          int yearB = int.tryParse(matchB.group(1) ?? '0') ?? 0;
          int semB = int.tryParse(matchB.group(2) ?? '0') ?? 0;
          if (yearA != yearB) return yearA.compareTo(yearB);
          return semA.compareTo(semB);
        }
        return a.termName.compareTo(b.termName);
      });
      return termList;
    }

    static Future<List<Term>> getTerms({bool forceRefresh = false}) async {
      if (storage.DataCache.getIsDemoAccount() ?? false) {
        return [Term('70876', AppStrings.getLanguagePack().api_demo_Term1), Term('70877', AppStrings.getLanguagePack().api_demo_Term2)];
      }
      if (!forceRefresh) {
        final cachedRaw = storage.DataCache.getCachedTermsRaw();
        if (cachedRaw.isNotEmpty) {
          try {
            final list = cachedRaw.map((s) => Term.deserialize(s)).toList();
            if (list.isNotEmpty) {
              return sortTerms(list);
            }
          } catch (_) {}
        }
      }

      List<Term> terms = [];
      if (storage.DataCache.getIsModernApi()) {
        try {
          final token = await storage.DataCache.getAccessToken();
          String baseUrl = storage.DataCache.getInstituteUrl() ?? '';
          
          // 1. Try RegisteredCourses/GetTerms
          try {
            final rTermsUrl = Uri.parse("$baseUrl/api/RegisteredCourses/GetTerms");
            final rTermsResponse = await _APIRequest.getRequest(rTermsUrl, bearerToken: token!);
            final rTermsDecoded = conv.json.decode(rTermsResponse);
            if (rTermsDecoded['data'] != null && rTermsDecoded['data'] is List) {
              for (var item in rTermsDecoded['data']) {
                final val = item['value']?.toString() ?? '';
                final text = item['text']?.toString() ?? item['termName']?.toString() ?? val;
                if (val.isNotEmpty) {
                  terms.add(Term(val, text));
                }
              }
            }
          } catch (_) {}

          // 2. Try TakenSubjects/Terms
          if (terms.isEmpty) {
            try {
              final termsUrl = Uri.parse("$baseUrl/api/TakenSubjects/Terms");
              final termsResponse = await _APIRequest.getRequest(termsUrl, bearerToken: token!);
              final termsDecoded = conv.json.decode(termsResponse);
              if (termsDecoded['data'] != null && termsDecoded['data'] is List) {
                for (var item in termsDecoded['data']) {
                  final val = item['value']?.toString() ?? '';
                  final text = item['text']?.toString() ?? item['termName']?.toString() ?? val;
                  if (val.isNotEmpty) {
                    terms.add(Term(val, text));
                  }
                }
              }
            } catch (_) {}
          }

          // 3. Try Periods/GetTerms
          if (terms.isEmpty) {
            try {
              final pTermsUrl = Uri.parse("$baseUrl/api/Periods/GetTerms");
              final pTermsResponse = await _APIRequest.getRequest(pTermsUrl, bearerToken: token!);
              final pTermsDecoded = conv.json.decode(pTermsResponse);
              if (pTermsDecoded['data'] != null && pTermsDecoded['data'] is List) {
                for (var item in pTermsDecoded['data']) {
                  final val = item['value']?.toString() ?? '';
                  final text = item['text']?.toString() ?? item['termName']?.toString() ?? val;
                  if (val.isNotEmpty) {
                    terms.add(Term(val, text));
                  }
                }
              }
            } catch (_) {}
          }
        } catch (e) {
          debug.log("Hiba a modern félévek lekérésekor: $e");
        }
      } else {
        try {
          final username = storage.DataCache.getUsername();
          final password = storage.DataCache.getPassword();
          final url = Uri.parse(storage.DataCache.getInstituteUrl()! + URLs.PERIODTERMS_URL);
          final request = await _APIRequest.postRequest(url, _APIRequest.getGenericPostData(username!, password!));

          final decoded = conv.json.decode(request);
          if (decoded['PeriodTermsList'] != null && decoded['PeriodTermsList'] is List) {
            List<dynamic> termList = decoded['PeriodTermsList'];
            for (var term in termList){
              final map = term as Map<String, dynamic>;
              terms.add(Term(map['Id'], map['TermName'] ?? ''));
            }
          }
        } catch (e) {
          debug.log("Hiba a régi félévek lekérésekor: $e");
        }
      }

      if (terms.isNotEmpty) {
        terms = sortTerms(terms);
        await storage.DataCache.setCachedTermsRaw(terms.map((t) => t.serialize()).toList());
        final currentSelected = storage.DataCache.getSelectedTermId();
        final currentSelectedName = storage.DataCache.getSelectedTermName();

        Term? matchedTerm;
        if (currentSelected != null && terms.any((t) => t.id == currentSelected)) {
          matchedTerm = terms.firstWhere((t) => t.id == currentSelected);
        } else if (currentSelectedName != null && terms.any((t) => t.termName == currentSelectedName)) {
          matchedTerm = terms.firstWhere((t) => t.termName == currentSelectedName);
        } else {
          matchedTerm = terms.last;
        }

        await storage.DataCache.setSelectedTermId(matchedTerm.id);
        await storage.DataCache.setSelectedTermName(matchedTerm.termName);
      }
      return terms;
    }
  }
  
  class InstitutesRequest{
    static Future<List<dynamic>?> fetchInstitudesJSON() async{
      //return _APIRequest.postRequest(Uri.parse(URLs.INSTITUTIONS_URL), '{}');
      var json;
      try{
        json = await getRawJsonWithNameUrlPairs();
      }
      catch(error){
      }
      return json;
    }

    static Future<List<dynamic>?> getRawJsonWithNameUrlPairs() async{
      final url = Uri.parse('https://raw.githubusercontent.com/Nanda070/Neptun-ELTE/refs/heads/main/universityNameUrlPairs.json');
      final response = await http.get(url);

      if (response.statusCode != 200) {
        return null;
      }

      Map<String, dynamic> jsonMap = conv.json.decode(response.body);
      return jsonMap["Institutes"];
    }
  
    static List<Institute> getDataFromInstitudesJSON(List<dynamic> jsonMap){
      var newList = <Institute>[].toList();
      for (var item in jsonMap){
        var item2 = item as Map<String, dynamic>;
        String name = item2['Name'];
        String url = item2['Url'] ?? "NULL";
        if(url != "NULL" && name != "DEMO") { //remove obsolete or non existent entries
          newList.add(Institute(name, url));
        }
      }
      return newList;
    }
    static Future<int> validateLoginCredentials(Institute institute, String username, String password) async{
      return validateLoginCredentialsUrl(institute.URL, username, password);
    }

    /// Login result codes for modern/old auth.
    /// 1 = success, 2 = 2FA required, 0 = invalid credentials, 3 = server/network busy,
    /// 4 = Student web (HWEB) capacity full — not a bad password / TOTP.
    static const int loginOk = 1;
    static const int loginNeeds2fa = 2;
    static const int loginInvalidCredentials = 0;
    static const int loginServerBusy = 3;
    static const int loginStudentWebFull = 4;

    /// Hub is ELTE-only. Portal + JWT API base (not Obuda/BME `/ujhallgato`).
    /// HWEB SPA is load-balanced across hallgato1…N.neptun.elte.hu — never hardcode a node as login base.
    static const String elteInstituteName = 'Eötvös Loránd Tudományegyetem (ELTE)';
    static const String elteNeptunBaseUrl = 'https://neptun.elte.hu';

    /// Modern Neptun API root — strip SPA login routes (`/Account`, `/login`), not REST prefixes.
    static String normalizeModernApiBaseUrl(String rawUrl) {
      var url = rawUrl.trim();
      if (url.endsWith('/')) {
        url = url.substring(0, url.length - 1);
      }
      url = url.replaceAll(RegExp(r'/login(\.aspx)?$', caseSensitive: false), '');
      url = url.replaceAll(RegExp(r'/MobileService\.svc$', caseSensitive: false), '');
      // /Account and /Account/Login are the web login SPA, not the REST API prefix
      url = url.replaceAll(RegExp(r'/Account(/Login)?/?$', caseSensitive: false), '');
      return url.replaceAll(RegExp(r'/+$'), '');
    }

    static List<String> _modernLoginBaseCandidates(String rawUrl) {
      final primary = normalizeModernApiBaseUrl(rawUrl);
      final out = <String>[];
      void add(String? u) {
        if (u == null || u.isEmpty) return;
        final cleaned = u.replaceAll(RegExp(r'/+$'), '');
        if (!out.contains(cleaned)) out.add(cleaned);
      }

      add(primary);
      final uri = Uri.tryParse(primary.isEmpty ? elteNeptunBaseUrl : primary);
      if (uri != null && uri.host.toLowerCase().contains('elte.hu')) {
        // ELTE JWT Authenticate on portal returns empty 400; HWEB nodes redirect to portal.
        // ELTE uses portal form login + OuterLogin (see _tryEltePortalLogin).
        add(elteNeptunBaseUrl);
        add(uri.replace(path: '').toString());
      }
      return out;
    }

    static bool _isElteUrl(String rawUrl) {
      final host = Uri.tryParse(normalizeModernApiBaseUrl(rawUrl))?.host.toLowerCase() ?? '';
      return host.contains('elte.hu') || rawUrl.toLowerCase().contains('elte');
    }

    /// Public ELTE host check (session recovery / silent reauth).
    static bool isElteHost(String rawUrl) => _isElteUrl(rawUrl);

    /// Clear in-memory portal cookies + 2FA pending state (call on logout / session death).
    static void resetEltePortalState() {
      _elteCookies.clear();
      _elteClearPortal2fa();
      _elteHasTotp = true;
      _elteHasEmail = true;
    }

    /// Best-effort portal Logout so the server session dies before jar wipe.
    /// Failures are ignored — local wipe still proceeds.
    static Future<void> eltePortalLogoutBestEffort() async {
      if (_elteCookies.isEmpty) return;
      try {
        final get = await _elteSend('GET', Uri.parse('$elteNeptunBaseUrl/Account/Logout'));
        final token = _elteExtractAntiforgery(get.body);
        if (token != null && token.isNotEmpty) {
          await _elteSend(
            'POST',
            Uri.parse('$elteNeptunBaseUrl/Account/Logout'),
            body: _elteFormEncode({'__RequestVerificationToken': token}),
          );
        }
      } catch (e) {
        debug.log('ELTE portal logout best-effort: $e');
      }
    }

    // --- ELTE portal (Potlap) → Student web OuterLogin (from live HAR Sep 2026) ---
    static final Map<String, String> _elteCookies = {};
    static bool _eltePortal2faPending = false;
    static String? _elte2faKey;
    static String? _elte2faNeptunCode;
    static String? _elteAntiforgery;
    static String? _elte2faRendered;
    static bool _elteHasTotp = true;
    static bool _elteHasEmail = true;
    static String? _elteEmailCodePrefix;

    static void _elteClearPortal2fa() {
      _eltePortal2faPending = false;
      _elte2faKey = null;
      _elte2faNeptunCode = null;
      _elteAntiforgery = null;
      _elte2faRendered = null;
      _elteEmailCodePrefix = null;
    }

    static String _elteCookieHeader() =>
        _elteCookies.entries.map((e) => '${e.key}=${e.value}').join('; ');

    static void _elteAbsorbSetCookies(HttpClientResponse response) {
      for (final c in response.cookies) {
        if (c.value.isEmpty || c.expires?.isBefore(DateTime.now()) == true) {
          _elteCookies.remove(c.name);
        } else {
          _elteCookies[c.name] = c.value;
        }
      }
      // Some IIS responses only put Set-Cookie in headers
      final raw = response.headers[HttpHeaders.setCookieHeader];
      if (raw != null) {
        for (final line in raw) {
          final part = line.split(';').first;
          final eq = part.indexOf('=');
          if (eq > 0) {
            final name = part.substring(0, eq).trim();
            final value = part.substring(eq + 1).trim();
            if (name.isNotEmpty) {
              if (value.isEmpty) {
                _elteCookies.remove(name);
              } else {
                _elteCookies[name] = value;
              }
            }
          }
        }
      }
    }

    static String _elteFormEncode(Map<String, String> fields) {
      return fields.entries
          .map((e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
          .join('&');
    }

    static String? _elteExtractAntiforgery(String html) {
      final m = RegExp(
        r'name="__RequestVerificationToken"[^>]*value="([^"]+)"',
        caseSensitive: false,
      ).firstMatch(html);
      return m?.group(1);
    }

    static Future<({int status, String location, String body})> _elteSend(
      String method,
      Uri uri, {
      String? body,
      String? contentType,
      bool followRedirects = false,
    }) async {
      HttpOverrides.global = NeptunCerts.getCerts();
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 25);
      try {
        final req = await client.openUrl(method, uri);
        req.followRedirects = followRedirects;
        req.maxRedirects = 0;
        req.headers.set(HttpHeaders.userAgentHeader,
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/153.0.0.0 Safari/537.36');
        req.headers.set(HttpHeaders.acceptHeader,
            'text/html,application/xhtml+xml,application/json,application/xml;q=0.9,*/*;q=0.8');
        req.headers.set('Origin', elteNeptunBaseUrl);
        if (uri.path.contains('Login2FA')) {
          req.headers.set('Referer',
              '$elteNeptunBaseUrl/Account/Login2FA?NeptunCode=${_elte2faNeptunCode ?? ''}&Key=${_elte2faKey ?? ''}');
        } else if (uri.path.contains('ToNeptun')) {
          req.headers.set('Referer', '$elteNeptunBaseUrl/ToNeptunWeb/ToNeptunHWeb');
        } else {
          req.headers.set('Referer', '$elteNeptunBaseUrl/Account/Login');
        }
        if (_elteCookies.isNotEmpty) {
          req.headers.set(HttpHeaders.cookieHeader, _elteCookieHeader());
        }
        if (body != null) {
          final bytes = conv.utf8.encode(body);
          req.headers.set(HttpHeaders.contentTypeHeader,
              contentType ?? 'application/x-www-form-urlencoded');
          req.contentLength = bytes.length;
          req.add(bytes);
        }
        final res = await req.close().timeout(const Duration(seconds: 35));
        _elteAbsorbSetCookies(res);
        final status = res.statusCode;
        final location = res.headers.value(HttpHeaders.locationHeader) ?? '';
        final responseBody = conv.utf8.decode(
          await res.expand((c) => c).toList(),
          allowMalformed: true,
        );
        debug.log('ELTE $method ${uri.path} -> $status loc=${location.length > 80 ? location.substring(0, 80) : location} body=${responseBody.length}');
        // ignore: avoid_print
        print('ELTE $method ${uri.path} -> $status loc=$location bodyLen=${responseBody.length}');
        return (status: status, location: location, body: responseBody);
      } finally {
        client.close(force: true);
      }
    }

    /// ELTE AD institute: portal form login (not JWT Authenticate on neptun.elte.hu).
    static Future<int> _tryEltePortalLogin(String username, String password) async {
      try {
        _elteCookies.clear();
        _elteClearPortal2fa();

        final loginGet = await _elteSend('GET', Uri.parse('$elteNeptunBaseUrl/Account/Login'));
        if (loginGet.status >= 500) return loginServerBusy;
        final antiforgery = _elteExtractAntiforgery(loginGet.body);
        if (antiforgery == null || antiforgery.isEmpty) {
          debug.log('ELTE portal: no antiforgery on Login page');
          // ignore: avoid_print
          print('ELTE portal: no antiforgery');
          return loginServerBusy;
        }

        final postBody = _elteFormEncode({
          'LoginName': username,
          'Password': password,
          'ReturnUrl': '',
          '__RequestVerificationToken': antiforgery,
        });
        final loginPost = await _elteSend(
          'POST',
          Uri.parse('$elteNeptunBaseUrl/Account/Login'),
          body: postBody,
        );
        final loc = loginPost.location;

        if (loginPost.status == 302 && loc.contains('Login2FA')) {
          final redirect = Uri.parse(loc.startsWith('http') ? loc : '$elteNeptunBaseUrl$loc');
          _elte2faNeptunCode = redirect.queryParameters['NeptunCode'] ?? username;
          _elte2faKey = redirect.queryParameters['Key'];
          if (_elte2faKey == null || _elte2faKey!.isEmpty) {
            // ignore: avoid_print
            print('ELTE portal: Login2FA redirect missing Key');
            return loginServerBusy;
          }

          final twoFaGet = await _elteSend('GET', redirect);
          final twoFaHtml = twoFaGet.body;
          _elteAntiforgery = _elteExtractAntiforgery(twoFaHtml) ?? antiforgery;
          final rendered = RegExp(r'name="Rendered"[^>]*value="([^"]*)"', caseSensitive: false)
              .firstMatch(twoFaHtml)
              ?.group(1);
          _elte2faRendered = (rendered != null && rendered.isNotEmpty)
              ? rendered
              : DateTime.now().toIso8601String();
          _elteHasTotp = true;
          _elteHasEmail = true;
          if (twoFaHtml.contains('name="HasTOTP"')) {
            _elteHasTotp = RegExp(r'name="HasTOTP"[^>]*value="True"', caseSensitive: false)
                .hasMatch(twoFaHtml);
          }
          if (twoFaHtml.contains('name="HasEmail"')) {
            _elteHasEmail = RegExp(r'name="HasEmail"[^>]*value="True"', caseSensitive: false)
                .hasMatch(twoFaHtml);
          }
          _eltePortal2faPending = true;
          await storage.DataCache.setInstituteUrl(elteNeptunBaseUrl);
          // ignore: avoid_print
          print('ELTE portal: needs 2FA');
          return loginNeeds2fa;
        }

        if (loginPost.status == 302 &&
            (loc == '/' || loc.isEmpty || loc == elteNeptunBaseUrl || loc.endsWith('neptun.elte.hu/'))) {
          return await _elteBridgeToHwebWithRetry();
        }

        if (loginPost.status == 200) {
          // Only treat as invalid when the portal actually reports bad credentials.
          // A bare login form redisplay (contains LoginName) is NOT proof of wrong password —
          // it often means CSRF/session conflict or server busy (Bug B after logout).
          if (_looksLikeInvalidCredentials(loginPost.body, 200)) {
            return loginInvalidCredentials;
          }
          final lower = loginPost.body.toLowerCase();
          if (lower.contains('login was unsuccessful') ||
              lower.contains('sikertelen bejelentkez')) {
            return loginInvalidCredentials;
          }
          // Validation summary only counts if it mentions credentials / password.
          if ((lower.contains('field-validation-error') ||
                  lower.contains('validation-summary-errors')) &&
              (lower.contains('password') ||
                  lower.contains('jelszó') ||
                  lower.contains('jelszo') ||
                  lower.contains('felhasználó') ||
                  lower.contains('felhasznalo') ||
                  lower.contains('loginname') ||
                  lower.contains('credentials'))) {
            return loginInvalidCredentials;
          }
          return loginServerBusy;
        }
        if (loginPost.status >= 500 || loginPost.status == 0) {
          return loginServerBusy;
        }
        // ignore: avoid_print
        print('ELTE portal login unexpected status=${loginPost.status} loc=$loc');
        return loginServerBusy;
      } on TimeoutException {
        // ignore: avoid_print
        print('ELTE portal login timeout');
        return loginServerBusy;
      } catch (e) {
        debug.log('ELTE portal login error: $e');
        // ignore: avoid_print
        print('ELTE portal login error: $e');
        return loginServerBusy;
      }
    }

    /// Portal / HWEB HTML that means capacity full (not bad password).
    static bool _elteLooksLikeStudentWebFull(String html) {
      final lower = html.toLowerCase();
      return lower.contains('student web is full') ||
          lower.contains('neptun student web is full') ||
          lower.contains('hallgatói web megtelt') ||
          lower.contains('hallgatoi web megtelt') ||
          lower.contains('nincs szabad') ||
          lower.contains('web megtelt') ||
          (lower.contains('megtelt') && lower.contains('web')) ||
          (lower.contains('capacity') && lower.contains('full'));
    }

    /// After portal session: POST ToNeptunHWeb → hallgatoN/outerlogin?GUID= → OuterLogin JWT.
    /// Returns [loginOk], [loginStudentWebFull], or [loginServerBusy] — never invalid credentials.
    static Future<int> _elteBridgeToHweb() async {
      try {
        final page = await _elteSend('GET', Uri.parse('$elteNeptunBaseUrl/ToNeptunWeb/ToNeptunHWeb'));
        final html = page.body;
        if (_elteLooksLikeStudentWebFull(html)) {
          debug.log('ELTE HWEB bridge: student web is full');
          // ignore: avoid_print
          print('ELTE HWEB bridge: student web is full');
          return loginStudentWebFull;
        }
        final token = _elteExtractAntiforgery(html);
        if (token == null) {
          // ignore: avoid_print
          print('ELTE HWEB bridge: no antiforgery (status=${page.status} bodyLen=${html.length})');
          if (_elteLooksLikeStudentWebFull(html)) return loginStudentWebFull;
          return loginServerBusy;
        }

        final post = await _elteSend(
          'POST',
          Uri.parse('$elteNeptunBaseUrl/ToNeptunWeb/ToNeptunHWeb'),
          body: _elteFormEncode({
            'NeptunWebType': 'HWeb',
            'NeptunWebIndex': '',
            '__RequestVerificationToken': token,
          }),
        );
        final loc = post.location;
        if (_elteLooksLikeStudentWebFull(post.body)) {
          // ignore: avoid_print
          print('ELTE HWEB bridge POST: student web is full');
          return loginStudentWebFull;
        }
        if (post.status != 302 || !loc.contains('outerlogin')) {
          debug.log('ELTE HWEB bridge: unexpected status=${post.status} loc=$loc');
          // ignore: avoid_print
          print('ELTE HWEB bridge: unexpected status=${post.status} loc=$loc');
          return loginServerBusy;
        }
        final outer = Uri.parse(loc);
        final guid = outer.queryParameters['GUID'] ?? outer.queryParameters['guid'];
        if (guid == null || guid.isEmpty) return loginServerBusy;
        final lcid = AppStrings.getNeptunLcid();
        final hwebBase = '${outer.scheme}://${outer.host}';

        await _elteSend('GET', outer);

        final outerLoginUri = Uri.parse('$hwebBase/api/Account/OuterLogin');
        final jsonBody = conv.jsonEncode({'guid': guid, 'lcid': lcid});
        HttpOverrides.global = NeptunCerts.getCerts();
        final client = HttpClient();
        try {
          final req = await client.postUrl(outerLoginUri);
          req.followRedirects = false;
          req.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
          req.headers.set(HttpHeaders.acceptHeader, 'application/json, text/plain, */*');
          req.headers.set('Origin', hwebBase);
          req.headers.set('Referer', outer.toString());
          if (_elteCookies.isNotEmpty) {
            req.headers.set(HttpHeaders.cookieHeader, _elteCookieHeader());
          }
          req.add(conv.utf8.encode(jsonBody));
          final res = await req.close().timeout(const Duration(seconds: 35));
          _elteAbsorbSetCookies(res);
          final raw = conv.utf8.decode(await res.expand((c) => c).toList(), allowMalformed: true);
          if (res.statusCode != 200) {
            debug.log('OuterLogin status=${res.statusCode} body=${raw.substring(0, raw.length.clamp(0, 200))}');
            // ignore: avoid_print
            print('OuterLogin status=${res.statusCode}');
            if (_elteLooksLikeStudentWebFull(raw)) return loginStudentWebFull;
            return loginServerBusy;
          }
          final decoded = conv.jsonDecode(raw);
          final data = decoded is Map ? decoded['data'] : null;
          final access = data is Map ? data['accessToken']?.toString() : null;
          if (access == null || access.isEmpty) return loginServerBusy;
          await storage.DataCache.setAccessToken(access);
          // Persist refresh JWT if OuterLogin returns it or sets it via Set-Cookie
          final refreshFromBody = data is Map ? data['refreshToken']?.toString() : null;
          if (refreshFromBody != null && refreshFromBody.isNotEmpty) {
            await storage.DataCache.setRefreshToken(refreshFromBody);
          } else {
            for (final entry in _elteCookies.entries) {
              final v = entry.value;
              if (v.startsWith('eyJ') && v != access && v.split('.').length >= 3) {
                await storage.DataCache.setRefreshToken(v);
                break;
              }
            }
          }
          await storage.DataCache.setIsModernApi(true);
          await storage.DataCache.setInstituteUrl(hwebBase);
          _elteClearPortal2fa();
          SessionGuard.clearAuthBlock();
          // ignore: avoid_print
          print('ELTE OuterLogin OK host=$hwebBase');
          return loginOk;
        } finally {
          client.close(force: true);
        }
      } catch (e) {
        debug.log('ELTE HWEB bridge error: $e');
        // ignore: avoid_print
        print('ELTE HWEB bridge error: $e');
        return loginServerBusy;
      }
    }

    /// Retry ToNeptunHWeb / OuterLogin for ~[window] while Student web is full/flaky.
    /// Returns [loginOk] as soon as JWT is obtained (no forced wait). On persistent
    /// failure returns [loginStudentWebFull] if any attempt saw capacity full,
    /// otherwise [loginServerBusy].
    static Future<int> _elteBridgeToHwebWithRetry({
      Duration window = const Duration(seconds: 7),
      Duration pauseBetween = const Duration(milliseconds: 1500),
    }) async {
      final deadline = DateTime.now().add(window);
      var last = loginServerBusy;
      var sawFull = false;
      var attempt = 0;
      while (true) {
        attempt++;
        last = await _elteBridgeToHweb();
        // ignore: avoid_print
        print('ELTE HWEB bridge attempt=$attempt result=$last');
        if (last == loginOk) return loginOk;
        if (last == loginStudentWebFull) sawFull = true;
        final remaining = deadline.difference(DateTime.now());
        if (remaining <= Duration.zero) break;
        final sleep = pauseBetween < remaining ? pauseBetween : remaining;
        if (sleep <= Duration.zero) break;
        await Future.delayed(sleep);
      }
      return sawFull ? loginStudentWebFull : last;
    }

    /// Portal Login2FA → bridge. Returns loginOk / loginInvalidCredentials (bad TOTP) /
    /// loginStudentWebFull / loginServerBusy — never conflates full with bad password.
    /// [onBridging] fires after TOTP succeeds and before the HWEB retry window.
    static Future<int> _submitEltePortal2fa(
      String code, {
      void Function()? onBridging,
    }) async {
      try {
        if (!_eltePortal2faPending ||
            _elte2faKey == null ||
            _elte2faNeptunCode == null ||
            _elteAntiforgery == null) {
          // ignore: avoid_print
          print('ELTE 2FA submit: missing pending state');
          return loginServerBusy;
        }
        final trimmed = code.trim();
        final rendered = _elte2faRendered ?? DateTime.now().toIso8601String();
        final fields = <String, String>{
          'NeptunCode': _elte2faNeptunCode!,
          'Key': _elte2faKey!,
          'ReturnUrl': '',
          'HasTOTP': _elteHasTotp ? 'True' : 'False',
          'HasEmail': _elteHasEmail ? 'True' : 'False',
          'Rendered': rendered,
          '__RequestVerificationToken': _elteAntiforgery!,
        };

        if (_elteEmailCodePrefix != null && _elteEmailCodePrefix!.isNotEmpty) {
          fields['Phase'] = 'RequestEmailCode';
          fields['CodePrefix'] = _elteEmailCodePrefix!;
          fields['EmailCode'] = trimmed;
        } else {
          fields['Phase'] = 'RequestTOTP';
          fields['CodePrefix'] = '';
          fields['TOTPCode'] = trimmed;
        }

        final post = await _elteSend(
          'POST',
          Uri.parse('$elteNeptunBaseUrl/Account/Login2FA'),
          body: _elteFormEncode(fields),
        );
        final loc = post.location;
        final body = post.body;
        // ignore: avoid_print
        print('ELTE 2FA POST status=${post.status} loc=$loc cookies=${_elteCookies.length}');

        if (_elteLooksLikeStudentWebFull(body)) {
          onBridging?.call();
          return await _elteBridgeToHwebWithRetry();
        }

        // Success: portal home (same shapes as password-only login redirect).
        final authOk = post.status == 302 &&
            (loc == '/' ||
                loc.isEmpty ||
                loc == elteNeptunBaseUrl ||
                loc.endsWith('/') ||
                loc.toLowerCase().endsWith('neptun.elte.hu') ||
                loc.toLowerCase().endsWith('neptun.elte.hu/'));
        if (authOk) {
          onBridging?.call();
          return await _elteBridgeToHwebWithRetry();
        }

        if (post.status == 200) {
          final prefix = RegExp(r'name="CodePrefix"[^>]*value="([^"]*)"', caseSensitive: false)
              .firstMatch(body)
              ?.group(1);
          if (prefix != null && prefix.isNotEmpty) {
            _elteEmailCodePrefix = prefix;
          }
          final token = _elteExtractAntiforgery(body);
          if (token != null) _elteAntiforgery = token;
          // Form redisplay → wrong / expired TOTP (not username/password).
          return loginInvalidCredentials;
        }
        return loginServerBusy;
      } catch (e) {
        debug.log('ELTE portal 2FA error: $e');
        // ignore: avoid_print
        print('ELTE portal 2FA error: $e');
        return loginServerBusy;
      }
    }

    /// Request email OTP (portal Login2FA GetEmail=true). Call before submitting EmailCode.
    static Future<String?> elteRequestEmailOtp() async {
      if (!_eltePortal2faPending || _elte2faKey == null || _elteAntiforgery == null) {
        return null;
      }
      try {
        final fields = <String, String>{
          'Phase': 'RequestTOTP',
          'Rendered': _elte2faRendered ?? DateTime.now().toIso8601String(),
          'NeptunCode': _elte2faNeptunCode ?? '',
          'Key': _elte2faKey!,
          'ReturnUrl': '',
          'HasTOTP': _elteHasTotp ? 'True' : 'False',
          'HasEmail': 'True',
          'CodePrefix': '',
          'TOTPCode': '',
          'GetEmail': 'true',
          '__RequestVerificationToken': _elteAntiforgery!,
        };
        final post = await _elteSend(
          'POST',
          Uri.parse('$elteNeptunBaseUrl/Account/Login2FA'),
          body: _elteFormEncode(fields),
        );
        final body = post.body;
        final token = _elteExtractAntiforgery(body);
        if (token != null) _elteAntiforgery = token;
        final prefix = RegExp(r'name="CodePrefix"[^>]*value="([^"]*)"', caseSensitive: false)
            .firstMatch(body)
            ?.group(1);
        final visible = RegExp(r'CodePrefix["\s:=\-]+(\d{3})').firstMatch(body)?.group(1);
        _elteEmailCodePrefix = (prefix != null && prefix.isNotEmpty) ? prefix : visible;
        return _elteEmailCodePrefix;
      } catch (e) {
        debug.log('ELTE request email OTP error: $e');
        return null;
      }
    }

    //
// --- 2FA
    static Future<int> validateLoginCredentialsUrl(String rawUrl, String username, String password) async {
      if(username == 'DEMO' && password == 'DEMO'){
        await storage.DataCache.setIsDemoAccount(1);
        return loginOk;
      }

      String url = rawUrl.trim();
      if (url.endsWith('/')) url = url.substring(0, url.length - 1);
      bool containsAspx = url.toLowerCase().contains('.aspx');

      String baseUrl = url.replaceAll(RegExp(r'/login(\.aspx)?$', caseSensitive: false), '');
      baseUrl = baseUrl.replaceAll(RegExp(r'/MobileService\.svc$', caseSensitive: false), '');

      if (containsAspx) {
        bool success = await _tryOldLogin(baseUrl, username, password);
        return success ? loginOk : loginInvalidCredentials;
      }

      // ELTE: portal Potlap login + HWEB OuterLogin (JWT Authenticate on portal is dead)
      if (_isElteUrl(rawUrl) || _isElteUrl(elteNeptunBaseUrl)) {
        final elteResult = await _tryEltePortalLogin(username, password);
        if (elteResult == loginOk || elteResult == loginNeeds2fa || elteResult == loginInvalidCredentials) {
          return elteResult;
        }
        // Fall through only on busy — still prefer honest busy over broken JWT 400
        if (elteResult == loginServerBusy) {
          return loginServerBusy;
        }
      }

      var sawServerBusy = false;
      for (final candidate in _modernLoginBaseCandidates(rawUrl)) {
        final result = await _tryModernLogin(candidate, username, password);
        if (result == loginOk || result == loginNeeds2fa) {
          return result;
        }
        if (result == loginInvalidCredentials) {
          // Endpoint answered clearly — stop trying aliases.
          return loginInvalidCredentials;
        }
        if (result == loginServerBusy) {
          sawServerBusy = true;
        }
      }
      return sawServerBusy ? loginServerBusy : loginInvalidCredentials;
    }

    static bool _isTwoFactorPayload(dynamic response, int statusCode) {
      if (response is! Map) return false;
      final data = response['data'];
      if (data is! Map) return false;
      if (data['isTwoFactorRequired'] == true || data['requiresTwoFactor'] == true) {
        return true;
      }
      // Neptun often answers 202 with only twoFactorLoginToken
      if (data['twoFactorLoginToken'] != null && data['accessToken'] == null) {
        return true;
      }
      return statusCode == 202 && data['twoFactorLoginToken'] != null;
    }

    /// True only when the portal/API actually reports a wrong password.
    /// Do **not** match bare substring `invalid` on full login HTML (`is-invalid` CSS, scripts).
    static bool _looksLikeInvalidCredentials(String body, int statusCode) {
      if (statusCode == 401 || statusCode == 403) return true;
      final lower = body.toLowerCase();

      // Explicit wrong-password / failed-login phrases (EN + HU).
      if (lower.contains('wrong password') ||
          lower.contains('invalid username') ||
          lower.contains('invalid password') ||
          lower.contains('invalid credentials') ||
          lower.contains('invalid user') ||
          lower.contains('username or password') ||
          lower.contains('login was unsuccessful') ||
          lower.contains('sikertelen bejelentkez') ||
          lower.contains('hibás felhasználó') ||
          lower.contains('hibas felhasznalo') ||
          lower.contains('hibás jelszó') ||
          lower.contains('hibas jelszo') ||
          lower.contains('érvénytelen felhasználó') ||
          lower.contains('ervenytelen felhasznalo') ||
          lower.contains('érvénytelen jelszó') ||
          lower.contains('ervenytelen jelszo') ||
          lower.contains('érvénytelen bejelentkez') ||
          lower.contains('ervenytelen bejelentkez')) {
        return true;
      }

      // Short JSON / plain error bodies may still say "invalid" / "hibás".
      // Full HTML login pages must not — `is-invalid` / scripts cause false positives.
      final looksLikeHtml = lower.contains('<html') ||
          lower.contains('<!doctype') ||
          lower.contains('name="loginname"') ||
          lower.contains("name='loginname'") ||
          lower.contains('__requestverificationtoken');
      if (looksLikeHtml) return false;

      return lower.contains('érvénytelen') ||
          lower.contains('ervenytelen') ||
          lower.contains('invalid') ||
          lower.contains('hibás') ||
          lower.contains('hibas');
    }

    static bool _looksLikeServerBusy(String body, int statusCode) {
      if (statusCode == 429 || statusCode == 502 || statusCode == 503 || statusCode == 504) {
        return true;
      }
      final lower = body.toLowerCase();
      return lower.contains('full') ||
          lower.contains('overload') ||
          lower.contains('too many') ||
          lower.contains('try again') ||
          lower.contains('maintenance') ||
          lower.contains('unavailable');
    }

    static Future<int> _tryModernLogin(String baseUrl, String username, String password) async {
      try {
        final modernApiUrl = Uri.parse("$baseUrl/api/Account/Authenticate");
        final body = conv.jsonEncode({
          "userName": username, "password": password,
          "captcha": "", "captchaIdentifier": "", "token": "", "LCID": AppStrings.getNeptunLcid()
        });

        // Load device cookie if exists
        final savedCookieVal = await storage.DataCache.getDeviceCookie(username);
        String? cookieHeader;
        if (savedCookieVal != null && savedCookieVal.isNotEmpty) {
          final b64 = conv.base64.encode(conv.utf8.encode(username.toUpperCase()));
          cookieHeader = 'devicecookie-$b64=$savedCookieVal';
        }

        final responseRaw = await _APIRequest.postRequestRaw(
          modernApiUrl,
          body,
          cookie: cookieHeader,
          timeout: const Duration(seconds: 20),
        );
        final rawBody = responseRaw.body.trim();
        final status = responseRaw.statusCode;

        if (rawBody.isEmpty) {
          // Empty 4xx/5xx from overloaded Neptun — not "wrong password"
          if (status >= 500 || status == 0 || status == 400 || status == 408 || status == 429) {
            return loginServerBusy;
          }
          return loginServerBusy;
        }

        if (_looksLikeServerBusy(rawBody, status)) {
          return loginServerBusy;
        }

        dynamic response;
        try {
          response = conv.jsonDecode(rawBody);
        } catch (_) {
          if (_looksLikeInvalidCredentials(rawBody, status)) {
            return loginInvalidCredentials;
          }
          return loginServerBusy;
        }

        // Extract and save cookies/tokens
        _APIRequest._extractAndSaveCookiesAndTokens(responseRaw, username);

        if (_isTwoFactorPayload(response, status)) {
          await storage.DataCache.setInstituteUrl(baseUrl);
          final tfToken = response["data"]["twoFactorLoginToken"];
          if (tfToken != null) {
            await storage.DataCache.setAccessToken(tfToken.toString());
          }
          await storage.DataCache.setIsModernApi(true);
          return loginNeeds2fa;
        }

        if (response["data"] != null && response["data"]["accessToken"] != null) {
          await storage.DataCache.setAccessToken(response["data"]["accessToken"]);
          await storage.DataCache.setIsModernApi(true);
          await storage.DataCache.setInstituteUrl(baseUrl);
          return loginOk;
        }

        // Structured error from API
        final err = response['error'] ?? response['ErrorMessage'] ?? response['message'];
        if (err != null && _looksLikeInvalidCredentials(err.toString(), status)) {
          return loginInvalidCredentials;
        }
        if (status >= 500 || _looksLikeServerBusy(rawBody, status)) {
          return loginServerBusy;
        }
        if (_looksLikeInvalidCredentials(rawBody, status)) {
          return loginInvalidCredentials;
        }
        return loginServerBusy;
      } on TimeoutException {
        return loginServerBusy;
      } catch (e) {
        return loginServerBusy;
      }
    }


    static Future<int> submitTwoFactorCode(
      String username,
      String password,
      String code, {
      void Function()? onBridging,
    }) async {
      if (_eltePortal2faPending) {
        return _submitEltePortal2fa(code, onBridging: onBridging);
      }
      try {
        String baseUrl = normalizeModernApiBaseUrl(storage.DataCache.getInstituteUrl() ?? '');
        if (baseUrl.isEmpty) return loginServerBusy;

        final url = Uri.parse("$baseUrl/api/Account/Authenticate");
        final body = conv.jsonEncode({
          "userName": username,
          "password": password,
          "captcha":"",
          "captchaIdentifier":"",
          "token": code,
          "LCID": AppStrings.getNeptunLcid()
        });

        // Load device cookie if exists
        final savedCookieVal = await storage.DataCache.getDeviceCookie(username);
        String? cookieHeader;
        if (savedCookieVal != null && savedCookieVal.isNotEmpty) {
          final b64 = conv.base64.encode(conv.utf8.encode(username.toUpperCase()));
          cookieHeader = 'devicecookie-$b64=$savedCookieVal';
        }

        final pendingTwoFactorToken = storage.DataCache.getAccessToken();
        final responseRaw = await _APIRequest.postRequestRaw(
          url,
          body,
          cookie: cookieHeader,
          bearerToken: (pendingTwoFactorToken != null && pendingTwoFactorToken.isNotEmpty)
              ? pendingTwoFactorToken
              : null,
          timeout: const Duration(seconds: 35),
        );
        final rawBody = responseRaw.body.trim();
        if (rawBody.isEmpty) return loginServerBusy;

        final response = conv.jsonDecode(rawBody);

        // Extract and save cookies/tokens
        _APIRequest._extractAndSaveCookiesAndTokens(responseRaw, username);

        if (response["data"] != null && response["data"]["accessToken"] != null) {
          await storage.DataCache.setAccessToken(response["data"]["accessToken"]);
          await storage.DataCache.setIsModernApi(true);
          await storage.DataCache.setInstituteUrl(baseUrl);
          return loginOk;
        }
        if (_looksLikeInvalidCredentials(rawBody, responseRaw.statusCode)) {
          return loginInvalidCredentials;
        }
      } catch (e) { }
      return loginServerBusy;
    }
    static Future<bool> _tryOldLogin(String baseUrl, String username, String password) async {
      try {
        final oldApiUrl = Uri.parse("$baseUrl/MobileService.svc" + URLs.TRAININGS_URL);
        final request = await _APIRequest.postRequest(
            oldApiUrl,
            _APIRequest.getGenericPostData(username, password)
        );

        if (request.trim().startsWith('{')) {
          final decodedResponse = conv.json.decode(request);
          if (decodedResponse["ErrorMessage"] == null) {
            await storage.DataCache.setIsModernApi(false);
            await storage.DataCache.setInstituteUrl("$baseUrl/MobileService.svc");
            return true;
          }
        }
      } catch (e) { }
      return false;
    }

    /// Monday on or before [day] (study-week aligned).
    static DateTime mondayOnOrBefore(DateTime day) {
      final dayOnly = DateTime(day.year, day.month, day.day);
      return dayOnly.subtract(Duration(days: dayOnly.weekday - DateTime.monday));
    }

    /// Conventional week-1 Monday for a semester season (autumn ≈ Sep 1, spring ≈ Feb 1).
    static DateTime semesterSeasonWeekOneMonday(DateTime ref) {
      final month = ref.month;
      if (month >= 1 && month <= 6) {
        return mondayOnOrBefore(DateTime(ref.year, 2, 1));
      }
      return mondayOnOrBefore(DateTime(ref.year, 9, 1));
    }

    static Future<int?> getFirstStudyweek({String? termId}) async{
      if(storage.DataCache.getIsDemoAccount()!){
        return mondayOnOrBefore(DateTime(2024, 9, 1)).millisecondsSinceEpoch;
      }

      final periods = await PeriodsRequest.getPeriods(termId: termId);
      final nowDt = DateTime.now();
      final now = nowDt.millisecondsSinceEpoch;
      final seasonFallback = semesterSeasonWeekOneMonday(nowDt);

      if(periods == null || periods.isEmpty){
        return seasonFallback.millisecondsSinceEpoch;
      }

      bool isStudyPeriod(String raw) {
        final name = raw.toLowerCase();
        return name.contains('szorgalmi') ||
            name.contains('oktatási időszak') ||
            name.contains('oktatasi idoszak') ||
            name.contains('oktatási') ||
            name.contains('study period') ||
            name.contains('teaching period') ||
            name.contains('instruction period') ||
            name.contains('term time');
      }

      // Prefer study/teaching period only. Subject-registration / login windows
      // (végleges tárgyjelentkezés, bejelentkezési) often start weeks/months earlier
      // and must NOT anchor week 1 (produced ~36 then ~16 education weeks).
      final studyPeriods = periods.where((p) => isStudyPeriod(p.name)).toList();

      PeriodEntry? pickLatestStarted(Iterable<PeriodEntry> candidates) {
        PeriodEntry? best;
        for (final item in candidates) {
          if (best == null || item.startEpoch > best.startEpoch) {
            best = item;
          }
        }
        return best;
      }

      PeriodEntry? pickEarliest(Iterable<PeriodEntry> candidates) {
        PeriodEntry? best;
        for (final item in candidates) {
          if (best == null || item.startEpoch < best.startEpoch) {
            best = item;
          }
        }
        return best;
      }

      PeriodEntry? period;
      final active = studyPeriods.where((p) => p.startEpoch <= now && now <= p.endEpoch);
      period = pickLatestStarted(active);

      if (period == null) {
        final inThirtyDays = now + const Duration(days: 30).inMilliseconds;
        final upcoming = studyPeriods.where((p) => p.startEpoch > now && p.startEpoch <= inThirtyDays);
        period = pickEarliest(upcoming);
      }

      if (period == null) {
        final oldestOk = now - const Duration(days: 140).inMilliseconds;
        final recent = studyPeriods.where((p) => p.startEpoch <= now && p.startEpoch >= oldestOk);
        period = pickLatestStarted(recent);
      }

      DateTime anchor = seasonFallback;
      if (period != null) {
        final studyStart = DateTime.fromMillisecondsSinceEpoch(period.startEpoch);
        final studyMonday = mondayOnOrBefore(studyStart);
        final seasonMonday = semesterSeasonWeekOneMonday(studyStart);
        // Education week 1 = calendar week containing Sep 1 / Feb 1 when teaching
        // starts in that same fortnight (ELTE autumn 2026: Sep 1 week = 1, Sep 7 week = 2).
        if ((studyMonday.difference(seasonMonday).inDays).abs() <= 14) {
          anchor = studyMonday.isBefore(seasonMonday) ? studyMonday : seasonMonday;
        } else {
          anchor = studyMonday;
        }
      }

      return anchor.millisecondsSinceEpoch;
    }
  }

class CalendarRequest {
  static List<String>? _cachedTrainingIds;

  /// True for GUID / pure numeric / digit-heavy IDs — not human training titles.
  static bool _looksLikeRawId(String? value) {
    if (value == null) return true;
    final t = value.trim();
    if (t.isEmpty) return true;
    if (RegExp(r'^\d+$').hasMatch(t)) return true;
    if (RegExp(r'^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$').hasMatch(t)) {
      return true;
    }
    // Long digit/hyphen blobs (training ids without dashes, etc.)
    if (t.length >= 10 && RegExp(r'^[\d\-]+$').hasMatch(t)) return true;
    return false;
  }

  static Future<void> _persistUserInfoProfile(Map data) async {
    final first = data['firstName']?.toString() ?? data['FirstName']?.toString() ?? '';
    final last = data['lastName']?.toString() ?? data['LastName']?.toString() ?? '';
    final printName = data['printName']?.toString() ??
        data['fullName']?.toString() ??
        data['name']?.toString() ??
        '';
    final display = printName.isNotEmpty
        ? printName
        : [last, first].where((s) => s.isNotEmpty).join(' ').trim();
    if (display.isNotEmpty) {
      await storage.DataCache.setStudentDisplayName(display);
    }
    final training = data['trainingName']?.toString() ??
        data['studentTrainingName']?.toString() ??
        data['facultyName']?.toString() ??
        '';
    // Never persist raw studentTrainingId / GUID as the training "name".
    if (training.isNotEmpty && !_looksLikeRawId(training)) {
      await storage.DataCache.setStudentTrainingName(training);
    }
    // Nested userAvatar.image is base64 JPEG (ELTE HWEB HAR).
    final avatar = data['userAvatar'];
    if (avatar is Map) {
      final img = avatar['image']?.toString();
      if (img != null && img.isNotEmpty) {
        await storage.DataCache.setStudentAvatarBase64(img);
      }
    }
  }

  /// Fetch higher-res drawer avatar from HWEB (`/api/General/GetUserAvatar`).
  /// Falls back to thumbnail already cached from `/api/UserInfo`.
  static Future<Uint8List?> fetchUserAvatarBytes({bool forceNetwork = false}) async {
    if (!(storage.DataCache.getIsModernApi())) return null;

    Uint8List? decodeCached() {
      final b64 = storage.DataCache.getStudentAvatarBase64();
      if (b64 == null || b64.isEmpty) return null;
      try {
        return conv.base64Decode(b64.replaceAll(RegExp(r'\s'), ''));
      } catch (_) {
        return null;
      }
    }

    if (!forceNetwork) {
      final cached = decodeCached();
      if (cached != null && cached.length > 64) return cached;
    }

    try {
      final token = storage.DataCache.getAccessToken();
      if (token == null || token.isEmpty) return decodeCached();
      final baseUrl = storage.DataCache.getInstituteUrl() ?? '';
      if (baseUrl.isEmpty) return decodeCached();

      final url = Uri.parse('$baseUrl/api/General/GetUserAvatar?imageSizeType=Normal');
      final raw = await _APIRequest.getRequest(url, bearerToken: token);
      final decoded = conv.json.decode(raw);
      Map? payload;
      if (decoded is Map) {
        if (decoded['data'] is Map) {
          payload = decoded['data'] as Map;
        } else if (decoded['image'] != null) {
          payload = decoded;
        }
      }
      final img = payload?['image']?.toString();
      if (img != null && img.isNotEmpty) {
        await storage.DataCache.setStudentAvatarBase64(img);
        try {
          return conv.base64Decode(img.replaceAll(RegExp(r'\s'), ''));
        } catch (e) {
          debug.log('fetchUserAvatarBytes decode: $e');
        }
      }
    } catch (e) {
      debug.log('fetchUserAvatarBytes: $e');
    }
    return decodeCached();
  }

  static void clearTrainingIdCache() {
    _cachedTrainingIds = null;
  }

  static Future<void> refreshUserProfile() async {
    if (!(storage.DataCache.getIsModernApi())) return;
    try {
      final token = await storage.DataCache.getAccessToken();
      if (token == null || token.isEmpty) return;
      final baseUrl = storage.DataCache.getInstituteUrl() ?? '';
      final uInfoUrl = Uri.parse("$baseUrl/api/UserInfo");
      final uInfoRaw = await _APIRequest.getRequest(uInfoUrl, bearerToken: token);
      final uInfoDecoded = conv.json.decode(uInfoRaw);
      if (uInfoDecoded['data'] is Map) {
        await _persistUserInfoProfile(Map<String, dynamic>.from(uInfoDecoded['data'] as Map));
      }
    } catch (e) {
      debug.log('refreshUserProfile: $e');
    }
  }

  static Future<List<String>> getStudentTrainingIds({bool forceRefresh = false}) async {
    if (forceRefresh) {
      _cachedTrainingIds = null;
    }
    if (_cachedTrainingIds != null && _cachedTrainingIds!.isNotEmpty) return _cachedTrainingIds!;
    if (!(storage.DataCache.getIsModernApi())) return [];

    final storedId = storage.DataCache.getStudentTrainingId();
    if (!forceRefresh && storedId != null && storedId.isNotEmpty) {
      _cachedTrainingIds = [storedId];
      return _cachedTrainingIds!;
    }

    try {
      final token = await storage.DataCache.getAccessToken();
      if (token == null || token.isEmpty) return [];
      String baseUrl = storage.DataCache.getInstituteUrl() ?? '';

      // Tier 1: /api/Calendar/GetStudentTrainings
      try {
        final url = Uri.parse("$baseUrl/api/Calendar/GetStudentTrainings");
        final responseRaw = await _APIRequest.getRequest(url, bearerToken: token);
        final decoded = conv.json.decode(responseRaw);

        List<String> ids = [];
        final trainingLabels = <String, String>{};
        if (decoded['data'] != null && decoded['data'] is List) {
          for (var training in decoded['data']) {
            final tid = training['studentTrainingId']?.toString();
            if (tid != null && tid.isNotEmpty && !ids.contains(tid)) {
              final rawLabel = training['trainingName']?.toString() ??
                  training['name']?.toString() ??
                  training['facultyName']?.toString() ??
                  training['trainingCode']?.toString() ??
                  '';
              // Prefer a human title; never fall back to raw studentTrainingId digits/GUID.
              final label = (rawLabel.isNotEmpty && !_looksLikeRawId(rawLabel))
                  ? rawLabel
                  : AppStrings.getLanguagePack().topmenu_TrainingSelectorTitle;
              trainingLabels[tid] = label;
              if (training['actualStudentTraining'] == true) {
                ids.insert(0, tid);
              } else {
                ids.add(tid);
              }
            }
          }
        }
        if (ids.isNotEmpty) {
          _cachedTrainingIds = ids;
          final preferred = storage.DataCache.getStudentTrainingId();
          final chosen = (preferred != null && ids.contains(preferred)) ? preferred : ids.first;
          await storage.DataCache.setStudentTrainingId(chosen);
          await storage.DataCache.setTrainingLabelsJson(conv.jsonEncode(trainingLabels));
          final chosenLabel = trainingLabels[chosen];
          if (chosenLabel != null && !_looksLikeRawId(chosenLabel) && chosenLabel != AppStrings.getLanguagePack().topmenu_TrainingSelectorTitle && chosenLabel != 'Training') {
            await storage.DataCache.setStudentTrainingName(chosenLabel);
          }
          // Also refresh UserInfo profile in background shape
          return ids;
        }
      } catch (e) {
        debug.log("Hiba a GetStudentTrainings lekérésekor: $e");
      }

      // Tier 2: /api/UserInfo
      try {
        final uInfoUrl = Uri.parse("$baseUrl/api/UserInfo");
        final uInfoRaw = await _APIRequest.getRequest(uInfoUrl, bearerToken: token);
        final uInfoDecoded = conv.json.decode(uInfoRaw);
        if (uInfoDecoded['data'] != null) {
          final d = uInfoDecoded['data'];
          if (d is Map) {
            await _persistUserInfoProfile(d);
            final tid = d['studentTrainingId']?.toString();
            if (tid != null && tid.isNotEmpty) {
              _cachedTrainingIds = [tid];
              await storage.DataCache.setStudentTrainingId(tid);
              return [tid];
            }
          }
        }
      } catch (e) {
        debug.log("Hiba a UserInfo lekérésekor: $e");
      }

      // Tier 3: /api/ContextUserProfile/MyTrainings
      try {
        final myTrainingsUrl = Uri.parse("$baseUrl/api/ContextUserProfile/MyTrainings");
        final myTrainingsRaw = await _APIRequest.getRequest(myTrainingsUrl, bearerToken: token);
        final myTrainingsDecoded = conv.json.decode(myTrainingsRaw);
        List<String> ids = [];
        if (myTrainingsDecoded['data'] != null && myTrainingsDecoded['data'] is List) {
          for (var training in myTrainingsDecoded['data']) {
            final tid = training['studentTrainingId']?.toString();
            if (tid != null && tid.isNotEmpty && !ids.contains(tid)) {
              ids.add(tid);
            }
          }
        }
        if (ids.isNotEmpty) {
          _cachedTrainingIds = ids;
          await storage.DataCache.setStudentTrainingId(ids.first);
          return ids;
        }
      } catch (e) {
        debug.log("Hiba a MyTrainings lekérésekor: $e");
      }

    } catch (e) {
      debug.log("Hiba a student trainings lekérésekor: $e");
    }

    if (storedId != null && storedId.isNotEmpty) {
      return [storedId];
    }
    return [];
  }

  static Future<String?> getStudentTrainingId({bool forceRefresh = false}) async {
    final ids = await getStudentTrainingIds(forceRefresh: forceRefresh);
    if (ids.isEmpty) return null;
    final preferred = storage.DataCache.getStudentTrainingId();
    if (preferred != null && ids.contains(preferred)) return preferred;
    return ids.first;
  }

  static List<CalendarEntry> getCalendarEntriesFromJSON(String jsonString) {
    if (jsonString == '{}' || jsonString.isEmpty) return [];
    try {
      final decoded = conv.json.decode(jsonString);
      List<CalendarEntry> list = [];
      if (storage.DataCache.getIsModernApi()) {
        if (decoded is Map && decoded['calendarData'] != null && decoded['calendarData'] is List) {
          for (var item in decoded['calendarData']) {
            if (item is! Map) continue;
            int startMs = item['start_ms'] is int ? item['start_ms'] : int.tryParse(item['start_ms']?.toString() ?? '0') ?? 0;
            int endMs = item['end_ms'] is int ? item['end_ms'] : int.tryParse(item['end_ms']?.toString() ?? '0') ?? 0;
            int eventType = item['type'] is int ? item['type'] : int.tryParse(item['type']?.toString() ?? '0') ?? 0;

            list.add(CalendarEntry.fromModern(
              startEpoch: startMs,
              endEpoch: endMs,
              location: item['location']?.toString() ?? AppStrings.getLanguagePack().courseDetail_NotSpecified,
              title: item['title']?.toString() ?? AppStrings.getLanguagePack().api_fallback_NoTitle,
              eventType: eventType,
              subjectCode: item['subjectCode']?.toString() ?? '-',
              courseType: item['courseType']?.toString(),
              teacher: item['teacher']?.toString() ?? AppStrings.getLanguagePack().courseDetail_NotSpecified,
              classInstanceId: item['classInstanceId']?.toString(),
              taskId: item['taskId']?.toString(),
            ));
          }
        }
        return list;
      }

      if (decoded['calendarData'] != null && decoded['calendarData'] is List) {
        for (var item in decoded['calendarData']) {
          String rawStart = item['start']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '';
          String rawEnd = item['end']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '';

          list.add(CalendarEntry(
            rawStart.isEmpty ? '0' : rawStart,
            rawEnd.isEmpty ? '0' : rawEnd,
            item['location'] ?? AppStrings.getLanguagePack().courseDetail_NotSpecified,
            item['title'] ?? AppStrings.getLanguagePack().api_fallback_NoTitle,
            item['type'] == 1,
          ));
        }
      }
      return list;
    } catch (e) {
      debug.log("Hiba a naptár JSON feldolgozásakor: $e");
      return [];
    }
  }

  static Future<String> makeCalendarRequest(String calendarJson) async {
    if (storage.DataCache.getIsDemoAccount()! || storage.DataCache.getHasICSFile()!) {
      return '{}';
    }

    if (storage.DataCache.getIsModernApi()) {
      try {
        final oldPayload = conv.json.decode(calendarJson);
        final startDateRaw = (oldPayload['startDate'] ?? oldPayload['StartDate']).toString();
        final endDateRaw = (oldPayload['endDate'] ?? oldPayload['EndDate']).toString();

        final numRegex = RegExp(r'\d+');
        final startEpoch = int.parse(numRegex.firstMatch(startDateRaw)!.group(0)!);
        final endEpoch = int.parse(numRegex.firstMatch(endDateRaw)!.group(0)!);

        // Use payload Sunday end — NOT next Monday 23:59 (that pulled next week's
        // Monday classes into this week → fake ~163h "break" + duplicate lessons).
        final startDate = DateTime.fromMillisecondsSinceEpoch(startEpoch);
        final endDate = DateTime.fromMillisecondsSinceEpoch(endEpoch);

        final startIso = "${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}T00:00:00.000";
        final endIso = "${endDate.year.toString().padLeft(4, '0')}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}T23:59:59.999";

        String baseUrl = storage.DataCache.getInstituteUrl() ?? '';
        String responseRaw = "";
        bool needsReAuth = false;

        bool dispClasses = storage.DataCache.getDisplayClasses() ?? true;
        bool dispExams = storage.DataCache.getDisplayExams() ?? true;
        bool dispPeriods = storage.DataCache.getDisplayPeriods() ?? true;

        List<String> trainingIds = await getStudentTrainingIds(forceRefresh: false);
        final token = await storage.DataCache.getAccessToken();

        if (token != null && token.isNotEmpty) {
          final baseUri = Uri.parse(baseUrl);
          final cleanBasePath = baseUri.path.endsWith('/') ? baseUri.path.substring(0, baseUri.path.length - 1) : baseUri.path;
          final calendarPath = '$cleanBasePath/api/Calendar/GetCalendarEvents'.replaceAll('//', '/');

          Map<String, String> queryParams = {
            'startDate': startIso,
            'endDate': endIso,
            'isClassesVisible': dispClasses.toString(),
            'isExamsVisible': dispExams.toString(),
            'isFinalExamsVisible': 'true',
            'isOnlineMeetingsVisible': 'true',
            'isOtherEventsVisible': 'true',
            'isPeriodsVisible': dispPeriods.toString(),
            'isTasksVisible': 'true',
          };
          for (int i = 0; i < trainingIds.length; i++) {
            queryParams['studentTrainingIds[$i]'] = trainingIds[i];
          }

          final url = baseUri.replace(path: calendarPath, queryParameters: queryParams);
          debug.log("Naptár kérés küldése: $url");

          responseRaw = await _APIRequest.getRequest(url, bearerToken: token);

          if (responseRaw.contains('"statusCode":410') || 
              responseRaw.contains('Authorization has been denied') || 
              responseRaw.contains('"statusCode": 401') || 
              responseRaw.contains('"statusCode":401') ||
              responseRaw.contains('A megadott kérelem nem engedélyezett') ||
              responseRaw.contains('Unauthorized')) {
            needsReAuth = true;
          }
        } else {
          needsReAuth = true;
        }

        if (needsReAuth) {
          debug.log("Naptár: Lejárt token/ID érzékelve. Session recovery...");
          final recovered = await _APIRequest.ensureValidSession();
          if (!recovered) {
            return '{"calendarData": []}';
          }

          final newTrainingIds = await getStudentTrainingIds(forceRefresh: true);
          final newToken = await storage.DataCache.getAccessToken();

          if (newToken != null && newToken.isNotEmpty) {
            final baseUri = Uri.parse(baseUrl);
            final cleanBasePath = baseUri.path.endsWith('/') ? baseUri.path.substring(0, baseUri.path.length - 1) : baseUri.path;
            final calendarPath = '$cleanBasePath/api/Calendar/GetCalendarEvents'.replaceAll('//', '/');

            Map<String, String> queryParams = {
              'startDate': startIso,
              'endDate': endIso,
              'isClassesVisible': dispClasses.toString(),
              'isExamsVisible': dispExams.toString(),
              'isFinalExamsVisible': 'true',
              'isOnlineMeetingsVisible': 'true',
              'isOtherEventsVisible': 'true',
              'isPeriodsVisible': dispPeriods.toString(),
              'isTasksVisible': 'true',
            };
            for (int i = 0; i < newTrainingIds.length; i++) {
              queryParams['studentTrainingIds[$i]'] = newTrainingIds[i];
            }

            final retryUrl = baseUri.replace(path: calendarPath, queryParameters: queryParams);
            responseRaw = await _APIRequest.getRequest(retryUrl, bearerToken: newToken);
          }
        }

        // Fallback ha studentTrainingIds-szel 400-at vagy üreset adna vissza
        if ((responseRaw.contains('400') || responseRaw.isEmpty || responseRaw == '{"data":[]}' || responseRaw == '{"data":null}') && token != null) {
          final baseUri = Uri.parse(baseUrl);
          final cleanBasePath = baseUri.path.endsWith('/') ? baseUri.path.substring(0, baseUri.path.length - 1) : baseUri.path;
          final calendarPath = '$cleanBasePath/api/Calendar/GetCalendarEvents'.replaceAll('//', '/');

          Map<String, String> fallbackParams = {
            'startDate': startIso,
            'endDate': endIso,
            'isClassesVisible': dispClasses.toString(),
            'isExamsVisible': dispExams.toString(),
            'isFinalExamsVisible': 'true',
            'isOnlineMeetingsVisible': 'true',
            'isOtherEventsVisible': 'true',
            'isPeriodsVisible': dispPeriods.toString(),
            'isTasksVisible': 'true',
          };
          final fallbackUrl = baseUri.replace(path: calendarPath, queryParameters: fallbackParams);
          final fbRaw = await _APIRequest.getRequest(fallbackUrl, bearerToken: token);
          if (fbRaw.isNotEmpty && !fbRaw.contains('400') && !fbRaw.contains('Error')) {
            responseRaw = fbRaw;
          }
        }

        final newApiData = conv.json.decode(responseRaw);
        List<Map<String, dynamic>> mappedList = [];

        if (newApiData is Map && newApiData['data'] != null) {
          var dataPart = newApiData['data'];
          Iterable items = dataPart is List ? dataPart : [dataPart];

          for (var event in items) {
            if (event is! Map) continue;
            final typeId = event['eventTypeId'] ?? 0;
            // typeId 6 = institutional period banner — keep as calendar entry (eventType 6)
            // so UI can show period banners; weekly class buckets still filter via isExam/isTask.

            final startStr = event['startDate']?.toString();
            final endStr = event['endDate']?.toString();
            if (startStr == null || endStr == null) continue;

            final eventStartEpoch = DateTime.tryParse(startStr)?.millisecondsSinceEpoch ?? 0;
            final eventEndEpoch = DateTime.tryParse(endStr)?.millisecondsSinceEpoch ?? 0;

            // Drop events outside the requested Mon–Sun window (defense if API is inclusive of next Monday).
            if (eventStartEpoch < startEpoch || eventStartEpoch > endEpoch) continue;

            final subjectCode = event['courseCode'] ?? event['subjectCode'] ?? '-';
            final courseType = event['courseTypeName'] ?? event['courseType'] ?? event['typeName'] ?? event['type'] ?? '';

            mappedList.add({
              'start_ms': eventStartEpoch,
              'end_ms': eventEndEpoch,
              'location': event['rooms'] ?? event['room'] ?? event['location'] ?? AppStrings.getLanguagePack().courseDetail_NotSpecified,
              'title': event['name'] ?? event['subjectName'] ?? event['title'] ?? AppStrings.getLanguagePack().api_fallback_Unknown,
              'type': typeId,
              'subjectCode': subjectCode,
              'courseType': courseType.toString(),
              'teacher': event['courseTutor'] ?? event['teacher'] ?? AppStrings.getLanguagePack().courseDetail_NotSpecified,
              'classInstanceId': event['classInstanceId']?.toString() ?? '',
              'taskId': event['id']?.toString() ?? event['taskId']?.toString() ?? event['midTermTaskId']?.toString() ?? '',
            });
          }
        }
        return conv.jsonEncode({"calendarData": mappedList});

      } catch (e) {
        debug.log("Naptár lekérési hiba: $e");
        return '{"calendarData": []}';
      }
    } else {
      final url = Uri.parse(storage.DataCache.getInstituteUrl()! + URLs.CALENDAR_URL);
      final request = await _APIRequest.postRequest(url, calendarJson);
      return request;
    }
  }


  static Future<Map<String, String>> getCourseDetails(String classInstanceId) async {
    final lang = AppStrings.getLanguagePack();
    if (storage.DataCache.getIsModernApi() != true) {
      return {"room": lang.courseDetail_OldApiUnsupported, "teacher": lang.courseDetail_Unsupported, "type": "", "code": ""};
    }

    final cachedRoom = await storage.getString('room_$classInstanceId');
    final cachedTeacher = await storage.getString('teacher_$classInstanceId');
    final cachedType = await storage.getString('type_$classInstanceId');
    final cachedCode = await storage.getString('code_$classInstanceId');

    if (!(storage.DataCache.getHasNetwork())) {
      if (cachedRoom != null) {
        return {
          "room": AppStrings.localizeCourseDetailValue(cachedRoom, placeholder: (l) => l.courseDetail_NoRoom),
          "teacher": AppStrings.localizeCourseDetailValue(cachedTeacher, placeholder: (l) => l.courseDetail_NoTeacher),
          "type": cachedType ?? "",
          "code": cachedCode ?? "",
        };
      }
      return {"room": lang.courseDetail_NoInternet, "teacher": lang.courseDetail_OfflineMode, "type": "", "code": ""};
    }

    try {
      final token = await storage.DataCache.getAccessToken();
      String baseUrl = storage.DataCache.getInstituteUrl() ?? '';

      final url = Uri.parse("$baseUrl/api/Calendar/GetCourseDetails?classInstanceId=$classInstanceId&webexMeetingId=null");
      final responseRaw = await _APIRequest.getRequest(url, bearerToken: token!);
      final decoded = conv.json.decode(responseRaw);

      if (decoded['data'] != null) {
        final d = decoded['data'];
        final rRaw = d['room']?.toString() ?? d['rooms']?.toString() ?? '';
        final tRaw = d['courseTutor']?.toString() ?? d['tutor']?.toString() ?? d['teacher']?.toString() ?? '';
        final r = rRaw.trim().isEmpty ? lang.courseDetail_NoRoom : rRaw;
        final t = tRaw.trim().isEmpty ? lang.courseDetail_NoTeacher : tRaw;
        final type = d['courseTypeName']?.toString() ?? d['courseType']?.toString() ?? d['typeName']?.toString() ?? d['type']?.toString() ?? "";
        final code = d['subjectCode']?.toString() ?? d['courseCode']?.toString() ?? "";

        await storage.saveString('room_$classInstanceId', r);
        await storage.saveString('teacher_$classInstanceId', t);
        if (type.isNotEmpty) await storage.saveString('type_$classInstanceId', type);
        if (code.isNotEmpty) await storage.saveString('code_$classInstanceId', code);

        return {"room": r, "teacher": t, "type": type, "code": code};
      }
    } catch (e) {
      debug.log("Hiba az óra részleteinek lekérésekor: $e");
    }

    if (cachedRoom != null) {
      return {
        "room": AppStrings.localizeCourseDetailValue(cachedRoom, placeholder: (l) => l.courseDetail_NoRoom),
        "teacher": AppStrings.localizeCourseDetailValue(cachedTeacher, placeholder: (l) => l.courseDetail_NoTeacher),
        "type": cachedType ?? "",
        "code": cachedCode ?? "",
      };
    }

    return {"room": lang.courseDetail_LoadError, "teacher": lang.courseDetail_LoadError, "type": "", "code": ""};
  }


  //missing details definition. pulls class location and uh... idk just fills the class
  static Future<void> fillMissingDetails(List<CalendarEntry> entries, Function onUpdate) async {
    bool hasNetwork = storage.DataCache.getHasNetwork();
    String? token;
    String baseUrl = '';

    if (hasNetwork) {
      token = await storage.DataCache.getAccessToken();
      baseUrl = storage.DataCache.getInstituteUrl() ?? '';
    }

    bool didUpdateUI = false;
    // Régi: for (var entry in entries) {
    for (var entry in entries.toList()) {
      if (entry.isTask && entry.taskId != null && entry.taskId!.isNotEmpty) {
        final cachedSubject = await storage.getString('task_sub_${entry.taskId}');


        if (cachedSubject != null && cachedSubject.isNotEmpty) {
          if (entry.location != cachedSubject) {
            entry.location = cachedSubject;
            didUpdateUI = true;
          }
          continue;
        }

        if (hasNetwork && token != null) {
          try {
            final url = Uri.parse("$baseUrl/api/Tasks/GetTaskDetail?midtermTaskId=${entry.taskId}");
            final responseRaw = await _APIRequest.getRequest(url, bearerToken: token);
            final decoded = conv.json.decode(responseRaw);

            if (decoded['data'] != null) {
              final subject = decoded['data']['subjectName'] ?? AppStrings.getLanguagePack().api_fallback_UnknownSubject;
              final type = decoded['data']['midtermTaskType'] ?? AppStrings.getLanguagePack().api_fallback_Task;
              final result = decoded['data']['midtermResult'] ?? AppStrings.getLanguagePack().api_fallback_NoResult;

              entry.location = subject;
              didUpdateUI = true;


              await storage.saveString('task_sub_${entry.taskId}', subject);
              await storage.saveString('task_type_${entry.taskId}', type);
              await storage.saveString('task_res_${entry.taskId}', result);

              onUpdate();
            }
          } catch(e) {}
          await Future.delayed(const Duration(milliseconds: 75));
        }
        continue;
      }
      if (entry.classInstanceId == null || entry.classInstanceId!.isEmpty) continue;

      final cachedRoom = await storage.getString('room_${entry.classInstanceId}');
      final cachedTeacher = await storage.getString('teacher_${entry.classInstanceId}');

      if (cachedRoom != null && cachedRoom.isNotEmpty && !AppStrings.isMissingRoomValue(cachedRoom)) {
        if (entry.location != cachedRoom || entry.teacher != cachedTeacher) {
          entry.location = cachedRoom;
          entry.teacher = AppStrings.localizeCourseDetailValue(cachedTeacher, placeholder: (l) => l.courseDetail_NoTeacher);
          didUpdateUI = true;
        }
        continue;
      }

      if (hasNetwork && token != null) {
        try {
          final url = Uri.parse("$baseUrl/api/Calendar/GetCourseDetails?classInstanceId=${entry.classInstanceId}&webexMeetingId=null");
          final responseRaw = await _APIRequest.getRequest(url, bearerToken: token);
          final decoded = conv.json.decode(responseRaw);

          if (decoded['data'] != null) {
            final lang = AppStrings.getLanguagePack();
            final r = decoded['data']['room'];
            final finalRoom = (r == null || r.toString().trim().isEmpty) ? lang.courseDetail_NoRoom : r.toString();
            final tRaw = decoded['data']['courseTutor']?.toString() ?? '';
            final t = tRaw.trim().isEmpty ? lang.courseDetail_NoTeacher : tRaw;

            entry.location = finalRoom;
            entry.teacher = t;
            didUpdateUI = true;

            await storage.saveString('room_${entry.classInstanceId}', finalRoom);
            await storage.saveString('teacher_${entry.classInstanceId}', t);

            onUpdate();
          }
        } catch(e) {}

        await Future.delayed(const Duration(milliseconds: 300));
      }
    }

    if (didUpdateUI) {
      onUpdate();
    }
  }

    static String getCalendarOneWeekJSON(String username, String password, int weekOffset, {String? termId}){
      if(storage.DataCache.getIsDemoAccount()!){
        return '';
      }
      final DateTime now = DateTime.now();
      final mondayThisWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
      final int deltaWeeks = weekOffset - 1;

      final targetMonday = mondayThisWeek.add(Duration(days: deltaWeeks * 7));
      final targetSunday = targetMonday.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59, milliseconds: 999));

      final epochStart = targetMonday.millisecondsSinceEpoch;
      final epochEnd = targetSunday.millisecondsSinceEpoch;

      final activeTermId = termId ?? storage.DataCache.getSelectedTermId();
      final termInt = int.tryParse(activeTermId ?? '0') ?? 0;

      return
        '{'
          '"UserLogin":"$username",'
          '"Password":"$password",'
          '"Time":true,'
          '"Exam":true,'
          '"startDate":"/Date($epochStart)/",'
          '"endDate":"/Date($epochEnd)/",'
          '"TotalRowCount":-1,'
          '"filter":{"TermID":$termInt}'
        '}';
    }
  }

class MarkbookRequest{
  static Future<List<Subject>?> getMarkbookSubjects({String? termId}) async{
    if(storage.DataCache.getIsDemoAccount()!){
      return <Subject>[
        Subject(false, 1, AppStrings.getLanguagePack().api_demo_Subject1, 0, 4, 0),
        Subject(true, 4, AppStrings.getLanguagePack().api_demo_GhostGrade, 1, 0, 0),
      ];
    }
    else if(storage.DataCache.getHasICSFile() ?? false){ return []; }

    final activeTermId = termId ?? storage.DataCache.getSelectedTermId();

    // --- MODERN API ÁG (Közvetlen és gyors feldolgozás) ---
    if (storage.DataCache.getIsModernApi()) {
      try {
        final token = await storage.DataCache.getAccessToken();
        String baseUrl = storage.DataCache.getInstituteUrl() ?? '';

        // 1. Resolve term GUID
        List<Term> terms = await TermsRequest.getTerms();
        String effectiveTermGuid = '';

        if (activeTermId != null && activeTermId.isNotEmpty) {
          for (var t in terms) {
            if (t.id == activeTermId || t.termName == activeTermId || t.termName == storage.DataCache.getSelectedTermName()) {
              effectiveTermGuid = t.id;
              break;
            }
          }
          if (effectiveTermGuid.isEmpty && activeTermId.contains('-') && activeTermId.length > 20) {
            effectiveTermGuid = activeTermId;
          }
        }

        if (effectiveTermGuid.isEmpty && terms.isNotEmpty) {
          effectiveTermGuid = terms.last.id;
        }

        // 2. Felvett tárgyak és kurzusok lekérése
        dynamic rawData;

        // A) Próbálkozás a TakenSubjects végponttal
        String subjectsUrlStr = "$baseUrl/api/TakenSubjects?sortAndPage.firstRow=0&sortAndPage.lastRow=100&sortAndPage.subjectName=asc";
        if (effectiveTermGuid.isNotEmpty) {
          subjectsUrlStr = "$baseUrl/api/TakenSubjects?request.termId=$effectiveTermGuid&sortAndPage.firstRow=0&sortAndPage.lastRow=100&sortAndPage.subjectName=asc";
        }
        try {
          final subjectsUrl = Uri.parse(subjectsUrlStr);
          final subjectsResponse = await _APIRequest.getRequest(subjectsUrl, bearerToken: token!);
          final subjectsDecoded = conv.json.decode(subjectsResponse);
          if (subjectsDecoded['data'] != null && subjectsDecoded['data'] is List && (subjectsDecoded['data'] as List).isNotEmpty) {
            rawData = subjectsDecoded['data'];
          }
        } catch (_) {}

        // B) Ha a TakenSubjects üres, próbálkozás a RegisteredCourses végponttal (Felvett kurzusok)
        if (rawData == null || (rawData is List && rawData.isEmpty)) {
          String regUrlStr = "$baseUrl/api/RegisteredCourses/GetRegisteredCourses?sortAndPage.subjectName=asc";
          if (effectiveTermGuid.isNotEmpty) {
            regUrlStr = "$baseUrl/api/RegisteredCourses/GetRegisteredCourses?request.termId=$effectiveTermGuid&sortAndPage.subjectName=asc";
          }
          try {
            final regUrl = Uri.parse(regUrlStr);
            final regResponse = await _APIRequest.getRequest(regUrl, bearerToken: token!);
            final regDecoded = conv.json.decode(regResponse);
            if (regDecoded['data'] != null && regDecoded['data'] is List && (regDecoded['data'] as List).isNotEmpty) {
              rawData = regDecoded['data'];
            }
          } catch (_) {}
        }

        // C) Tartalék: TakenSubjects félév-szűrés nélkül
        if (rawData == null || (rawData is List && rawData.isEmpty)) {
          try {
            final fallbackUrl = Uri.parse("$baseUrl/api/TakenSubjects?sortAndPage.firstRow=0&sortAndPage.lastRow=100&sortAndPage.subjectName=asc");
            final fallbackRes = await _APIRequest.getRequest(fallbackUrl, bearerToken: token!);
            final fbDecoded = conv.json.decode(fallbackRes);
            if (fbDecoded['data'] != null && fbDecoded['data'] is List && (fbDecoded['data'] as List).isNotEmpty) {
              rawData = fbDecoded['data'];
            }
          } catch (_) {}
        }

        // D) Tartalék: RegisteredCourses félév-szűrés nélkül
        if (rawData == null || (rawData is List && rawData.isEmpty)) {
          try {
            final fallbackUrl = Uri.parse("$baseUrl/api/RegisteredCourses/GetRegisteredCourses?sortAndPage.subjectName=asc");
            final fallbackRes = await _APIRequest.getRequest(fallbackUrl, bearerToken: token!);
            final fbDecoded = conv.json.decode(fallbackRes);
            if (fbDecoded['data'] != null && fbDecoded['data'] is List && (fbDecoded['data'] as List).isNotEmpty) {
              rawData = fbDecoded['data'];
            }
          } catch (_) {}
        }

        Map<String, Subject> modernSubjectsMap = {};

        if (rawData != null && rawData is List) {
          for (var item in rawData) {
            if (item is! Map) continue;
            String subjectName = item['subjectName'] ?? item['name'] ?? item['subjectCode'] ?? AppStrings.getLanguagePack().api_fallback_UnknownSubject;
            String subjectCode = item['subjectCode']?.toString() ?? subjectName;
            int credit = (item['subjectCredit'] as num?)?.toInt() ?? (item['credit'] as num?)?.toInt() ?? 0;
            
            bool isCompleted = item['completed'] == true || item['isCompleted'] == true || item['passed'] == true;
            int grade = (item['grade'] as num?)?.toInt() ?? (item['resultValue'] as num?)?.toInt() ?? 0;
            int failState = 0;

            if (item['uiDisplayState'] != null && item['uiDisplayState'] is Map) {
              final ui = item['uiDisplayState'];
              int uiType = (ui['type'] as num?)?.toInt() ?? 0;
              if (uiType == 1) {
                isCompleted = true;
              }
              if (ui['reasons'] != null && ui['reasons'] is List) {
                for (var r in ui['reasons']) {
                  final rStr = r.toString().toLowerCase();
                  if (rStr.contains('teljesített') || rStr.contains('aláírva')) {
                    isCompleted = true;
                  }
                  if (rStr.contains('megtagadva') || rStr.contains('nem teljesített')) {
                    failState = 1;
                  }
                  final parsedG = parseTextToGrade(r.toString());
                  if (parsedG > 0) {
                    grade = parsedG;
                  }
                }
              }
            }

            if (isCompleted && grade == 0) {
              grade = 5;
            }

            if (modernSubjectsMap.containsKey(subjectCode)) {
              final existing = modernSubjectsMap[subjectCode]!;
              if (isCompleted) existing.completed = true;
              if (grade > existing.grade) existing.grade = grade;
              if (credit > existing.credit) existing.credit = credit;
              if (failState > existing.failState) existing.failState = failState;
            } else {
              modernSubjectsMap[subjectCode] = Subject(isCompleted, credit, subjectName, 0, grade, failState, subjectCode: subjectCode);
            }
          }
        }
        return modernSubjectsMap.values.toList();
      } catch (e) {
        debug.log("Hiba a modern tárgyak lekérésekor: $e");
        return [];
      }
    }

    // --- RÉGI API ÁG (Ahol még él a /MobileService.svc) ---
    int oldTermId = int.tryParse(activeTermId ?? '0') ?? 0;
    String responseJson = await _getMarkbookJSon(oldTermId);
    List<dynamic> markbooklistRaw = [];
    final decoded = conv.json.decode(responseJson);
    if (decoded['MarkBookList'] == null) return null;
    markbooklistRaw = decoded['MarkBookList'];

    if(responseJson.isEmpty || markbooklistRaw.isEmpty){ return null; }

    List<Subject> subjects = [];
    for (var markbook in markbooklistRaw){
      final markbookMap = markbook as Map<String, dynamic>;
      subjects.add(Subject(
          markbookMap['Completed'], markbookMap['Credit'], markbookMap['SubjectName'],
          markbookMap['ID'], parseTextToGrade(markbookMap['Values']), parseTextToFailstate(markbookMap['Signer'])
      ));
    }
    return subjects;
  }

  static Future<String> _getMarkbookJSon([int termId = 0]) async{
    final username = storage.DataCache.getUsername();
    final password = storage.DataCache.getPassword();
    final url = Uri.parse(storage.DataCache.getInstituteUrl()! + URLs.MARKBOOK_URL);
    final json = '{"UserLogin":"$username","Password":"$password","CurrentPage":1,"filter":{"TermID": $termId},"TotalRowCount":-1}';
    return await _APIRequest.postRequest(url, json);
  }

  static int parseTextToFailstate(String failstate){
    RegExp regex = RegExp(r'(aláírva|megtagadva)');
    final matches = regex.allMatches(failstate.toLowerCase());
    if(matches.isEmpty) return 0;
    int best = 99;
    for(var match in matches){
      final result = (match.group(1) ?? '').trim().toLowerCase();
      if(result.isEmpty) return 0;
      switch (result){
        case "megtagadva": if(best > 1) best = 1; break;
        default: if(best > 0) best = 0; break;
      }
    }
    return best;
  }

  static bool isMark(String txt){
    switch(txt){
      case 'jeles': case 'jó': case 'közepes': case 'elégséges': case 'elégtelen': return true;
      default: return false;
    }
  }

  static int parseTextToGrade(String gradeTxt){
    RegExp regex = RegExp(r'(elégtelen|elégséges|közepes|jó|jeles|megfelelt)');
    final matches = regex.allMatches(gradeTxt.toLowerCase());
    if(matches.isEmpty) return 0;

    int latest = 0;
    for(var match in matches){
      final result = (match.group(1) ?? '').trim().toLowerCase();
      if(result.isEmpty) break;
      switch (result){
        case 'jeles': latest = 5; break;
        case 'jó': latest = 4; break;
        case 'közepes': latest = 3; break;
        case 'elégséges': latest = 2; break;
        case 'elégtelen': latest = 1; break;
        case 'megfelelt': latest = 5; break; // Pipa megjelenítéséhez
      }
    }
    return latest;
  }

  /// Registered courses for selected term (separate from markbook / TakenSubjects).
  static Future<List<Subject>> getRegisteredCourses({String? termId}) async {
    if (storage.DataCache.getIsDemoAccount()!) {
      return [Subject(false, 3, AppStrings.getLanguagePack().api_demo_Course, 0, 0, 0, subjectCode: 'DEMO-001')];
    }
    if (!(storage.DataCache.getIsModernApi())) return [];
    try {
      final token = await storage.DataCache.getAccessToken();
      final baseUrl = storage.DataCache.getInstituteUrl() ?? '';
      final terms = await TermsRequest.getTerms();
      String guid = termId ?? storage.DataCache.getSelectedTermId() ?? '';
      if (guid.isEmpty && terms.isNotEmpty) guid = terms.last.id;
      for (final t in terms) {
        if (t.id == guid || t.termName == guid) {
          guid = t.id;
          break;
        }
      }
      String urlStr = "$baseUrl/api/RegisteredCourses/GetRegisteredCourses?sortAndPage.subjectName=asc";
      if (guid.isNotEmpty) {
        urlStr = "$baseUrl/api/RegisteredCourses/GetRegisteredCourses?request.termId=$guid&sortAndPage.subjectName=asc";
      }
      final raw = await _APIRequest.getRequest(Uri.parse(urlStr), bearerToken: token!);
      final decoded = conv.json.decode(raw);
      final out = <Subject>[];
      if (decoded['data'] is List) {
        for (final item in decoded['data'] as List) {
          if (item is! Map) continue;
          final code = item['subjectCode']?.toString() ?? '';
          final name = item['subjectName']?.toString() ?? item['name']?.toString() ?? code;
          final credit = (item['subjectCredit'] as num?)?.toInt() ?? (item['credit'] as num?)?.toInt() ?? 0;
          out.add(Subject(false, credit, name, 0, 0, 0, subjectCode: code));
        }
      }
      return out;
    } catch (e) {
      debug.log('getRegisteredCourses: $e');
      return [];
    }
  }

  /// Grade history: TakenSubjects for every known term (capped).
  /// Skips the walk when session is blocked (plan item 1 — no multi-term fetch on dead JWT).
  static Future<List<({String termName, Subject subject})>> getGradeHistoryAcrossTerms({int maxTerms = 8}) async {
    if (SessionGuard.isAuthBlocked || !storage.DataCache.getHasNetwork()) {
      return [];
    }
    final terms = await TermsRequest.getTerms();
    final out = <({String termName, Subject subject})>[];
    final slice = terms.length > maxTerms ? terms.sublist(terms.length - maxTerms) : terms;
    for (final t in slice.reversed) {
      if (SessionGuard.isAuthBlocked) break;
      final list = await getMarkbookSubjects(termId: t.id);
      if (list == null) continue;
      await cacheTermSubjects(t.id, list);
      for (final s in list) {
        if (s.grade > 0 || s.completed) {
          out.add((termName: t.termName, subject: s));
        }
      }
    }
    return out;
  }

  static String _termCacheLenKey(String termId) => 'CachedMarkbookTerm_${termId}_len';
  static String _termCacheItemKey(String termId, int i) => 'CachedMarkbookTerm_${termId}_$i';

  /// Persist TakenSubjects for one term (used by semester comparison, cache-first).
  static Future<void> cacheTermSubjects(String termId, List<Subject> list) async {
    if (termId.isEmpty) return;
    await storage.saveInt(_termCacheLenKey(termId), list.length);
    for (int i = 0; i < list.length; i++) {
      await storage.saveString(_termCacheItemKey(termId, i), list[i].toString());
    }
  }

  static Future<List<Subject>?> loadCachedTermSubjects(String termId) async {
    if (termId.isEmpty) return null;
    final len = await storage.getInt(_termCacheLenKey(termId));
    if (len == null || len < 0) return null;
    final out = <Subject>[];
    for (int i = 0; i < len; i++) {
      final raw = await storage.getString(_termCacheItemKey(termId, i));
      if (raw == null) continue;
      out.add(Subject(false, 0, 'NULL', 0, 0, 0).fillWithExisting(raw));
    }
    return out;
  }

  /// Per-term átlag / /30 / completed credits for side-by-side comparison (plan item 10).
  /// Cache-first; network only when session is usable. Cap [maxTerms] (default 8).
  static Future<List<TermComparisonStat>> getSemesterComparison({int maxTerms = 8}) async {
    if (storage.DataCache.getIsDemoAccount()!) {
      return [
        TermComparisonStat(
          termId: '70876',
          termName: AppStrings.getLanguagePack().api_demo_Term1,
          creditSum: 20,
          average: 4.2,
          per30: 2.8,
          fromCache: true,
        ),
        TermComparisonStat(
          termId: '70877',
          termName: AppStrings.getLanguagePack().api_demo_Term2,
          creditSum: 24,
          average: 3.75,
          per30: 3.0,
          fromCache: true,
        ),
      ];
    }

    final terms = await TermsRequest.getTerms();
    if (terms.isEmpty) return [];
    final slice = terms.length > maxTerms ? terms.sublist(terms.length - maxTerms) : List<Term>.from(terms);
    // Newest first for the comparison UI.
    final ordered = slice.reversed.toList();
    final canFetch = !SessionGuard.isAuthBlocked && storage.DataCache.getHasNetwork();
    final out = <TermComparisonStat>[];

    for (final t in ordered) {
      List<Subject>? list = await loadCachedTermSubjects(t.id);
      bool fromCache = list != null;
      if ((list == null || list.isEmpty) && canFetch) {
        list = await getMarkbookSubjects(termId: t.id);
        if (list != null) {
          await cacheTermSubjects(t.id, list);
          fromCache = false;
        }
      }
      if (list == null || list.isEmpty) continue;

      // Same rule as markbook header: completed subjects with grade ≥ 2.
      final grades = <int>[];
      final credits = <int>[];
      for (final s in list) {
        if (!s.completed) continue;
        grades.add(s.grade);
        credits.add(s.credit);
      }
      final r = MarkbookMath.fromCompleted(grades: grades, credits: credits);
      if (r.creditSum <= 0 || r.average.isNaN) continue;
      out.add(TermComparisonStat(
        termId: t.id,
        termName: t.termName,
        creditSum: r.creditSum,
        average: r.average,
        per30: r.per30,
        fromCache: fromCache,
      ));
    }
    return out;
  }
}

/// One row for semester comparison (plan item 10).
class TermComparisonStat {
  final String termId;
  final String termName;
  final int creditSum;
  final double average;
  final double per30;
  final bool fromCache;

  const TermComparisonStat({
    required this.termId,
    required this.termName,
    required this.creditSum,
    required this.average,
    required this.per30,
    this.fromCache = false,
  });
}

class CashinRequest{
  /// One page of previous transactions — not full history. Header / UI must not claim "all time".
  static const int previousTransactionsPageSize = 50;

  static Future<List<CashinEntry>?> getCashin() => getAllCashins();

  static Future<List<CashinEntry>?> getAllCashins() async{
    if(storage.DataCache.getIsDemoAccount()!){
      final now = DateTime.now();
      return <CashinEntry>[
        CashinEntry(10000, DateTime(now.year + 1, now.month).millisecondsSinceEpoch, AppStrings.getLanguagePack().api_demo_Payment1, "1", 'aktív'),
        // Negative = paid outgoing fee (counts toward totalMoney); positive completed = scholarship (does not).
        CashinEntry(-50000, now.subtract(const Duration(days: 40)).millisecondsSinceEpoch, AppStrings.getLanguagePack().api_demo_Payment2, "2", 'teljesített'),
        CashinEntry(30000, now.subtract(const Duration(days: 70)).millisecondsSinceEpoch, AppStrings.getLanguagePack().api_demo_Payment2, "3", 'teljesített'),
      ];
    }
    else if(storage.DataCache.getHasICSFile() ?? false){
      return [];
    }


    if (storage.DataCache.getIsModernApi()) {
      try {
        final token = await storage.DataCache.getAccessToken();
        String baseUrl = storage.DataCache.getInstituteUrl() ?? '';

        final lastRow = previousTransactionsPageSize;
        final url = Uri.parse("$baseUrl/api/Transactions/GetStudentPreviousTransactions?sortAndPage.firstRow=0&sortAndPage.lastRow=$lastRow&sortAndPage.transferDate=desc");

        final responseRaw = await _APIRequest.getRequest(url, bearerToken: token!);
        final decoded = conv.json.decode(responseRaw);

        List<CashinEntry> modernCashins = [];

        if (decoded['data'] != null && decoded['data'] is List) {
          for (var item in decoded['data']) {
            final rawVal = item['transactionValue'];
            int amount = ((rawVal as num?) ?? 0).toInt().abs();
            final sign = item['sign']?.toString() ?? '';
            final dir = item['transactionDirection']?.toString().toLowerCase() ?? '';
            final type = item['transactionPayingType']?.toString().toLowerCase() ?? '';

            // Student perspective:
            // Receiving money (scholarship, kifizetés, jóváírás, sign == '-'): POSITIVE (+)
            // Paying money (tuition, fees, befizetés, sign == '+'): NEGATIVE (-)
            bool isReceiving = sign == '-' ||
                dir.contains('kifizet') ||
                dir.contains('jóváírás') ||
                dir.contains('bejövő') ||
                type.contains('ösztöndíj') ||
                type.contains('támogatás') ||
                type.contains('jutalom');

            if (isReceiving) {
              amount = amount; // Positive
            } else {
              amount = -amount; // Negative
            }

            final rawDate = item['transferDate']?.toString();
            final dateMs = rawDate != null ? (DateTime.tryParse(rawDate)?.millisecondsSinceEpoch ?? 0) : 0;

            modernCashins.add(CashinEntry(
                amount,
                dateMs,
                item['transactionPayingType']?.toString() ?? AppStrings.getLanguagePack().payment_unknownTransaction,
                item['transactionId']?.toString() ?? 'unknown_id',
                item['transactionStatus']?.toString() ?? AppStrings.getLanguagePack().payment_unknownStatus,
                direction: item['transactionDirection']?.toString(),
                note: item['transactionNote']?.toString(),
                currency: item['transactionCurrency']?.toString() ?? 'HUF'
            ));
          }
        }
        return modernCashins;
      } catch (e) {
        debug.log("Hiba a modern tranzakciók lekérésekor: $e");
        return [];
      }
    }


    final username = storage.DataCache.getUsername();
    final password = storage.DataCache.getPassword();
    final json = '{"UserLogin":"$username","Password":"$password","TotalRowCount":-1}';
    final url = Uri.parse(storage.DataCache.getInstituteUrl()! + URLs.GETCASHIN_URL);

    List<CashinEntry> entries = _jsonToCashinEntry(await _APIRequest.postRequest(url, json));
    return entries;
  }

  static List<CashinEntry> _jsonToCashinEntry(String json){
    if(storage.DataCache.getIsDemoAccount()!){ return []; }
    List<CashinEntry> ls = [];
    try {
      final List<dynamic> cashins = conv.json.decode(json)['CashinDataRows'];
      for (var cashin in cashins) {
        ls.add(CashinEntry(
            cashin['amount'],
            int.parse(cashin['deadline'] == null ? '0' : cashin['deadline'].toString().replaceAll('/Date(', '').replaceAll(')/', '')),
            cashin['appellation'],
            cashin['ID'].toString(),
            cashin['status_name']
        ));
      }
    }
    catch (_){ return []; }
    return ls;
  }

  static Future<double?> getCollectiveInvoiceBalance() async {
    if (storage.DataCache.getIsDemoAccount()!) {
      await storage.DataCache.setAccountBalance(15000.0, currency: 'HUF');
      return 15000.0;
    }
    if (storage.DataCache.getIsModernApi()) {
      try {
        final invoices = await getCollectiveInvoices();
        if (invoices.isNotEmpty) {
          final first = invoices.first;
          final balance = first.balance;
          await storage.DataCache.setAccountBalance(balance, currency: first.currency);
          return balance;
        }
      } catch (e) {
        debug.log("Hiba a gyűjtőszámla egyenleg lekérésekor: $e");
      }
    }
    return storage.DataCache.getAccountBalance();
  }

  static Future<List<CollectiveInvoice>> getCollectiveInvoices() async {
    if (storage.DataCache.getIsDemoAccount()!) {
      return [CollectiveInvoice('DEMO', 15000, 'HUF')];
    }
    if (!storage.DataCache.getIsModernApi()) return [];
    try {
      final token = await storage.DataCache.getAccessToken();
      String baseUrl = storage.DataCache.getInstituteUrl() ?? '';
      final url = Uri.parse("$baseUrl/api/FinancialDataDashboard/GetCollectiveInvoices");
      final responseRaw = await _APIRequest.getRequest(url, bearerToken: token!);
      final decoded = conv.json.decode(responseRaw);
      final list = <CollectiveInvoice>[];
      if (decoded['data'] != null && decoded['data'] is List) {
        for (final item in decoded['data'] as List) {
          if (item is! Map) continue;
          list.add(CollectiveInvoice(
            item['collectiveInvoiceName']?.toString() ??
                item['name']?.toString() ??
                item['appellation']?.toString() ??
                'Invoice',
            (item['collectiveInvoiceBalance'] as num?)?.toDouble() ?? 0.0,
            item['collectiveInvoiceCurrency']?.toString() ?? 'HUF',
          ));
        }
      }
      return list;
    } catch (e) {
      debug.log('getCollectiveInvoices: $e');
      return [];
    }
  }
}

/// Plan item 12 — bank (read-only flags), student-card **claim** status, optional profile.
/// Never logs IBAN / bankAccountNumber / SWIFT / nekId. No QR / card number / expiry.
class StudentCardRequest {
  static const _secretBankKeys = {
    'bankAccountNumber',
    'BankAccountNumber',
    'iban',
    'IBAN',
    'bankAccountSwiftCode',
    'BankAccountSwiftCode',
    'swift',
    'SWIFT',
    'bic',
    'BIC',
  };

  static Future<Map?> _getData(String path) async {
    if (!storage.DataCache.getIsModernApi()) return null;
    if (SessionGuard.isAuthBlocked) return null;
    final token = storage.DataCache.getAccessToken();
    if (token == null || token.isEmpty) return null;
    final baseUrl = storage.DataCache.getInstituteUrl() ?? '';
    if (baseUrl.isEmpty) return null;
    try {
      final raw = await _APIRequest.getRequest(
        Uri.parse('$baseUrl$path'),
        bearerToken: token,
      );
      final decoded = conv.json.decode(raw);
      if (decoded is! Map) return null;
      final data = decoded['data'];
      if (data is Map) return Map<String, dynamic>.from(data);
      if (data is List) return {'_list': data};
      if (data == null) return {};
      return {'_value': data};
    } catch (e) {
      debug.log('StudentCardRequest $path: $e');
      return null;
    }
  }

  /// Strip account numbers / SWIFT before any debug or cache of raw maps.
  static Map<String, dynamic> _sanitizeBankMap(Map raw) {
    final out = <String, dynamic>{};
    raw.forEach((k, v) {
      final key = k.toString();
      if (_secretBankKeys.contains(key)) return;
      // Never copy nested account-number blobs.
      if (v is Map) {
        out[key] = _sanitizeBankMap(v);
      } else {
        out[key] = v;
      }
    });
    return out;
  }

  static BankAccountFlags? _flagsFromMap(Map raw) {
    final s = _sanitizeBankMap(raw);
    final owner = s['bankAccountOwner']?.toString() ??
        s['BankAccountOwner']?.toString() ??
        '';
    final bankName = s['bankName']?.toString() ?? s['BankName']?.toString() ?? '';
    if (owner.isEmpty && bankName.isEmpty && s['isDefault'] == null && s['isValid'] == null) {
      return null;
    }
    return BankAccountFlags(
      owner: owner,
      bankName: bankName,
      isDefault: s['isDefault'] == true,
      isForeign: s['isForeign'] == true,
      isValid: s['isValid'] == true,
      otpStatus: s['otpStatus']?.toString() ?? s['OtpStatus']?.toString() ?? '',
      otpStatusIsVisible: s['otpStatusIsVisible'] != false,
    );
  }

  static Future<List<BankAccountFlags>> fetchBankFlags() async {
    final list = <BankAccountFlags>[];
    final seen = <String>{};

    void addFlags(BankAccountFlags? f, {String? dedupeKey}) {
      if (f == null) return;
      final key = dedupeKey ?? '${f.owner}|${f.bankName}|${f.isDefault}';
      if (seen.contains(key)) return;
      seen.add(key);
      list.add(f);
    }

    // Tab list first — ids only; details pulled without logging secrets.
    final tab = await _getData('/api/BankAccount/GetUserBankAccountTabList');
    final tabItems = tab?['_list'];
    if (tabItems is List) {
      for (final item in tabItems) {
        if (item is! Map) continue;
        final id = item['bankAccountId']?.toString() ??
            item['BankAccountId']?.toString() ??
            item['id']?.toString();
        if (id != null && id.isNotEmpty) {
          final details = await _getData(
            '/api/BankAccount/GetBankAccountDetails?bankAccountId=$id',
          );
          if (details != null && details['_list'] == null) {
            addFlags(_flagsFromMap(details), dedupeKey: id);
            continue;
          }
        }
        addFlags(_flagsFromMap(item));
      }
    }

    // Default account — may return an id or a number; never log the payload.
    final def = await _getData('/api/BankAccount/GetDefaultBankAccountNumber');
    if (def != null) {
      final id = def['bankAccountId']?.toString() ??
          def['BankAccountId']?.toString() ??
          def['id']?.toString();
      if (id != null && id.isNotEmpty && !seen.contains(id)) {
        final details = await _getData(
          '/api/BankAccount/GetBankAccountDetails?bankAccountId=$id',
        );
        if (details != null && details['_list'] == null) {
          addFlags(_flagsFromMap(details), dedupeKey: id);
        }
      } else if (def['_list'] == null && def['_value'] == null) {
        addFlags(_flagsFromMap(def));
      }
      // If `_value` is a raw account number string — discard; never use/log it.
    }

    return list;
  }

  static StudentCardClaimStatus? _claimFromMap(Map raw) {
    // nekId present on wire — never copy into logs; omit from model for UI honesty.
    final claimType = raw['claimType']?.toString() ?? '';
    final firStatus = raw['firStatus']?.toString() ?? '';
    final firStatusId = raw['firStatusId']?.toString() ?? '';
    final processStatus = raw['processStatus']?.toString() ?? '';
    final finalDecision = raw['finalDecision']?.toString() ?? '';
    final registrationDate = raw['registrationDate']?.toString() ?? '';
    final trainingName = raw['trainingName']?.toString() ?? '';
    final trainingFaculty = raw['trainingFaculty']?.toString() ?? '';
    final primaryInstituteName = raw['primaryInstituteName']?.toString() ?? '';
    final primaryInstitutePrintCode =
        raw['primaryInstitutePrintCode']?.toString() ?? '';
    final addressId = raw['addressId']?.toString() ?? '';
    final hasAny = [
      claimType,
      firStatus,
      processStatus,
      finalDecision,
      trainingName,
      primaryInstituteName,
    ].any((s) => s.isNotEmpty);
    if (!hasAny && raw.isEmpty) return null;
    return StudentCardClaimStatus(
      claimType: claimType,
      firStatus: firStatus,
      firStatusId: firStatusId,
      processStatus: processStatus,
      finalDecision: finalDecision,
      registrationDate: registrationDate,
      trainingName: trainingName,
      trainingFaculty: trainingFaculty,
      primaryInstituteName: primaryInstituteName,
      primaryInstitutePrintCode: primaryInstitutePrintCode,
      addressId: addressId,
    );
  }

  static Future<StudentCardClaimStatus?> fetchClaimStatus() async {
    final data = await _getData('/api/StudentCard/StudentCardClaimProcess');
    if (data == null) return null;
    if (data['_list'] is List) {
      final list = data['_list'] as List;
      if (list.isEmpty) return null;
      final first = list.first;
      if (first is Map) return _claimFromMap(first);
      return null;
    }
    if (data.isEmpty) return null;
    return _claimFromMap(data);
  }

  static Future<List<StudentCardAddress>> fetchClaimAddresses() async {
    final data = await _getData('/api/StudentCard/GetStudentAddress');
    final out = <StudentCardAddress>[];
    final items = data?['_list'];
    if (items is List) {
      for (final item in items) {
        if (item is! Map) continue;
        final address = item['address']?.toString() ?? '';
        final addressType = item['addressType']?.toString() ?? '';
        if (address.isEmpty && addressType.isEmpty) continue;
        out.add(StudentCardAddress(address: address, addressType: addressType));
      }
    } else if (data != null && data['_list'] == null && data.isNotEmpty) {
      final address = data['address']?.toString() ?? '';
      final addressType = data['addressType']?.toString() ?? '';
      if (address.isNotEmpty || addressType.isNotEmpty) {
        out.add(StudentCardAddress(address: address, addressType: addressType));
      }
    }
    return out;
  }

  static Future<GeneralUserProfile?> fetchGeneralProfile() async {
    final data = await _getData('/api/PersonalData/GetGeneralUserData');
    if (data == null || data.isEmpty || data['_list'] != null) return null;

    final citizenships = <String>[];
    final rawCit = data['userCitizenship'] ?? data['UserCitizenship'];
    if (rawCit is List) {
      for (final c in rawCit) {
        if (c is Map) {
          final label = c['name']?.toString() ??
              c['citizenship']?.toString() ??
              c['translation']?.toString() ??
              c['value']?.toString() ??
              '';
          if (label.isNotEmpty) citizenships.add(label);
        } else if (c != null && c.toString().isNotEmpty) {
          citizenships.add(c.toString());
        }
      }
    }

    final extras = <ProfileExtraField>[];
    final rawExtra = data['extraFields'] ?? data['ExtraFields'];
    if (rawExtra is List) {
      for (final e in rawExtra) {
        if (e is! Map) continue;
        extras.add(ProfileExtraField(
          field: e['field']?.toString() ?? '',
          translation: e['translation']?.toString() ?? '',
          value: e['value']?.toString() ?? '',
          isRequired: e['required'] == true,
        ));
      }
    }

    String s(String a, [String? b]) =>
        data[a]?.toString() ?? (b != null ? data[b]?.toString() : null) ?? '';

    return GeneralUserProfile(
      printName: s('printName', 'PrintName'),
      firstName: s('firstName', 'FirstName'),
      lastName: s('lastName', 'LastName'),
      title: s('title', 'Title'),
      bornName: s('bornName', 'BornName'),
      bornDate: s('bornDate', 'BornDate'),
      bornCountry: s('bornCountry', 'BornCountry'),
      bornPlace: s('bornPlace', 'BornPlace'),
      sex: s('sex', 'Sex'),
      loginName: s('loginName', 'LoginName'),
      motherName: s('motherName', 'MotherName'),
      numberOfChildren: s('numberOfChildren', 'NumberOfChildren'),
      educationalIdentifier: s('educationalIdentifier', 'EducationalIdentifier'),
      citizenships: citizenships,
      extraFields: extras,
    );
  }

  static Future<ProfileContacts?> fetchContacts() async {
    final data = await _getData('/api/PersonalData/GetStudentPersonalDataContacts');
    if (data == null) return null;
    final addresses = <String>[];
    final emails = <String>[];
    final phones = <String>[];

    void collect(dynamic node, List<String> into, List<String> keys) {
      if (node is List) {
        for (final item in node) {
          if (item is Map) {
            for (final k in keys) {
              final v = item[k]?.toString();
              if (v != null && v.isNotEmpty) {
                into.add(v);
                break;
              }
            }
          } else if (item != null && item.toString().isNotEmpty) {
            into.add(item.toString());
          }
        }
      }
    }

    collect(data['addresses'] ?? data['addressList'] ?? data['Addresses'], addresses, [
      'address',
      'fullAddress',
      'value',
      'text',
    ]);
    collect(data['emails'] ?? data['emailList'] ?? data['Emails'], emails, [
      'email',
      'emailAddress',
      'value',
      'text',
    ]);
    collect(data['phones'] ?? data['phoneList'] ?? data['Phones'], phones, [
      'phone',
      'phoneNumber',
      'value',
      'text',
    ]);

    // Some payloads nest under contact groups.
    if (addresses.isEmpty && emails.isEmpty && phones.isEmpty) {
      collect(data['studentAddresses'], addresses, ['address', 'fullAddress', 'value']);
      collect(data['studentEmails'], emails, ['email', 'emailAddress', 'value']);
      collect(data['studentPhones'], phones, ['phone', 'phoneNumber', 'value']);
    }

    if (addresses.isEmpty && emails.isEmpty && phones.isEmpty) return null;
    return ProfileContacts(addresses: addresses, emails: emails, phones: phones);
  }

  /// Fetch all item-12 surfaces and persist **non-secret** claim/bank flags (+ light profile).
  static Future<StudentCardSnapshot> fetchAndCache() async {
    final banks = await fetchBankFlags();
    final claim = await fetchClaimStatus();
    final addresses = await fetchClaimAddresses();
    final profile = await fetchGeneralProfile();
    final contacts = await fetchContacts();
    final snap = StudentCardSnapshot(
      banks: banks,
      claim: claim,
      addresses: addresses,
      profile: profile,
      contacts: contacts,
      fromCache: false,
    );
    await storage.DataCache.setStudentCardCacheJson(snap.toCacheJson());
    return snap;
  }

  static StudentCardSnapshot? loadCached() {
    final raw = storage.DataCache.getStudentCardCacheJson();
    if (raw == null || raw.isEmpty) return null;
    try {
      return StudentCardSnapshot.fromCacheJson(raw);
    } catch (e) {
      debug.log('StudentCardRequest.loadCached: $e');
      return null;
    }
  }
}

class BankAccountFlags {
  final String owner;
  final String bankName;
  final bool isDefault;
  final bool isForeign;
  final bool isValid;
  final String otpStatus;
  final bool otpStatusIsVisible;

  const BankAccountFlags({
    required this.owner,
    required this.bankName,
    required this.isDefault,
    required this.isForeign,
    required this.isValid,
    required this.otpStatus,
    this.otpStatusIsVisible = true,
  });

  Map<String, dynamic> toJson() => {
        'owner': owner,
        'bankName': bankName,
        'isDefault': isDefault,
        'isForeign': isForeign,
        'isValid': isValid,
        'otpStatus': otpStatus,
        'otpStatusIsVisible': otpStatusIsVisible,
      };

  static BankAccountFlags fromJson(Map<String, dynamic> j) => BankAccountFlags(
        owner: j['owner']?.toString() ?? '',
        bankName: j['bankName']?.toString() ?? '',
        isDefault: j['isDefault'] == true,
        isForeign: j['isForeign'] == true,
        isValid: j['isValid'] == true,
        otpStatus: j['otpStatus']?.toString() ?? '',
        otpStatusIsVisible: j['otpStatusIsVisible'] != false,
      );
}

class StudentCardClaimStatus {
  final String claimType;
  final String firStatus;
  final String firStatusId;
  final String processStatus;
  final String finalDecision;
  final String registrationDate;
  final String trainingName;
  final String trainingFaculty;
  final String primaryInstituteName;
  final String primaryInstitutePrintCode;
  final String addressId;

  const StudentCardClaimStatus({
    required this.claimType,
    required this.firStatus,
    required this.firStatusId,
    required this.processStatus,
    required this.finalDecision,
    required this.registrationDate,
    required this.trainingName,
    required this.trainingFaculty,
    required this.primaryInstituteName,
    required this.primaryInstitutePrintCode,
    required this.addressId,
  });

  bool get isEmpty =>
      claimType.isEmpty &&
      firStatus.isEmpty &&
      processStatus.isEmpty &&
      finalDecision.isEmpty &&
      trainingName.isEmpty &&
      primaryInstituteName.isEmpty;

  Map<String, dynamic> toJson() => {
        'claimType': claimType,
        'firStatus': firStatus,
        'firStatusId': firStatusId,
        'processStatus': processStatus,
        'finalDecision': finalDecision,
        'registrationDate': registrationDate,
        'trainingName': trainingName,
        'trainingFaculty': trainingFaculty,
        'primaryInstituteName': primaryInstituteName,
        'primaryInstitutePrintCode': primaryInstitutePrintCode,
        'addressId': addressId,
      };

  static StudentCardClaimStatus fromJson(Map<String, dynamic> j) =>
      StudentCardClaimStatus(
        claimType: j['claimType']?.toString() ?? '',
        firStatus: j['firStatus']?.toString() ?? '',
        firStatusId: j['firStatusId']?.toString() ?? '',
        processStatus: j['processStatus']?.toString() ?? '',
        finalDecision: j['finalDecision']?.toString() ?? '',
        registrationDate: j['registrationDate']?.toString() ?? '',
        trainingName: j['trainingName']?.toString() ?? '',
        trainingFaculty: j['trainingFaculty']?.toString() ?? '',
        primaryInstituteName: j['primaryInstituteName']?.toString() ?? '',
        primaryInstitutePrintCode: j['primaryInstitutePrintCode']?.toString() ?? '',
        addressId: j['addressId']?.toString() ?? '',
      );
}

class StudentCardAddress {
  final String address;
  final String addressType;

  const StudentCardAddress({required this.address, required this.addressType});

  Map<String, dynamic> toJson() => {'address': address, 'addressType': addressType};

  static StudentCardAddress fromJson(Map<String, dynamic> j) => StudentCardAddress(
        address: j['address']?.toString() ?? '',
        addressType: j['addressType']?.toString() ?? '',
      );
}

class ProfileExtraField {
  final String field;
  final String translation;
  final String value;
  final bool isRequired;

  const ProfileExtraField({
    required this.field,
    required this.translation,
    required this.value,
    required this.isRequired,
  });

  Map<String, dynamic> toJson() => {
        'field': field,
        'translation': translation,
        'value': value,
        'required': isRequired,
      };

  static ProfileExtraField fromJson(Map<String, dynamic> j) => ProfileExtraField(
        field: j['field']?.toString() ?? '',
        translation: j['translation']?.toString() ?? '',
        value: j['value']?.toString() ?? '',
        isRequired: j['required'] == true,
      );
}

class GeneralUserProfile {
  final String printName;
  final String firstName;
  final String lastName;
  final String title;
  final String bornName;
  final String bornDate;
  final String bornCountry;
  final String bornPlace;
  final String sex;
  final String loginName;
  final String motherName;
  final String numberOfChildren;
  final String educationalIdentifier;
  final List<String> citizenships;
  final List<ProfileExtraField> extraFields;

  const GeneralUserProfile({
    required this.printName,
    required this.firstName,
    required this.lastName,
    required this.title,
    required this.bornName,
    required this.bornDate,
    required this.bornCountry,
    required this.bornPlace,
    required this.sex,
    required this.loginName,
    required this.motherName,
    required this.numberOfChildren,
    required this.educationalIdentifier,
    required this.citizenships,
    required this.extraFields,
  });

  Map<String, dynamic> toJson() => {
        'printName': printName,
        'firstName': firstName,
        'lastName': lastName,
        'title': title,
        'bornName': bornName,
        'bornDate': bornDate,
        'bornCountry': bornCountry,
        'bornPlace': bornPlace,
        'sex': sex,
        'loginName': loginName,
        'motherName': motherName,
        'numberOfChildren': numberOfChildren,
        'educationalIdentifier': educationalIdentifier,
        'citizenships': citizenships,
        'extraFields': extraFields.map((e) => e.toJson()).toList(),
      };

  static GeneralUserProfile fromJson(Map<String, dynamic> j) => GeneralUserProfile(
        printName: j['printName']?.toString() ?? '',
        firstName: j['firstName']?.toString() ?? '',
        lastName: j['lastName']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        bornName: j['bornName']?.toString() ?? '',
        bornDate: j['bornDate']?.toString() ?? '',
        bornCountry: j['bornCountry']?.toString() ?? '',
        bornPlace: j['bornPlace']?.toString() ?? '',
        sex: j['sex']?.toString() ?? '',
        loginName: j['loginName']?.toString() ?? '',
        motherName: j['motherName']?.toString() ?? '',
        numberOfChildren: j['numberOfChildren']?.toString() ?? '',
        educationalIdentifier: j['educationalIdentifier']?.toString() ?? '',
        citizenships: (j['citizenships'] as List?)?.map((e) => e.toString()).toList() ?? [],
        extraFields: (j['extraFields'] as List?)
                ?.whereType<Map>()
                .map((e) => ProfileExtraField.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            [],
      );
}

class ProfileContacts {
  final List<String> addresses;
  final List<String> emails;
  final List<String> phones;

  const ProfileContacts({
    required this.addresses,
    required this.emails,
    required this.phones,
  });

  Map<String, dynamic> toJson() => {
        'addresses': addresses,
        'emails': emails,
        'phones': phones,
      };

  static ProfileContacts fromJson(Map<String, dynamic> j) => ProfileContacts(
        addresses: (j['addresses'] as List?)?.map((e) => e.toString()).toList() ?? [],
        emails: (j['emails'] as List?)?.map((e) => e.toString()).toList() ?? [],
        phones: (j['phones'] as List?)?.map((e) => e.toString()).toList() ?? [],
      );
}

class StudentCardSnapshot {
  final List<BankAccountFlags> banks;
  final StudentCardClaimStatus? claim;
  final List<StudentCardAddress> addresses;
  final GeneralUserProfile? profile;
  final ProfileContacts? contacts;
  final bool fromCache;

  const StudentCardSnapshot({
    required this.banks,
    required this.claim,
    required this.addresses,
    required this.profile,
    required this.contacts,
    this.fromCache = false,
  });

  String toCacheJson() => conv.jsonEncode({
        'banks': banks.map((b) => b.toJson()).toList(),
        'claim': claim?.toJson(),
        'addresses': addresses.map((a) => a.toJson()).toList(),
        'profile': profile?.toJson(),
        'contacts': contacts?.toJson(),
      });

  static StudentCardSnapshot fromCacheJson(String raw) {
    final j = conv.jsonDecode(raw) as Map<String, dynamic>;
    return StudentCardSnapshot(
      banks: (j['banks'] as List?)
              ?.whereType<Map>()
              .map((e) => BankAccountFlags.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      claim: j['claim'] is Map
          ? StudentCardClaimStatus.fromJson(Map<String, dynamic>.from(j['claim'] as Map))
          : null,
      addresses: (j['addresses'] as List?)
              ?.whereType<Map>()
              .map((e) => StudentCardAddress.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      profile: j['profile'] is Map
          ? GeneralUserProfile.fromJson(Map<String, dynamic>.from(j['profile'] as Map))
          : null,
      contacts: j['contacts'] is Map
          ? ProfileContacts.fromJson(Map<String, dynamic>.from(j['contacts'] as Map))
          : null,
      fromCache: true,
    );
  }
}

class PeriodsRequest{

  static Future<List<PeriodEntry>?> getPeriods({String? termId}) async{
    if(storage.DataCache.getIsDemoAccount()!){
      final now = DateTime.now();
      return <PeriodEntry>[
        PeriodEntry('lejárt időszak', DateTime(now.year - 1, now.month, now.day - 2).millisecondsSinceEpoch, DateTime(now.year - 1, now.month, now.day + 1).millisecondsSinceEpoch, 1),
        PeriodEntry('bejelentkezési időszak', DateTime(now.year, now.month, now.day - 2).millisecondsSinceEpoch, DateTime(now.year, now.month, now.day +7).millisecondsSinceEpoch, 1),
      ];
    }
    else if(storage.DataCache.getHasICSFile() ?? false){
      return [PeriodEntry('végleges tárgyjelentkezés', await ICSCalendar.getFirstEventStartMs(), await ICSCalendar.getFirstEventStartMs() + Duration(days: 365).inMilliseconds, 1)];
    }

    final activeTermId = termId ?? storage.DataCache.getSelectedTermId();

    // --- MODERN API ÁG ---
    if (storage.DataCache.getIsModernApi()) {
      try {
        final token = await storage.DataCache.getAccessToken();
        String baseUrl = storage.DataCache.getInstituteUrl() ?? '';

        List<Term> terms = await TermsRequest.getTerms();
        String effectiveTermGuid = '';

        if (activeTermId != null && activeTermId.isNotEmpty) {
          for (var t in terms) {
            if (t.id == activeTermId || t.termName == activeTermId || t.termName == storage.DataCache.getSelectedTermName()) {
              effectiveTermGuid = t.id;
              break;
            }
          }
          if (effectiveTermGuid.isEmpty && activeTermId.contains('-') && activeTermId.length > 20) {
            effectiveTermGuid = activeTermId;
          }
        }

        if (effectiveTermGuid.isEmpty && terms.isNotEmpty) {
          effectiveTermGuid = terms.last.id;
        }

        if (effectiveTermGuid.isEmpty) return [];

        // 3. Időszakok lekérése az adott félévhez
        String periodsUrlStr = "$baseUrl/api/Periods/GetPeriods?sortAndPage.firstRow=0&sortAndPage.lastRow=50&sortAndPage.fromDate=asc";
        if (effectiveTermGuid.isNotEmpty) {
          periodsUrlStr = "$baseUrl/api/Periods/GetPeriods?request.termId=$effectiveTermGuid&sortAndPage.firstRow=0&sortAndPage.lastRow=50&sortAndPage.fromDate=asc";
        }
        final periodsUrl = Uri.parse(periodsUrlStr);
        final periodsResponse = await _APIRequest.getRequest(periodsUrl, bearerToken: token!);
        var periodsDecoded = conv.json.decode(periodsResponse);

        if ((periodsDecoded['data'] == null || (periodsDecoded['data'] is List && (periodsDecoded['data'] as List).isEmpty)) && effectiveTermGuid.isNotEmpty) {
          final fallbackUrl = Uri.parse("$baseUrl/api/Periods/GetPeriods?sortAndPage.firstRow=0&sortAndPage.lastRow=50&sortAndPage.fromDate=asc");
          final fallbackRes = await _APIRequest.getRequest(fallbackUrl, bearerToken: token);
          final fbDecoded = conv.json.decode(fallbackRes);
          if (fbDecoded['data'] != null && fbDecoded['data'] is List && (fbDecoded['data'] as List).isNotEmpty) {
            periodsDecoded = fbDecoded;
          }
        }

        List<PeriodEntry> modernPeriods = [];
        if (periodsDecoded['data'] != null && periodsDecoded['data'] is List) {
          for (var item in periodsDecoded['data']) {
            final fromStr = item['fromDate']?.toString();
            final toStr = item['toDate']?.toString();
            if (fromStr == null || toStr == null) continue;

            final fromEpoch = DateTime.tryParse(fromStr)?.millisecondsSinceEpoch ?? 0;
            final toEpoch = DateTime.tryParse(toStr)?.millisecondsSinceEpoch ?? 0;

            final pName = item['periodName']?.toString() ?? item['periodType']?.toString() ?? AppStrings.getLanguagePack().api_fallback_UnknownPeriod;

            modernPeriods.add(PeriodEntry(
                pName,
                fromEpoch,
                toEpoch,
                1 // partOfSemester fake adat (nem használja igazán a UI)
            ));
          }
        }
        return modernPeriods;

      } catch (e) {
        debug.log("Hiba a modern időszakok lekérésekor: $e");
        return [];
      }
    }

    // --- RÉGI API ÁG ---
    List<Term> terms = [];
    if (activeTermId != null && activeTermId.isNotEmpty) {
      terms = [Term(activeTermId, storage.DataCache.getSelectedTermName() ?? '')];
    } else {
      terms = await TermsRequest.getTerms();
    }
    if(terms.isEmpty) return <PeriodEntry>[PeriodEntry(AppStrings.getLanguagePack().api_fallback_NoTermId, DateTime.now().millisecondsSinceEpoch, DateTime.now().millisecondsSinceEpoch, 1)];

    List<PeriodEntry> periods = <PeriodEntry>[];
    int cntperiod = terms.length;
    for(var term in terms){
      final jsonresult = await _getPeriodJSon(term.intId);
      final decoded = conv.json.decode(jsonresult);
      if (decoded['PeriodList'] != null) {
        final result = decoded['PeriodList'] as List<dynamic>;
        for(var period in result){
          final currPeriod = period as Map<String, dynamic>;
          periods.add(PeriodEntry(currPeriod['PeriodTypeName'], int.parse(currPeriod['FromDate'].toString().replaceAll('/Date(', '').replaceAll(')/', '')), int.parse(currPeriod['ToDate'].toString().replaceAll('/Date(', '').replaceAll(')/', '')), cntperiod));
        }
      }
      cntperiod--;
    }
    return periods;
  }

  static Future<String> _getPeriodJSon(int termID) async{
    final username = storage.DataCache.getUsername();
    final password = storage.DataCache.getPassword();
    final url = Uri.parse(storage.DataCache.getInstituteUrl()! + URLs.PERIODS_URL);
    final json = '{"UserLogin":"$username","Password":"$password","PeriodTermID":$termID,"TotalRowCount":-1}';
    return await _APIRequest.postRequest(url, json);
  }
}

class MailRequest{
  /// Last known total inbox rows from GetReceivedMessages (0 if API omitted it).
  static int lastTotalRowCount = 0;

  static Future<int> getUnreadMessageCount() async {
    if (storage.DataCache.getIsDemoAccount()!) {
      await storage.DataCache.setUnreadMailCount(1);
      return 1;
    }
    if (storage.DataCache.getIsModernApi()) {
      try {
        final token = await storage.DataCache.getAccessToken();
        String baseUrl = storage.DataCache.getInstituteUrl() ?? '';
        final url = Uri.parse("$baseUrl/api/Message/GetUnreadedMessagesCount");
        final responseRaw = await _APIRequest.getRequest(url, bearerToken: token!);
        final decoded = conv.json.decode(responseRaw);
        if (decoded['data'] != null && decoded['data']['count'] != null) {
          int count = (decoded['data']['count'] as num).toInt();
          await storage.DataCache.setUnreadMailCount(count);
          return count;
        }
      } catch (e) {
        debug.log("Hiba az olvasatlan üzenetek számának lekérésekor: $e");
      }
    }
    return storage.DataCache.getUnreadMailCount();
  }

  static Future<List<int>> getUnreadMessagesAndAllMessages()async{
    try{
      if (storage.DataCache.getIsModernApi()) {
        final unread = await getUnreadMessageCount();
        return [unread, 0, 0];
      }
      List<int> list = [];
      final json = await _getMailJson(0);
      var result = conv.json.decode(json)['NewMessagesNumber'];
      list.add(result);
      result = conv.json.decode(json)['TotalRowCount'];
      list.add(result);
      return list;
    }
    catch(_){
      return [0, 0, 0];
    }
  }

  static Future<List<MailEntry>?> getMails(int page) async{
    if(storage.DataCache.getIsDemoAccount()!){
      final now = DateTime.now();
      lastTotalRowCount = 2;
      return <MailEntry>[
        MailEntry(AppStrings.getLanguagePack().api_demo_MailSubject, AppStrings.getLanguagePack().api_demo_MailBody, AppStrings.getLanguagePack().api_demo_MailSender, now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch, false, "0"),
        MailEntry('DEMO', 'Demo Demo Demo', AppStrings.getLanguagePack().api_demo_MailSender, now.subtract(const Duration(hours: 2)).millisecondsSinceEpoch, false, "1"),
      ];
    }
    else if(storage.DataCache.getHasICSFile() ?? false){
      lastTotalRowCount = 0;
      return [];
    }

    if (storage.DataCache.getIsModernApi()) {
      try {
        final token = await storage.DataCache.getAccessToken();
        String baseUrl = storage.DataCache.getInstituteUrl() ?? '';

        int actualPage = page > 0 ? page - 1 : 0;
        int firstRow = actualPage * 20;
        int lastRow = firstRow + 20;

        // Honesty: Sep 2026 HARs still use filterType=0 for inbox (no unread-only server filter).
        final url = Uri.parse("$baseUrl/api/Message/GetReceivedMessages?firstRow=$firstRow&lastRow=$lastRow&filterType=0");
        final responseRaw = await _APIRequest.getRequest(url, bearerToken: token!);
        final decoded = conv.json.decode(responseRaw);

        List<MailEntry> modernMails = [];
        final data = decoded['data'];
        if (data != null && data['receivedMessages'] != null) {
          for (var item in data['receivedMessages']) {
            modernMails.add(MailEntry(
              item['subject'] ?? AppStrings.getLanguagePack().api_fallback_UnknownSubject,
              AppStrings.getLanguagePack().mail_preview_TapToLoadBody,
              item['senderName'] ?? AppStrings.getLanguagePack().api_fallback_Unknown,
              DateTime.parse(item['lastPostDate']).millisecondsSinceEpoch,
              item['unreadedPostCount'] == 0,
              item['messageId'].toString(),
            ));
          }
          final totalCandidate = data['totalRowCount'] ??
              data['TotalRowCount'] ??
              data['totalCount'] ??
              data['TotalCount'];
          if (totalCandidate is num) {
            lastTotalRowCount = totalCandidate.toInt();
          } else if (totalCandidate is String) {
            lastTotalRowCount = int.tryParse(totalCandidate) ?? lastTotalRowCount;
          }
        }
        return modernMails;
      } catch (e) {
        debug.log("Hiba a modern üzenetek lekérésekor: $e");
        return [];
      }
    }

    final request = await _getMailJson(page);
    List<MailEntry> mails = getMailEntrysJson(request);
    try {
      final decoded = conv.json.decode(request);
      final total = decoded['TotalRowCount'];
      if (total is num) {
        lastTotalRowCount = total.toInt();
      }
    } catch (_) {}
    return mails;
  }

  static Future<String> _getMailJson(int page)async{
    final username = storage.DataCache.getUsername();
    final password = storage.DataCache.getPassword();
    final url = Uri.parse(storage.DataCache.getInstituteUrl()! + URLs.MESSAGES_URL);
    final json = '{"UserLogin":"$username","Password":"$password","CurrentPage":$page,"TotalRowCount":-1,"MessageID":0,"MessageSortEnum":0}';
    return await _APIRequest.postRequest(url, json);
  }

  static List<MailEntry> getMailEntrysJson(String json){
    List<MailEntry> mails = [];
    final decoded = conv.json.decode(json);
    if (decoded['MessagesList'] == null) return [];
    final result = decoded['MessagesList'] as List<dynamic>;

    for(var item in result){
      mails.add(MailEntry(item['Subject'], removeBloatFromMail(item['Detail']), item['Name'], int.parse(item['SendDate'].toString().replaceAll('\/Date(', '').replaceAll(')\/', '')), !item['IsNew'], item['PersonMessageId'].toString()));
    }
    return mails;
  }

  static String removeBloatFromMail(String raw){
    var sanitised = raw.trim();
    sanitised = sanitised.replaceAll(RegExp(r'\.\w+\{[^}]*\}'), '');
    return sanitised.trim();
  }

  static Future<void> setMailRead(String id)async{
    if (storage.DataCache.getIsDemoAccount() ?? false) return;
    if (id.isEmpty) return;
    try {
      if (storage.DataCache.getIsModernApi()) {
        final token = await storage.DataCache.getAccessToken();
        if (token == null || token.isEmpty) return;
        final baseUrl = storage.DataCache.getInstituteUrl() ?? '';
        // Try modern endpoints (Neptun naming varies by version).
        final candidates = <Uri>[
          Uri.parse('$baseUrl/api/Message/SetReadedMessage'),
          Uri.parse('$baseUrl/api/Messages/SetReadedMessage'),
          Uri.parse('$baseUrl/api/Message/SetMessageAsReaded'),
        ];
        final body = conv.jsonEncode({'messageId': id, 'MessageID': id});
        for (final url in candidates) {
          try {
            final res = await _APIRequest.postRequestRaw(url, body, bearerToken: token);
            if (res.statusCode >= 200 && res.statusCode < 300) {
              final unread = storage.DataCache.getUnreadMailCount();
              if (unread > 0) {
                await storage.DataCache.setUnreadMailCount(unread - 1);
              }
              // Refresh authoritative count when possible
              await getUnreadMessageCount();
              return;
            }
          } catch (_) {}
        }
      } else {
        final username = storage.DataCache.getUsername();
        final password = storage.DataCache.getPassword();
        final url = Uri.parse(storage.DataCache.getInstituteUrl()! + URLs.MESSAGE_SET_READ);
        final json = '{"UserLogin":"$username","Password":"$password","PersonMessageId":$id}';
        await _APIRequest.postRequest(url, json);
        final unread = storage.DataCache.getUnreadMailCount();
        if (unread > 0) {
          await storage.DataCache.setUnreadMailCount(unread - 1);
        }
      }
    } catch (e) {
      debug.log('setMailRead error: $e');
    }
  }

  static String _htmlToPlain(String rawHtml) {
    return rawHtml
        .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>'), '')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }

  static Future<String> getMailContent(String messageId, String oldDetails) async {
    if (storage.DataCache.getIsDemoAccount() ?? false) {
      return oldDetails;
    }

    if (storage.DataCache.getIsModernApi()) {
      try {
        final token = await storage.DataCache.getAccessToken();
        String baseUrl = storage.DataCache.getInstituteUrl() ?? '';
        final url = Uri.parse("$baseUrl/api/Messages/$messageId/Posts?messageId=$messageId");

        String responseRaw = await _APIRequest.getRequest(url, bearerToken: token!);

        // retry if 500 status
        if (responseRaw.contains("Hiba történt") || responseRaw.contains('"statusCode":500')) {
          await Future.delayed(const Duration(milliseconds: 200));
          responseRaw = await _APIRequest.getRequest(url, bearerToken: token);
        }

        final decoded = conv.json.decode(responseRaw);

        if (decoded['data'] != null && decoded['data']['posts'] != null && decoded['data']['posts'].isNotEmpty) {
          final posts = decoded['data']['posts'] as List;
          final parts = <String>[];
          for (var i = 0; i < posts.length; i++) {
            final post = posts[i];
            if (post is! Map) continue;
            final rawHtml = post['htmlText']?.toString() ?? post['text']?.toString() ?? '';
            final clean = _htmlToPlain(rawHtml);
            if (clean.isEmpty) continue;
            final when = post['postDate']?.toString() ?? post['date']?.toString() ?? '';
            final who = post['posterName']?.toString() ?? post['senderName']?.toString() ?? '';
            final header = [if (who.isNotEmpty) who, if (when.isNotEmpty) when].join(' · ');
            if (posts.length > 1) {
              parts.add(header.isNotEmpty ? '— ${i + 1}/${posts.length} — $header\n$clean' : '— ${i + 1}/${posts.length} —\n$clean');
            } else {
              parts.add(clean);
            }
          }
          if (parts.isNotEmpty) return parts.join('\n\n');
          return AppStrings.getStringWithParams(AppStrings.getLanguagePack().api_error_EmptyNeptunResponse, [responseRaw]);
        } else {
          return AppStrings.getStringWithParams(AppStrings.getLanguagePack().api_error_EmptyNeptunResponse, [responseRaw]);
        }
      } catch (e) {
        return AppStrings.getStringWithParams(AppStrings.getLanguagePack().api_error_DownloadNetwork, [e]);
      }
    }
    return oldDetails;
  }
}
  
  class Term{
    String id;
    String termName;

    Term(dynamic id, this.termName) : id = id.toString();

    int get intId => int.tryParse(id) ?? 0;

    Map<String, dynamic> toMap() => {'id': id, 'termName': termName};
    factory Term.fromMap(Map<String, dynamic> map) => Term(map['id']?.toString() ?? '', map['termName']?.toString() ?? '');

    String serialize() => conv.jsonEncode(toMap());
    factory Term.deserialize(String str) => Term.fromMap(conv.jsonDecode(str));
  }
  
  class Subject{
    bool completed;
    int credit;
    int id;
    String name;
    int grade = 0;
    int failState = 0;
    String subjectCode;


    Subject(this.completed, this.credit, this.name, this.id, this.grade, this.failState, {this.subjectCode = ''});

    @override
    String toString() {
      return '$completed\n$credit\n$id\n$name\n$grade\n$failState\n$subjectCode';
    }

    Subject fillWithExisting(String existing){
      var data = existing.split('\n');
      if(data.length < 6){
        completed = false;
        credit = 0;
        id = 0;
        name = 'ERROR';
        grade = 0;
        failState = 1;
        subjectCode = '';
        return this;
      }
      completed = bool.parse(data[0]);
      credit = int.parse(data[1]);
      id = int.parse(data[2]);
      name = data[3];
      grade = int.parse(data[4]);
      failState = int.parse(data[5]);
      subjectCode = data.length > 6 ? data[6] : '';
      return this;
    }
  }
  
  class Institute{
    late final String Name;
    late final String URL;
  
    Institute(String name, String url){
      Name = name;
      URL = url;
    }
  
    getUrl() => Uri.parse(URL);
  }
class CalendarEntry {
  late int startEpoch;
  late int endEpoch;
  late String location;
  late String title;

  late int eventType;

  late String subjectCode;
  late String teacher;
  late String? courseType;
  late String? classInstanceId;
  late String? taskId;

  bool get isExam => eventType == 1;
  bool get isPeriodBanner => eventType == 6;
  bool get isTask => eventType > 1 && eventType != 6;

  CalendarEntry(String start, String end, String loc, String rawTitle, bool oldIsExam) {
    startEpoch = int.parse(start);
    startEpoch = DateTime.fromMillisecondsSinceEpoch(startEpoch)
        .subtract(Duration(hours: (Generic.isDaylightSavings(DateTime.fromMillisecondsSinceEpoch(startEpoch)) ? 2 : 1)))
        .millisecondsSinceEpoch;

    endEpoch = int.parse(end);
    endEpoch = DateTime.fromMillisecondsSinceEpoch(endEpoch)
        .subtract(Duration(hours: (Generic.isDaylightSavings(DateTime.fromMillisecondsSinceEpoch(endEpoch)) ? 2 : 1)))
        .millisecondsSinceEpoch;

    location = loc;
    classInstanceId = null;
    eventType = oldIsExam ? 1 : 0;

    final regex = RegExp(r'\]([^(]+)\(');
    final match = regex.firstMatch(rawTitle);
    if (match != null) {
      title = match.group(1)!.replaceAll(']', '').replaceAll('(', '').replaceAll('\u0009', '').trim();
    } else {
      title = rawTitle;
    }

    final regex2 = RegExp(r'\(([^)]+)\)');
    final matches = regex2.allMatches(rawTitle).map((m) => m.group(1)!.trim()).toList();
    if (matches.isNotEmpty) {
      subjectCode = matches[0];
    } else {
      subjectCode = "-";
    }

    if (matches.length > 2) {
      courseType = matches[1];
      teacher = matches[2];
    } else if (matches.length > 1) {
      teacher = matches[1];
      courseType = null;
    } else {
      teacher = "-";
      courseType = null;
    }
  }

  // MODERN API
  CalendarEntry.fromModern({
    required this.startEpoch,
    required this.endEpoch,
    required this.location,
    required this.title,
    required this.eventType,
    required this.subjectCode,
    required this.teacher,
    this.courseType,
    this.classInstanceId,
    this.taskId,
  });

  @override
  String toString() {
    return '$startEpoch\n$endEpoch\n$location\n$title\n$eventType\n$teacher\n$subjectCode\n${classInstanceId ?? ""}\n${taskId ?? ""}\n${courseType ?? ""}';
  }

  CalendarEntry fillWithExisting(String existing) {
    var data = existing.split('\n');
    if (data.isEmpty || data.length < 7) return this;

    startEpoch = int.parse(data[0]);
    endEpoch = int.parse(data[1]);
    location = data[2];
    title = data[3];

    if (data[4] == 'true') eventType = 1;
    else if (data[4] == 'false') eventType = 0;
    else eventType = int.parse(data[4]);

    teacher = data[5];
    subjectCode = data[6];

    if (data.length >= 8 && data[7].trim().isNotEmpty) {
      classInstanceId = data[7].trim();
    } else { classInstanceId = null; }

    if (data.length >= 9 && data[8].trim().isNotEmpty) {
      taskId = data[8].trim();
    } else { taskId = null; }

    if (data.length >= 10 && data[9].trim().isNotEmpty) {
      courseType = data[9].trim();
    } else { courseType = null; }

    return this;
  }
}

class CollectiveInvoice {
  final String name;
  final double balance;
  final String currency;
  CollectiveInvoice(this.name, this.balance, this.currency);
}

class CashinEntry{
  late String ID;
  late int ammount;
  late int dueDateMs;
  late String comment;
  late bool completed = false;
  String? direction;
  String? note;
  String? currency;

  CashinEntry(this.ammount, this.dueDateMs, this.comment, this.ID, String completedStatus, {this.direction, this.note, this.currency}){
    if(completedStatus.toLowerCase() == 'teljesített' ||
        completedStatus.toLowerCase() == 'törölt' ||
        completedStatus.toLowerCase() == 'pénzügyileg igazolt'){
      completed = true;
    }
  }

  @override
  String toString() {
    return '$ammount\n$dueDateMs\n$comment\n$completed\n$ID\n${direction ?? ''}\n${note ?? ''}\n${currency ?? ''}';
  }

  CashinEntry fillWithExisting(String existing){
    var data = existing.split('\n');
    if(data.isEmpty || data.length < 5){
      return this;
    }
    ammount = int.tryParse(data[0]) ?? 0;
    dueDateMs = int.tryParse(data[1]) ?? 0;
    comment = data[2];
    completed = bool.tryParse(data[3]) ?? false;
    ID = data[4];
    if (data.length > 5) direction = data[5].isNotEmpty ? data[5] : null;
    if (data.length > 6) note = data[6].isNotEmpty ? data[6] : null;
    if (data.length > 7) currency = data[7].isNotEmpty ? data[7] : null;
    return this;
  }
}


  
  enum PeriodType{
    timetableRegistration,
    gradingTime,
    loginTime,
    pregivenGradingAccepting,
    timetableFinalization,
    coursesRegistration,
    nerdTime,
    examTime,
    signinTime,
    none
  }
  
  class PeriodEntry{
    late String name;
    late int startEpoch;
    late int endEpoch;
    late bool isActive;
    late int partofSemester;
    late PeriodType type;
  
    PeriodEntry(this.name, int startEpoch, int endEpoch, this.partofSemester){
      final startEp = DateTime.fromMillisecondsSinceEpoch(startEpoch);
      final correctedStartEpoch = DateTime(startEp.year, startEp.month, startEp.day);
      this.startEpoch = correctedStartEpoch.millisecondsSinceEpoch;
  
      final endEp = DateTime.fromMillisecondsSinceEpoch(endEpoch).add(const Duration(days: 1)); // last day counts too
      var correctedEndEpoch = DateTime(endEp.year, endEp.month, endEp.day);
      final isOverflowedByOneDay = endEp.add(Duration(minutes: 1)).hour == 1;
      if(isOverflowedByOneDay){
        correctedEndEpoch = correctedEndEpoch.subtract(Duration(days: 1));
      }
      this.endEpoch = correctedEndEpoch.millisecondsSinceEpoch;
  
  
      fillIsActiveStatus();
    }
  
    @override
    String toString() {
      return '$name\n$startEpoch\n$endEpoch\n$partofSemester';
    }
  
    String getValue(){
      return '$startEpoch-$endEpoch';
    }
  
    PeriodEntry fillWithExisting(String existing){
      var data = existing.split('\n');
      if(data.isEmpty || data.length < 4){
        return this;
      }
      name = data[0];
      startEpoch = int.tryParse(data[1]) ?? 0;
      endEpoch = int.parse(data[2]);
      partofSemester = int.parse(data[3]);
      fillIsActiveStatus();
      return this;
    }
  
    void fillIsActiveStatus() {
      final now = DateTime.now().millisecondsSinceEpoch;
      isActive = (startEpoch <= now && now <= endEpoch);

      final lower = name.toLowerCase().trim();
      if (lower.contains('előzetes tárgyjelentkezés') || lower.contains('tárgyfelvétel')) {
        type = PeriodType.timetableRegistration;
      } else if (lower.contains('jegybeírás') || lower.contains('értékelés')) {
        type = PeriodType.gradingTime;
      } else if (lower.contains('bejelentkezés') || lower.contains('regisztráció')) {
        type = PeriodType.loginTime;
      } else if (lower.contains('megajánlott jegy')) {
        type = PeriodType.pregivenGradingAccepting;
      } else if (lower.contains('végleges tárgyjelentkezés')) {
        type = PeriodType.timetableFinalization;
      } else if (lower.contains('kurzusjelentkezés') || lower.contains('kurzusfelvétel')) {
        type = PeriodType.coursesRegistration;
      } else if (lower.contains('szorgalmi')) {
        type = PeriodType.nerdTime;
      } else if (lower.contains('vizsga')) {
        type = PeriodType.examTime;
      } else if (lower.contains('beiratkozás')) {
        type = PeriodType.signinTime;
      } else {
        type = PeriodType.none;
      }
    }
  }

  class MailEntry{
    String subject;
    String detail;
    String senderName;
    int sendDateMs;
    bool isRead;
    String ID;

    MailEntry(this.subject, this.detail, this.senderName, this.sendDateMs, this.isRead, this.ID);

    @override
    String toString() {
      return '$subject\u0000$detail\u0000$senderName\u0000$sendDateMs\u0000$isRead\u0000$ID';
    }

    MailEntry fillWithExisting(String existing){
      var data = existing.split('\u0000');
      if(data.isEmpty || data.length < 6){
        return this;
      }
      subject = data[0];
      detail = data[1];
      senderName = data[2];
      sendDateMs = int.parse(data[3]);
      isRead = bool.parse(data[4]);
      ID = data[5];
      return this;
    }
  }
  
  class Generic {
    static String reactionForAvg(double avg) {
      if (avg >= 5.0) {
        return "💀";
      }
      else if (avg >= 4.25) {
        return "🤓";
      }
      else if (avg >= 3.75) {
        return "😌";
      }
      else if (avg >= 2.75) {
        return "😐";
      }
      else if (avg >= 2) {
        return "😬";
      }
      else if (avg > 0) {
        return "🤡";
      }
      else {
        return '🤗';
      }
    }

    static String _capitalizeFirst(String value) {
      if (value.isEmpty) return value;
      return value[0].toUpperCase() + value.substring(1);
    }

    /// Calendar week subtitle: locale-appropriate month/day (not generic [monthToText] punctuation).
    static String calendarWeekDateLabel(DateTime date) {
      final lang = AppStrings.getCurrentLangCode();
      final month = monthToText(date.month);
      final day = date.day;
      switch (lang) {
        case 'hu':
          return '$month $day.';
        case 'ru':
          return '$day $month';
        default:
          return '${_capitalizeFirst(month)}\u00A0$day';
      }
    }

    static String calendarWeekDateRange(DateTime from, DateTime to) {
      if (from.year == to.year &&
          from.month == to.month &&
          from.day == to.day) {
        return calendarWeekDateLabel(to);
      }
      final lang = AppStrings.getCurrentLangCode();
      if (from.year == to.year && from.month == to.month) {
        final monthRaw = monthToText(from.month);
        switch (lang) {
          case 'hu':
            return '$monthRaw ${from.day}.\u00A0–\u00A0${to.day}.';
          case 'ru':
            return '${from.day}\u00A0–\u00A0${to.day} $monthRaw';
          default:
            final month = _capitalizeFirst(monthRaw);
            return '$month ${from.day}\u2013$to.day';
        }
      }
      const rangeSep = '\u00A0–\u00A0';
      return '${calendarWeekDateLabel(from)}$rangeSep${calendarWeekDateLabel(to)}';
    }

    static String monthToText(int month) {
      switch (month) {
        case 1:
          return AppStrings.getLanguagePack().api_monthJan_Universal;
        case 2:
          return AppStrings.getLanguagePack().api_monthFeb_Universal;
        case 3:
          return AppStrings.getLanguagePack().api_monthMar_Universal;
        case 4:
          return AppStrings.getLanguagePack().api_monthApr_Universal;
        case 5:
          return AppStrings.getLanguagePack().api_monthMay_Universal;
        case 6:
          return AppStrings.getLanguagePack().api_monthJun_Universal;
        case 7:
          return AppStrings.getLanguagePack().api_monthJul_Universal;
        case 8:
          return AppStrings.getLanguagePack().api_monthAug_Universal;
        case 9:
          return AppStrings.getLanguagePack().api_monthSep_Universal;
        case 10:
          return AppStrings.getLanguagePack().api_monthOkt_Universal;
        case 11:
          return AppStrings.getLanguagePack().api_monthNov_Universal;
        case 12:
          return AppStrings.getLanguagePack().api_monthDec_Universal;
      }
      return "NULL";
    }

    static String dayToText(int day){
      switch(day){
        case 1:
          return AppStrings.getLanguagePack().api_dayMon_Universal;
        case 2:
          return AppStrings.getLanguagePack().api_dayTue_Universal;
        case 3:
          return AppStrings.getLanguagePack().api_dayWed_Universal;
        case 4:
          return AppStrings.getLanguagePack().api_dayThu_Universal;
        case 5:
          return AppStrings.getLanguagePack().api_dayFri_Universal;
        case 6:
          return AppStrings.getLanguagePack().api_daySat_Universal;
        case 7:
          return AppStrings.getLanguagePack().api_daySun_Universal;
        default:
          return '';
      }
    }

    static String capitalizePeriodText(String periodName) {
      final chars = periodName
          .toLowerCase()
          .trim()
          .characters
          .toList();
      String str = '';
      int idx = 0;
      bool setNexttoCapitalize = false;
      for (var item in chars) {
        if (idx == 0 || setNexttoCapitalize) {
          str += item.toUpperCase();
          idx++;
          setNexttoCapitalize = false;
          continue;
        }
        if (item == ' ') {
          setNexttoCapitalize = true;
        }
        str += item;
        idx++;
      }
      return str;
    }

    static String randomLoadingComment(bool familyFriendlyMode) {
      if (!familyFriendlyMode) {
        final gen = Random().nextInt(100) % 7;
        switch (gen) {
          case 0:
            return AppStrings.getLanguagePack().api_loadingScreenHintFriendly1_Universal;
          case 1:
            return AppStrings.getLanguagePack().api_loadingScreenHintFriendly2_Universal;
          case 2:
            return AppStrings.getLanguagePack().api_loadingScreenHintFriendly3_Universal;
          case 3:
            return AppStrings.getLanguagePack().api_loadingScreenHintFriendly4_Universal;
          case 4:
            return AppStrings.getLanguagePack().api_loadingScreenHintFriendly5_Universal;
          case 5:
            return AppStrings.getLanguagePack().api_loadingScreenHintFriendly6_Universal;
          case 6:
            return AppStrings.getLanguagePack().api_loadingScreenHintFriendly7_Universal;
          default:
            return 'Neptun 2';
        }
      }
      final gen = Random().nextInt(100) % 7;
      switch (gen) {
        case 0:
          return AppStrings.getLanguagePack().api_loadingScreenHint1_Universal;
        case 1:
          return AppStrings.getLanguagePack().api_loadingScreenHint2_Universal;
        case 2:
          return AppStrings.getLanguagePack().api_loadingScreenHint3_Universal;
        case 3:
          return AppStrings.getLanguagePack().api_loadingScreenHint4_Universal;
        case 4:
          return AppStrings.getLanguagePack().api_loadingScreenHint5_Universal;
        case 5:
          return AppStrings.getLanguagePack().api_loadingScreenHint6_Universal;
        case 6:
          return AppStrings.getLanguagePack().api_loadingScreenHint7_Universal;
        default:
          return 'Neptun 2';
      }
    }
    static String randomLoadingCommentMini(bool familyFriendlyMode) {
      if (!familyFriendlyMode) {
        final gen = Random().nextInt(100) % 4;
        switch (gen) {
          case 0:
            return AppStrings.getLanguagePack().api_loadingScreenHintFriendlyMini1_Universal;
          case 1:
            return AppStrings.getLanguagePack().api_loadingScreenHintFriendlyMini2_Universal;
          case 2:
            return AppStrings.getLanguagePack().api_loadingScreenHintFriendlyMini3_Universal;
          case 3:
            return AppStrings.getLanguagePack().api_loadingScreenHintFriendlyMini4_Universal;
          default:
            return 'Neptun 2';
        }
      }
      final gen = Random().nextInt(100) % 3;
      switch (gen) {
        case 0:
          return AppStrings.getLanguagePack().api_loadingScreenHintMini1_Universal;
        case 1:
          return AppStrings.getLanguagePack().api_loadingScreenHintMini2_Universal;
        case 2:
          return AppStrings.getLanguagePack().api_loadingScreenHintMini3_Universal;
        default:
          return 'Neptun 2';
      }
    }

    static List<InlineSpan> textToInlineSpan(String text) {
      List<InlineSpan> spans = [];

      final htmlLink = RegExp(r'<a[^>]*>(.*?)</a>|https?://\S+|mailto:\S+');

      // Split the text at anchor tags using the regex pattern
      List<String> matches = htmlLink.allMatches(text)
          .map((m) => m.group(0)!)
          .toList();
      List<String> parts = text.split(htmlLink);

      for (int i = 0; i < parts.length; i++) {
        spans.add(TextSpan(text: parts[i]));
        if (i < matches.length) {
          if (matches[i].startsWith('<a')) {
            final htmlLink2 = RegExp(r'>(.*?)</a>');
            final match = htmlLink2.firstMatch(matches[i]);
            if (match == null) {
              continue;
            }
            String newText = match.group(1)!;

            if(!newText.contains('@') || !newText.contains('https://') || !newText.contains('http://')){
              final htmlLink3 = RegExp(r'href="(.*?)"');
              final match = htmlLink3.firstMatch(matches[i]);
              if (match == null) {
                break;
              }
              final url = match.group(1)!;
              spans.add(ClickableTextSpan.getNewClickableSpan(
                  ClickableTextSpan.getNewOpenLinkCallback(url), newText,
                  ClickableTextSpan.getStockStyle()));
            }
            else{
              final isMailTo = newText.contains('@') &&
                  !(newText.contains('https://') || newText.contains('http://'));

              spans.add(ClickableTextSpan.getNewClickableSpan(
                  ClickableTextSpan.getNewOpenLinkCallback(
                      isMailTo ? 'mailto:$newText' : newText.contains('www.') && !newText.contains('http:') ? 'https://$newText' : newText), newText,
                  ClickableTextSpan.getStockStyle()));
            }
          }
          else {
            // Handle URLs
            String url = matches[i];
            spans.add(ClickableTextSpan.getNewClickableSpan(
                ClickableTextSpan.getNewOpenLinkCallback(url), url,
                ClickableTextSpan.getStockStyle()));
          }
        }
      }

      return spans;
    }

    static void setupDaylightSavingsTime(){
      final now = DateTime.now();
      var probableSunday = DateTime(now.year, 3, 31, 0, 0, 0);
      if(probableSunday.weekday == 7){
        daylightSavingsTimeFrom = probableSunday;
      }
      else{
        daylightSavingsTimeFrom = probableSunday.subtract(Duration(days: probableSunday.weekday));
        if(daylightSavingsTimeFrom.hour != 0){
          daylightSavingsTimeFrom = DateTime(daylightSavingsTimeFrom.year, daylightSavingsTimeFrom.month, daylightSavingsTimeFrom.day + 1);
        }
      }

      probableSunday = DateTime(now.year, 10, 31, 0, 0, 0);
      if(probableSunday.weekday == 7){
        daylightSavingsTimeTo = probableSunday;
      }
      else{
        daylightSavingsTimeTo = probableSunday.subtract(Duration(days: probableSunday.weekday));
      }
    }

    static DateTime daylightSavingsTimeFrom = DateTime(DateTime.now().year, 3, 31, 0, 0, 0);
    static DateTime daylightSavingsTimeTo = DateTime(DateTime.now().year, 10, 27, 0, 0, 0);

    static bool isDaylightSavings(DateTime time){
      return (daylightSavingsTimeFrom.microsecondsSinceEpoch < time.microsecondsSinceEpoch && time.microsecondsSinceEpoch < daylightSavingsTimeTo.microsecondsSinceEpoch);
    }
  }

  class Language{
    static Future<bool> checkSupportedUserLanguage()async{
      final deviceLang = Platform.localeName.split('_')[0].toLowerCase();
      // check language
      final allLang = await Language.getAllLanguages();
      return Language.getHasLanguageById(allLang, deviceLang);
    }

    static bool getHasLanguageById(List<LangPackMap>? languages, String neededId){
      if(languages == null){
        return false;
      }
      for(var item in languages){
        if(item.langId == neededId){
          return true;
        }
      }
      return false;
    }

    static Future<LanguagePack?> getLanguagePackById(List<LangPackMap>? languages, String neededID)async{
      if(languages == null){
        return null;
      }
      String? langUrl;
      for(var item in languages){
        if(item.langId == neededID){
          langUrl = item.langURL;
          break;
        }
      }
      if(langUrl == null){
        return null;
      }

      final url = Uri.parse(langUrl);
      final response = await http.get(url);
      if (response.statusCode != 200) {
        return null;
      }
      return LanguagePack.fromJson(neededID, response.body, (){}); // auto registers itself, as its downloaded, no need for the callback, def not invalid as it has just been downloaded
    }

    static List<LangPackMap>? _langMapCache;
    static List<LangPackMap> getAllLanguagesWithNative(){
      final nativeList = <LangPackMap>[
        LangPackMap(langName: 'English', langId: 'en', langURL: '', langFlag: '🇺🇸/🇬🇧'),
        LangPackMap(langName: 'Magyar', langId: 'hu', langURL: '', langFlag: '🇭🇺')];

      if(!DataCache.getHasNetwork()){
        return nativeList;
      }
      return nativeList + (_langMapCache == null ? <LangPackMap>[].toList() : _langMapCache!);
    }

    static Future<List<LangPackMap>?> getAllLanguages()async{
      if(_langMapCache != null){
        return _langMapCache;
      }
      try {
        final url = Uri.parse('https://raw.githubusercontent.com/Nanda070/Neptun-ELTE/refs/heads/main/Languages/supportedLanguages.json');
        final response = await http.get(url);

        if (response.statusCode != 200) {
          return null;
        }

        Map<String, dynamic> jsonMap = conv.json.decode(response.body);
        final allLangItems = jsonMap['languagesMap'] as List<dynamic>;
        final List<LangPackMap> langPacksRoot = [];
        for (var item in allLangItems){
          langPacksRoot.add(LangPackMap.fromMap(item));
        }
        _langMapCache = langPacksRoot;
        return langPacksRoot;
      } catch (e) {
        return null;
      }
    }
  }

  class LangPackMap{
    final String langName;
    final String langFlag;
    final String langId;
    final String langURL;

    const LangPackMap({required this.langName, required this.langId, required this.langURL, required this.langFlag});

    static LangPackMap fromMap(Map<String, dynamic> json){
      return LangPackMap(langName: json['langName'], langId: json['langId'], langURL: json['langURL'], langFlag: json['langFlag']);
    }
  }

  class Coloring{
    static List<ThemePackMap>? _themeMapCache;

    static List<ThemePackMap>? getAllThemesCache(){
      return _themeMapCache;
    }

    static Future<List<ThemePackMap>?> getAllThemes()async{
      if(_themeMapCache != null){
        return _themeMapCache;
      }
      try {
        final url = Uri.parse('https://raw.githubusercontent.com/Nanda070/Neptun-ELTE/refs/heads/main/Themes/supportedThemes.json');
        final response = await http.get(url);

        if (response.statusCode != 200) {
          return null;
        }

        Map<String, dynamic> jsonMap = conv.json.decode(response.body);
        final allThemeItems = jsonMap['themesMap'] as List<dynamic>;
        final List<ThemePackMap> themePacksRoot = [];
        for (var item in allThemeItems){
          themePacksRoot.add(ThemePackMap.fromMap(item));
        }
        _themeMapCache = themePacksRoot;
        return themePacksRoot;
      } catch (e) {
        return null;
      }
    }

    static Future<AppPalette?> getThemePackById(List<ThemePackMap>? themes, String neededID)async{
      if(themes == null){
        return null;
      }
      String? themeUrl;
      for(var item in themes){
        if(item.themeName == neededID){
          themeUrl = item.themeUrl;
          break;
        }
      }
      if(themeUrl == null){
        return null;
      }

      final url = Uri.parse(themeUrl);
      final response = await http.get(url);
      if (response.statusCode != 200) {
        return null;
      }
      return AppPalette.fromJson(response.body, (){}); // auto registers itself, as its downloaded, no need for the callback, def not invalid as it has just been downloaded
    }
  }

  class ThemePackMap{
    final String themeName;
    final String themeUrl;
    final Color themepackAccent;

    const ThemePackMap({required this.themeName, required this.themeUrl, required this.themepackAccent});

    static ThemePackMap fromMap(Map<String, dynamic> json){
      return ThemePackMap(themeName: json['themeName'], themeUrl: json['themeURL'], themepackAccent: Color(json['themeAccent']));
    }
  }
  
  class NeptunCerts extends HttpOverrides {
    static NeptunCerts? _instance;
    static bool hasValidCertificate = true;

    static NeptunCerts getCerts(){
      if(_instance != null){
        return _instance!;
      }
      return NeptunCerts();
    }

    NeptunCerts(){
      _instance = this;
    }
    @override
    HttpClient createHttpClient(SecurityContext? context) {
      return super.createHttpClient(context)
        ..badCertificateCallback = (X509Certificate cert, String host, int port) {
          return true;
        };
    }
  }