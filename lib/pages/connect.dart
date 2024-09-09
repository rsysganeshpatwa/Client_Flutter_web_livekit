import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_it/get_it.dart';
import 'package:livekit_client/livekit_client.dart' as livekit;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_meeting_room/exts.dart';
import 'package:video_meeting_room/pages/prejoin.dart';
import 'package:video_meeting_room/utils.dart';
import '../services/api_service.dart';
import '../services/permission_service.dart';
import '../widgets/text_field.dart';
import '../models/role.dart';

class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key});

  @override
  State<StatefulWidget> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  static const _storeKeyIdentity = 'identity';
  Role _selectedRole = Role.admin;

  final ApiService _apiService = GetIt.I<ApiService>();
  final PermissionService _permissionService = GetIt.I<PermissionService>();

  final _identityCtrl = TextEditingController( text: 'ganesh');
  final _roomCtrl = TextEditingController( text: 'ganesh');
  final _welcomeMessageCtrl = TextEditingController(text: 'Welcome to the room!');
  
  bool _busy = false;
  String? roomNameFromUrl;
  String? roomRoleFromUrl;
  String? welcomeMessage = "";
  bool _isRoomNameInUrl = false;

  @override
  void initState() {
    super.initState();
    _readPrefs();
    if (livekit.lkPlatformIs(livekit.PlatformType.android)) {
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
    await _permissionService.checkPermissions();
  }

  Future<void> _readPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _identityCtrl.text = prefs.getString(_storeKeyIdentity) ?? '';
    String? room = "";
    final uri = Uri.base;
    final encryptedParams = uri.queryParameters['data'];

    if (encryptedParams != null && encryptedParams.isNotEmpty) {
          final decodedEncryptedParams = Uri.decodeComponent(encryptedParams);
       
      final decryptedParams = UrlEncryptionHelper.decrypt(decodedEncryptedParams);
      final decodedParams = UrlEncryptionHelper.decodeParams(decryptedParams);
      room = decodedParams['room'] ?? '';
    }
    String metadata = await _apiService.getWelcomeMessage(room);
    welcomeMessage = metadata;
    _initializeParams();
  }

  Future<void> _initializeParams() async {
    final uri = Uri.base;
    final encryptedParams = uri.queryParameters['data'];

    if (encryptedParams != null && encryptedParams.isNotEmpty) {
          final decodedEncryptedParams = Uri.decodeComponent(encryptedParams);
       
      final decryptedParams = UrlEncryptionHelper.decrypt(decodedEncryptedParams);
      final decodedParams = UrlEncryptionHelper.decodeParams(decryptedParams);

      setState(() {
        roomNameFromUrl = decodedParams['room'] ?? '';
        roomRoleFromUrl = decodedParams['role'] ?? '';
        if (roomNameFromUrl != null) {
          _roomCtrl.text = roomNameFromUrl!;
          _isRoomNameInUrl = true;
        }
        if (roomRoleFromUrl != null) {
          _selectedRole = roomRoleFromUrl == Role.admin.name
              ? Role.admin
              : Role.participant;
        }
      });


    } else {
      // Handle the case where no encrypted parameters are present
      // For example, show an error or redirect to another page
      print('No encrypted parameters found in the URL.');
    }
  }

  Future<void> _writePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storeKeyIdentity, _identityCtrl.text);
  }

  Future<void> _connect(BuildContext ctx) async {
    try {
      setState(() {
        _busy = true;
      });

      await _writePrefs();

      final identity = _identityCtrl.text;
      final roomName = _roomCtrl.text;
      final adminWelcomeMessage = _welcomeMessageCtrl.text;
      final _role = _selectedRole == Role.admin ? Role.admin : Role.participant;

      final token = await _apiService.getToken(identity, roomName, _role.toString(), adminWelcomeMessage);
    
      await Navigator.push<void>(
        ctx,
        MaterialPageRoute(
          builder: (_) => PreJoinPage(
            args: JoinArgs(
              url: dotenv.env['API_LIVEKIT_HTTPS_URL'] ?? '',
              token: token,
              simulcast: true,
              adaptiveStream: true,
              dynacast: true,
              preferredCodec: 'Preferred Codec',
              enableBackupVideoCodec:
                  ['VP9', 'AV1'].contains('Preferred Codec'),
              role: _role,
              roomName: roomName,
              identity: identity,
            ),
          ),
        ),
      );
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
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
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
                  stream: _apiService.getRoomList(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                          child: Text('Error loading rooms',
                              style: TextStyle(color: Colors.white)));
                    } else if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else {
                      final roomList = snapshot.data;
                      return ListView.builder(
                        itemCount: roomList?.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            title: Text(
                              roomList![index],
                              style: const TextStyle(color: Colors.white),
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
        title: const Text('POC Health Care Monitoring'),
        backgroundColor: Theme.of(context).indicatorColor,
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
               // Welcome message
    Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Text(
           welcomeMessage!,
           style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
           textAlign: TextAlign.center,
           ),
          ),
              if (!_isRoomNameInUrl) buildRoleSelection(),
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 25),
          child: ListTile(
            title: const Text(
              'Host',
              style: TextStyle(color: Colors.white),
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
              style: TextStyle(color: Colors.white),
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
        if (_selectedRole == Role.admin)
         Padding(
          padding: const EdgeInsets.only(bottom: 25),
          child: LKTextField(
            label: 'Welcome Message',
            ctrl: _welcomeMessageCtrl,
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
    if (!_isRoomNameInUrl) {
      return Positioned(
        right: 0,
        top: 0,
        bottom: 0,
        child: Container(
          width: 200,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              bottomLeft: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
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
                  stream: _apiService.getRoomList(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                          child: Text('Error loading rooms',
                              style: TextStyle(color: Colors.white)));
                    } else if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else {
                      final roomList = snapshot.data;
                      return ListView.builder(
                        itemCount: roomList?.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            title: Text(
                              roomList![index],
                              style: const TextStyle(color: Colors.white),
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
    }
    return Container();
  }

  Widget buildFloatingActionButton() {
    if (!_isRoomNameInUrl) {
      return Positioned(
        right: 16,
        top: 16,
        child: FloatingActionButton(
          onPressed: () => _showRoomListModal(context),
          child: const Icon(Icons.list),
        ),
      );
    }
    return Container();
  }
}
