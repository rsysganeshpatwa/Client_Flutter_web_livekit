import 'package:flutter/material.dart';
import 'package:flutter_window_close/flutter_window_close.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:logging/logging.dart';
import 'package:intl/intl.dart';
import 'package:video_meeting_room/pages/connect-widget/LiveKitIngressPage.dart';
import 'package:video_meeting_room/pages/login.dart';
import 'package:video_meeting_room/service_locator.dart';
import 'package:video_meeting_room/theme.dart';

// Adjust import as necessary
import 'utils.dart';

void main() async {
  final format = DateFormat('HH:mm:ss');
  // configure logs for debugging
  Logger.root.level = Level.FINE;
  Logger.root.onRecord.listen((record) {
    //  print('${format.format(record.time)}: ${record.message}');
  });

  WidgetsFlutterBinding.ensureInitialized();

  if (lkPlatformIsDesktop()) {
    await FlutterWindowClose.setWindowShouldCloseHandler(() async {
      await onWindowShouldClose?.call();
      return true;
    });
  }
  setup();

  // ErrorWidget.builder = (FlutterErrorDetails details) {
  //   print('ganesh Error: ${details.exception} ${details.stack} ${details.library}');
  //   return Container(
  //     color: Colors.white,
  //     child: Center(
  //       child: Text(
  //         'An error occurred. Please restart the app.',
  //         style: TextStyle(color: Colors.red),
  //       ),
  //     ),
  //   );
  // };

  runApp(const LiveKitExampleApp());
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
                  child: LiveKitIngressPage(),
                ),
              ),
            ],
          ),
        ),
      );
}
