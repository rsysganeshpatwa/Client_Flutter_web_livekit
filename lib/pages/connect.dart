import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:flutter_svg/flutter_svg.dart';

import 'package:livekit_client/livekit_client.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:permission_handler/permission_handler.dart';

import 'package:http/http.dart' as http;

import 'dart:convert';

import 'package:video_meeting_room/pages/prejoin.dart';
import 'package:video_meeting_room/pages/room.dart';

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
  Role _selectedRole = Role.participant; // Default role is Participant

  final tokenServiceUrl = dotenv.env['API_NODE_LOCAL_URL'] ?? '';
  final url = dotenv.env['API_LIVEKIT_LOCAL_URL'] ?? '';

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
      final _role = _selectedRole == Role.admin ? Role.admin : Role.participant;

      // Call the Node.js API to get the token

      final response = await http.post(
        Uri.parse('$tokenServiceUrl/token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'identity': identity,
          'roomName': roomName,
          'role': _role.toString()
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final token = data['token'];

        print('Connecting with identity: $identity, token: $token...');

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
                role: _role,
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

  void _showRoomListModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
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
                                _roomCtrl.text = roomList[index];
                                Navigator.pop(context); // Close the modal
                                _isRoomNameInUrl = false;
                              });
                            },
                          );
                        },
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text('POC Health Care Monitoring'),
        backgroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          buildMainContent(),
          if (!isMobile) buildSidebar(),
          if (isMobile) buildFloatingActionButton(),
        ],
      ),
    );
  }

  Widget buildMainContent() {
    return Container(
      alignment: Alignment.center,
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_isRoomNameInUrl) buildRoleSelection(),
              if (_isRoomNameInUrl) // Conditionally show the room name
                Padding(
                  padding: const EdgeInsets.only(bottom: 25),
                  child: Text(
                    'Room Name: ${_roomCtrl.text}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 25),
                child: LKTextField(
                  label: 'Name',
                  ctrl: _identityCtrl,
                ),
              ),
              buildConnectButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildRoleSelection() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.center, // Align items to start vertically
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 25),
          child: ListTile(
            title: const Text(
              'Host',
              style: TextStyle(color: Colors.white), // Set text color to white
            ),
            leading: Radio<Role>(
              value: Role.admin,
              groupValue: _selectedRole,
              onChanged: (Role? value) {
                setState(() {
                  _selectedRole = value!;
                });
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 25),
          child: ListTile(
            title: const Text(
              'Participant',
              style: TextStyle(color: Colors.white), // Set text color to white
            ),
            leading: Radio<Role>(
              value: Role.participant,
              groupValue: _selectedRole,
              onChanged: (Role? value) {
                setState(() {
                  _selectedRole = value!;
                });
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 25),
          child: LKTextField(
            label: 'Room Name',
            ctrl: _roomCtrl,
          ),
        ),
      ],
    );
  }

  Widget buildConnectButton() {
    return ElevatedButton(
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
    );
  }

  Widget buildSidebar() {
    if (!_isRoomNameInUrl)
      return Positioned(
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
                                _roomCtrl.text = roomList[index];
                                _isRoomNameInUrl = false;
                              });
                            },
                          );
                        },
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      );
    return Container();
  }

  Widget buildFloatingActionButton() {
    if (!_isRoomNameInUrl)
      return Positioned(
        right: 16,
        top: 16,
        child: FloatingActionButton(
          onPressed: () => _showRoomListModal(context),
          child: Icon(Icons.list),
        ),
      );
    return Container();
  }
}
