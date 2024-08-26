import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<void> checkPermissions() async {
    var status = await Permission.bluetooth.request();

    if (status.isPermanentlyDenied) {
      print('Bluetooth Permission disabled');
    }

    status = await Permission.bluetoothConnect.request();

    if (status.isPermanentlyDenied) {
      print('Bluetooth Connect Permission disabled');
    }

    status = await Permission.camera.request();

    if (status.isPermanentlyDenied) {
      print('Camera Permission disabled');
    }

    status = await Permission.microphone.request();

    if (status.isPermanentlyDenied) {
      print('Microphone Permission disabled');
    }
  }
}
