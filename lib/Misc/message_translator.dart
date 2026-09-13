import 'dart:convert' as conv;
import 'package:http/http.dart' as http;

/// Lightweight HU→EN/RU translation for message bodies.
/// Uses the public Google Translate `client=gtx` endpoint (no API key).
/// Offline / failure → returns null; caller must keep the original text.
class MessageTranslator {
  static const _timeout = Duration(seconds: 12);

  static Future<String?> translateHuTo({
    required String text,
    required String targetLang,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final tl = targetLang.toLowerCase();
    if (tl != 'en' && tl != 'ru') return null;

    try {
      // Chunk long messages to stay within URL limits.
      final chunks = <String>[];
      const maxChunk = 900;
      for (var i = 0; i < trimmed.length; i += maxChunk) {
        final end = (i + maxChunk < trimmed.length) ? i + maxChunk : trimmed.length;
        chunks.add(trimmed.substring(i, end));
      }

      final out = StringBuffer();
      for (final chunk in chunks) {
        final uri = Uri.https('translate.googleapis.com', '/translate_a/single', {
          'client': 'gtx',
          'sl': 'hu',
          'tl': tl,
          'dt': 't',
          'q': chunk,
        });
        final res = await http.get(uri).timeout(_timeout);
        if (res.statusCode != 200) return null;
        final decoded = conv.jsonDecode(res.body);
        if (decoded is! List || decoded.isEmpty || decoded[0] is! List) return null;
        for (final part in decoded[0]) {
          if (part is List && part.isNotEmpty && part[0] != null) {
            out.write(part[0].toString());
          }
        }
      }
      final result = out.toString().trim();
      return result.isEmpty ? null : result;
    } catch (_) {
      return null;
    }
  }
}
