// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

//
// Flutter has a color profile issue so colors will look different
// on Apple devices.
// https://github.com/flutter/flutter/issues/55092
// https://github.com/flutter/flutter/issues/39113
//

extension LKColors on Colors {
  static const lkBlue = Color(0xFF5A8BFF);
  static const lkDarkBlue = Color(0xFF00153C);
    static const lkAccent = Color(0xFFFFC107); // Amber accent
  static const lkGrey = Color(0xFFB0BEC5); // Light grey
  static const lkSuccessGreen = Color(0xFF4CAF50); // Success color
  static const lkErrorRed = Color(0xFFD32F2F); // Error color
  static const lkLightBlue = Color(0xFFE3F2FD);
}

class LiveKitTheme {
  //
  final bgColor = const Color.fromARGB(255, 100, 59, 59);
  final textColor = Colors.white;
  final cardColor = LKColors.lkDarkBlue;
  final accentColor = LKColors.lkBlue;

  ThemeData buildThemeData(BuildContext ctx) => ThemeData(
        appBarTheme: AppBarTheme(
          backgroundColor: cardColor,
        ),
        cardColor: cardColor,
        scaffoldBackgroundColor: bgColor,
        canvasColor: bgColor,
        iconTheme: IconThemeData(
          color: textColor,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            textStyle:
                WidgetStateProperty.all<TextStyle>(GoogleFonts.montserrat(
              fontSize: 15,
            )),
            padding: WidgetStateProperty.all<EdgeInsets>(
                const EdgeInsets.symmetric(vertical: 20, horizontal: 25)),
            shape: WidgetStateProperty.all<OutlinedBorder>(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
            // backgroundColor: WidgetStateProperty.all<Color>(accentColor),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return accentColor.withOpacity(0.5);
              }
              return accentColor;
            }),
          ),
        ),
        checkboxTheme: CheckboxThemeData(
          checkColor: WidgetStateProperty.all(Colors.white),
          fillColor: WidgetStateProperty.all(accentColor),
        ),
        switchTheme: SwitchThemeData(
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return accentColor;
            }
            return accentColor.withOpacity(0.3);
          }),
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return Colors.white.withOpacity(0.3);
          }),
        ),
        dialogTheme: DialogTheme(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        textTheme: GoogleFonts.montserratTextTheme(
          Theme.of(ctx).textTheme,
        ).apply(
          displayColor: textColor,
          bodyColor: textColor,
          decorationColor: textColor,
        ),
        hintColor: Colors.red,
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: const TextStyle(
            color: LKColors.lkBlue,
          ),
          hintStyle: TextStyle(
            color: LKColors.lkBlue.withOpacity(.5),
          ),
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.white,
          surface: bgColor,
        ),
      );
}
