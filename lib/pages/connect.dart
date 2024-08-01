import 'package:flutter/material.dart';

import 'package:flutter_svg/flutter_svg.dart';

import 'package:livekit_client/livekit_client.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:permission_handler/permission_handler.dart';

import 'package:http/http.dart' as http;

import 'dart:convert';

import 'package:video_meeting_room/pages/prejoin.dart';

import 'package:video_meeting_room/widgets/text_field.dart';

import '../exts.dart';



class ConnectPage extends StatefulWidget {

    const ConnectPage({
    super.key,
  });
  @override
  State<StatefulWidget> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  static const _storeKeyIdentity = 'identity';

  final _identityCtrl = TextEditingController();

  bool _busy = false;

  @override
  void initState() {
    super.initState();

    _readPrefs();
    

    if (lkPlatformIs(PlatformType.android)) {
      _checkPremissions();
    }
  }

  @override
  void dispose() {
    _identityCtrl.dispose();

    super.dispose();
  }

  Future<void> _checkPremissions() async {
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

  // Read saved Identity

  Future<void> _readPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    _identityCtrl.text = prefs.getString(_storeKeyIdentity) ?? '';
  }

  // Save Identity

  Future<void> _writePrefs() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_storeKeyIdentity, _identityCtrl.text);
  }

  Future<void> _connect(BuildContext ctx) async {
    try {
      setState(() {
        _busy = true;
      });

      // Save Identity for convenience

      await _writePrefs();


// Load the .env file
      

      final identity = _identityCtrl.text;

      // Call the Node.js API to get the token

      final response = await http.post(
        Uri.parse('http://localhost:3000/token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'identity': identity, 'roomName': 'room1'}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final token = data['token'];

        print('Connecting with identity: $identity, token: $token...');

       var url = 'wss://poc-test-7otdfht1.livekit.cloud'; 

        await Navigator.push<void>(
          ctx,
          MaterialPageRoute(
            builder: (_) => PreJoinPage(
              args: JoinArgs(
                url: url ?? '',
                token: token,
                simulcast: true,
                adaptiveStream: true,
                dynacast: true,
                preferredCodec: 'Preferred Codec',
                enableBackupVideoCodec:
                    ['VP9', 'AV1'].contains('Preferred Codec'),
              ),
            ),
          ),
        );
      } else {
        throw Exception('Failed to generate token');
      }
    } catch (error) {
      print('Could not connect $error');

      await ctx.showErrorDialog(error);
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text('POC Health Care Monitoring'),
          backgroundColor: Colors.white,
        ),
        body: Container(
          alignment: Alignment.center,
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 20,
              ),
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 70),
                    child: SvgPicture.asset(
                      'images/logo-dark.svg',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 25),
                    child: LKTextField(
                      label: 'Name',
                      ctrl: _identityCtrl,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _busy ? null : () => _connect(context),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_busy)
                          const Padding(
                            padding: EdgeInsets.only(right: 10),
                            child: SizedBox(
                              height: 15,
                              width: 15,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        const Text('CONNECT'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
