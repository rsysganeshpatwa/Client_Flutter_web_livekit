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
import 'package:flutter/src/widgets/async.dart' as asyncstate;

class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key});

  @override
  State<StatefulWidget> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  static const _storeKeyIdentity = 'identity';

  final tokenServiceUrl = 'https://ec2-13-60-74-153.eu-north-1.compute.amazonaws.com/api';//'http://localhost:3000' ; //'https://livekit-token-server.glitch.me';

  //'https://token-livekit-service.onrender.com';

  final _identityCtrl = TextEditingController();

  final _roomCtrl = TextEditingController();

  bool _busy = false;

  String? roomNameFromUrl;

  bool _isRoomNameInUrl = false;
  late final activeRoomNames;
  @override
  void initState() {
    super.initState();

    _readPrefs();

    if (lkPlatformIs(PlatformType.android)) {
      _checkPermissions();
    }
  }

  @override
  void dispose() {
    _identityCtrl.dispose();

    _roomCtrl.dispose();

    super.dispose();
  }

  Future<void> _checkPermissions() async {
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

  Future<void> _readPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    _identityCtrl.text = prefs.getString(_storeKeyIdentity) ?? '';

    setState(() {
      roomNameFromUrl = Uri.base.queryParameters[
          'room']; // Replace with logic to get room name from URL if applicable

      if (roomNameFromUrl != null) {
        _roomCtrl.text = roomNameFromUrl!;
        _isRoomNameInUrl = true;
      }
    });
  }

  Future<void> _writePrefs() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_storeKeyIdentity, _identityCtrl.text);
  }

  Stream<List<String>> getRoomList() async* {
    while (true) {
      final response = await http.get(Uri.parse('$tokenServiceUrl/rooms'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        final roomList = data.map((room) => room['name'].toString()).toList();
        print('Room List: $roomList');
        yield roomList;
      }

      // Wait for a while before the next request
      await Future.delayed(Duration(seconds: 30));
    }
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

      final roomName = _roomCtrl.text;

      // Call the Node.js API to get the token

      final response = await http.post(
        //https://token-livekit-service.onrender.com/token
        Uri.parse('$tokenServiceUrl/token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'identity': identity, 'roomName': roomName}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final token = data['token'];

        print('Connecting with identity: $identity, token: $token...');

        var url = 'https://ec2-13-60-74-153.eu-north-1.compute.amazonaws.com/livekit';//'http://localhost:7880';//'wss://poc-test-7otdfht1.livekit.cloud';

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
        body: Stack(
          children: [
            Container(
              alignment: Alignment.center,
              child: SingleChildScrollView(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 25),
                        child: SvgPicture.asset('images/logo-dark.svg'),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 25),
                        child: LKTextField(
                          label: 'Name',
                          ctrl: _identityCtrl,
                        ),
                      ),
                      if (!_isRoomNameInUrl)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 25),
                          child: LKTextField(
                            label: 'Room Name',
                            ctrl: _roomCtrl,
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
            if (!_isRoomNameInUrl)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 200,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Active Rooms',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                          child: StreamBuilder<List<String>>(
                        stream: getRoomList(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Text('');
                          } else if (snapshot.connectionState ==
                              asyncstate.ConnectionState.waiting) {
                            return CircularProgressIndicator();
                          } else {
                            final roomList = snapshot.data;
                            return ListView.builder(
                              itemCount: roomList?.length,
                              itemBuilder: (context, index) {
                                return ListTile(
                                  title: Text(
                                    roomList![index],
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  onTap: () {
                                    setState(() {
                                      _roomCtrl.text = roomList![index];

                                      _isRoomNameInUrl = false;
                                    });
                                  },
                                );
                              },
                            );
                          }
                        },
                      )),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
}
