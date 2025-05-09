import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_window_close/flutter_window_close.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:video_meeting_room/pages/login.dart';
import 'package:video_meeting_room/providers/PinnedParticipantProvider.dart';
import 'package:video_meeting_room/service_locator.dart';
import 'package:video_meeting_room/theme.dart';
// Adjust import as necessary
import 'utils.dart';

void main() {
  runZonedGuarded(() async {
    // Ensure binding is initialized in the same zone
    WidgetsFlutterBinding.ensureInitialized();

    // Optional: Make zone mismatch fatal in dev
    BindingBase.debugZoneErrorsAreFatal = true;

    // Set up logging
    Logger.root.level = Level.FINE;
    Logger.root.onRecord.listen((record) {
      // print('${format.format(record.time)}: ${record.message}');
    });

    if (lkPlatformIsDesktop()) {
      await FlutterWindowClose.setWindowShouldCloseHandler(() async {
        await onWindowShouldClose?.call();
        return true;
      });
    }

    setup();

    // Flutter error handler
    FlutterError.onError = (FlutterErrorDetails details) {
      print('Flutter error: ${details.exceptionAsString()}');
      print('Stack trace: ${details.stack}');
    };

    runApp(
      ChangeNotifierProvider(
        create: (_) => PinnedParticipantProvider(),
        child: const LiveKitExampleApp(),
      ),
    );
  }, (error, stackTrace) {
    print('Uncaught error: $error');
    print('Stack: $stackTrace');
  });
}
class LiveKitExampleApp extends StatelessWidget {
  const LiveKitExampleApp({
    super.key,
  });

  // ThemeData _buildThemeData(BuildContext context) {
  //   final themeManager = ThemeManager();
  //    themeManager.setSkyBlueTheme();

  //   return themeManager.getThemeData(context);
  // }
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'R Systems Connect',
        theme: LiveKitTheme().buildThemeData(context),
        home: Scaffold(
          body: Stack(
            children: [
              // Main content (LoginPage) on top of the background
              Positioned.fill(
                child: Container(
                  color:
                      Colors.transparent, // Ensure the container is transparent
                  child: const LoginPage(),
                ),
              ),
            ],
          ),
        ),
      );
}
