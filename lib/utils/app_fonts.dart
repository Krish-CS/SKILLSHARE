import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppFonts {
  static const String _nativeFontFamily = 'SourceSerif4';
  static const String _nativePacificoFontFamily = 'Pacifico';

  static TextTheme loraTextTheme(TextTheme base) {
    return base.apply(fontFamily: _nativeFontFamily);
  }

  static TextStyle lora({
    TextStyle? textStyle,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    List<Shadow>? shadows,
  }) {
    return _textStyle(
      webBuilder: () => GoogleFonts.lora(
        textStyle: textStyle,
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        height: height,
        shadows: shadows,
      ),
      textStyle: textStyle,
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      shadows: shadows,
    );
  }

  static TextStyle pacifico({
    TextStyle? textStyle,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    List<Shadow>? shadows,
  }) {
    return (textStyle ?? const TextStyle()).copyWith(
      fontFamily: _nativePacificoFontFamily,
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      shadows: shadows,
    );
  }

  static TextStyle dancingScript({TextStyle? textStyle, Color? color, double? fontSize, FontWeight? fontWeight, double? letterSpacing, double? height, List<Shadow>? shadows}) =>
      _generic(
        webBuilder: () => GoogleFonts.dancingScript(
          textStyle: textStyle,
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing,
          height: height,
          shadows: shadows,
        ),
        textStyle: textStyle,
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        height: height,
        shadows: shadows,
      );

  static TextStyle oswald({TextStyle? textStyle, Color? color, double? fontSize, FontWeight? fontWeight, double? letterSpacing, double? height, List<Shadow>? shadows}) =>
      _generic(
        webBuilder: () => GoogleFonts.oswald(
          textStyle: textStyle,
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing,
          height: height,
          shadows: shadows,
        ),
        textStyle: textStyle,
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        height: height,
        shadows: shadows,
      );

  static TextStyle lexend({TextStyle? textStyle, Color? color, double? fontSize, FontWeight? fontWeight, double? letterSpacing, double? height, List<Shadow>? shadows}) =>
      _generic(
        webBuilder: () => GoogleFonts.lexend(
          textStyle: textStyle,
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing,
          height: height,
          shadows: shadows,
        ),
        textStyle: textStyle,
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        height: height,
        shadows: shadows,
      );

  static TextStyle playfairDisplay({TextStyle? textStyle, Color? color, double? fontSize, FontWeight? fontWeight, double? letterSpacing, double? height, List<Shadow>? shadows}) =>
      _generic(
        webBuilder: () => GoogleFonts.playfairDisplay(
          textStyle: textStyle,
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing,
          height: height,
          shadows: shadows,
        ),
        textStyle: textStyle,
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        height: height,
        shadows: shadows,
      );

  static TextStyle lobster({TextStyle? textStyle, Color? color, double? fontSize, FontWeight? fontWeight, double? letterSpacing, double? height, List<Shadow>? shadows}) =>
      _generic(
        webBuilder: () => GoogleFonts.lobster(
          textStyle: textStyle,
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing,
          height: height,
          shadows: shadows,
        ),
        textStyle: textStyle,
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        height: height,
        shadows: shadows,
      );

  static TextStyle raleway({TextStyle? textStyle, Color? color, double? fontSize, FontWeight? fontWeight, double? letterSpacing, double? height, List<Shadow>? shadows}) =>
      _generic(
        webBuilder: () => GoogleFonts.raleway(
          textStyle: textStyle,
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing,
          height: height,
          shadows: shadows,
        ),
        textStyle: textStyle,
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        height: height,
        shadows: shadows,
      );

  static TextStyle spaceMono({TextStyle? textStyle, Color? color, double? fontSize, FontWeight? fontWeight, double? letterSpacing, double? height, List<Shadow>? shadows}) =>
      _generic(
        webBuilder: () => GoogleFonts.spaceMono(
          textStyle: textStyle,
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing,
          height: height,
          shadows: shadows,
        ),
        textStyle: textStyle,
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        height: height,
        shadows: shadows,
      );

  static TextStyle caveat({TextStyle? textStyle, Color? color, double? fontSize, FontWeight? fontWeight, double? letterSpacing, double? height, List<Shadow>? shadows}) =>
      _generic(
        webBuilder: () => GoogleFonts.caveat(
          textStyle: textStyle,
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing,
          height: height,
          shadows: shadows,
        ),
        textStyle: textStyle,
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        height: height,
        shadows: shadows,
      );

  static TextStyle satisfy({TextStyle? textStyle, Color? color, double? fontSize, FontWeight? fontWeight, double? letterSpacing, double? height, List<Shadow>? shadows}) =>
      _generic(
        webBuilder: () => GoogleFonts.satisfy(
          textStyle: textStyle,
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing,
          height: height,
          shadows: shadows,
        ),
        textStyle: textStyle,
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        height: height,
        shadows: shadows,
      );

  static TextStyle righteous({TextStyle? textStyle, Color? color, double? fontSize, FontWeight? fontWeight, double? letterSpacing, double? height, List<Shadow>? shadows}) =>
      _generic(
        webBuilder: () => GoogleFonts.righteous(
          textStyle: textStyle,
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing,
          height: height,
          shadows: shadows,
        ),
        textStyle: textStyle,
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        height: height,
        shadows: shadows,
      );

  static TextStyle _generic({
    required TextStyle Function() webBuilder,
    TextStyle? textStyle,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    List<Shadow>? shadows,
  }) {
    return _textStyle(
      webBuilder: webBuilder,
      textStyle: textStyle,
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      shadows: shadows,
    );
  }

  static TextStyle _textStyle({
    required TextStyle Function() webBuilder,
    TextStyle? textStyle,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    List<Shadow>? shadows,
  }) {
    // Keep typography deterministic across platforms by relying on bundled
    // fonts instead of runtime Google Fonts fetching.
    final _ = webBuilder;
    return (textStyle ?? const TextStyle()).copyWith(
      fontFamily: _nativeFontFamily,
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      shadows: shadows,
    );
  }
}
