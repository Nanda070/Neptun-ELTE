import 'package:flutter/material.dart';

/// Drop leading emoji / symbol runs so Material [Icon] rows are not doubled
/// (e.g. gear icon + "⚙ Settings"). Keeps the first letter/digit onward.
String stripLeadingEmoji(String raw) {
  final chars = raw.characters;
  final buf = StringBuffer();
  var started = false;
  final letterOrDigit = RegExp(r'\p{L}|\p{N}', unicode: true);
  for (final c in chars) {
    if (!started) {
      if (!letterOrDigit.hasMatch(c)) continue;
      started = true;
    }
    buf.write(c);
  }
  final out = buf.toString().trim();
  return out.isEmpty ? raw.trim() : out;
}

class EmojiRichText extends StatelessWidget {
  final String text;
  final TextStyle defaultStyle;
  final TextStyle emojiStyle;
  final TextAlign textAlign;
  const EmojiRichText({super.key, required this.text, required this.defaultStyle, required this.emojiStyle, this.textAlign = TextAlign.start});

  List<EmojiRichTextHelper> getSeparatedText(){
    List<EmojiRichTextHelper> construct = [];
    final chars = text.characters;

    bool flip = false;
    String str = "";

    for (var char in chars){
      if(flip ? isEmoji(char) : !isEmoji(char)){
        str += char;
      }
      else{
        construct.add(EmojiRichTextHelper(text: str, isEmoji: flip));
        str = "";
        flip = !flip;

        str += char;
      }
    }
    if(str.isNotEmpty){
      construct.add(EmojiRichTextHelper(text: str, isEmoji: flip));
    }

    return construct;
  }

  @override
  Widget build(BuildContext context) {
    final List<TextSpan> textSpans = [];
    final textHelper = getSeparatedText();

    for (var txtHelper in textHelper) {
      textSpans.add(TextSpan(
        text: txtHelper.text,
        // Color emoji fonts (Noto / platform) paint their own glyphs. Applying
        // [TextStyle.color] draws a tinted monochrome silhouette underneath →
        // duplicate “ghost” emoji (e.g. 🐞 Bug report in drawer / Settings).
        style: txtHelper.isEmoji ? _untintedEmojiStyle(emojiStyle) : defaultStyle,
      ));
    }

    return Text.rich(
      TextSpan(children: textSpans),
      textAlign: textAlign,
    );
  }

  /// Keep size / family from [emojiStyle] but drop color / foreground tint.
  static TextStyle _untintedEmojiStyle(TextStyle style) {
    return TextStyle(
      inherit: false,
      fontSize: style.fontSize,
      fontFamily: style.fontFamily,
      fontFamilyFallback: style.fontFamilyFallback,
      height: style.height,
      letterSpacing: style.letterSpacing,
      wordSpacing: style.wordSpacing,
      fontWeight: style.fontWeight,
      fontStyle: style.fontStyle,
      // Intentionally no [color] / [foreground] — prevents ghost duplicates.
    );
  }

  // Check if the given Unicode code points represent an emoji
  bool isEmoji(String str){
    final languagePattern = RegExp(
      r'\p{L}|[\x00-\x7F]',
      unicode: true,
    );
    return !languagePattern.hasMatch(str);
  }
}

class EmojiRichTextHelper{
  final String text;
  final bool isEmoji;
  const EmojiRichTextHelper({required this.text, required this.isEmoji});
}