import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_window_close/flutter_window_close.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:logging/logging.dart';
import 'package:intl/intl.dart';
import 'package:video_meeting_room/pages/login.dart';
import 'package:video_meeting_room/service_locator.dart';
import 'package:video_meeting_room/theme.dart';
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
  await dotenv.load();
   setup();

     ErrorWidget.builder = (FlutterErrorDetails details) {
      print(details.exception);
      print(details.stack);
      print(details.library);
    // Return a custom widget when an error occurs
    return Center(
      child: Text(
        'Something went wrong! ${details.library}', // Custom error message
        style: TextStyle(color: Colors.red, fontSize: 18),
      ),
    );
  };
  runApp(const LiveKitExampleApp());
}

class LiveKitExampleApp extends StatelessWidget {
  //
  const LiveKitExampleApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'R Systems Connect',
        theme: LiveKitTheme().buildThemeData(context),
        home:  LoginPage(),
      );
}
