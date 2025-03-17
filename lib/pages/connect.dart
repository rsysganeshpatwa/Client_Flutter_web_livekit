import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:livekit_client/livekit_client.dart' as livekit;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_meeting_room/app_config.dart';
import 'package:video_meeting_room/exts.dart';
import 'package:video_meeting_room/pages/prejoin.dart';
import 'package:video_meeting_room/utils.dart';
import '../services/api_service.dart';
import '../services/permission_service.dart';
import '../widgets/text_field.dart';
import '../models/role.dart';
import 'streamer.dart';

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

  final _identityCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();
  final _welcomeMessageCtrl = TextEditingController(text: 'Weekly Roundtable Leadership Call');

  bool _busy = false;
  String? roomNameFromUrl;
  String? roomRoleFromUrl;
  String? welcomeMessage = "Weekly Roundtable Leadership Call";
  bool _isRoomNameInUrl = false;

  String? selectedRoom;

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
      print('Decoded Params: $decodedParams');
      room = decodedParams['room'] ?? '';
    }
    //String metadata = await _apiService.getWelcomeMessage(room);
    welcomeMessage = 'Weekly Roundtable Leadership Call';
    _initializeParams();
  }

  Future<void> _initializeParams() async {
    final uri = Uri.base;
    final encryptedParams = uri.queryParameters['data'];
      print('Encrypted Params: $encryptedParams');
    if (encryptedParams != null && encryptedParams.isNotEmpty) {
          final decodedEncryptedParams = Uri.decodeComponent(encryptedParams);
       
      final decryptedParams = UrlEncryptionHelper.decrypt(decodedEncryptedParams);
      final decodedParams = UrlEncryptionHelper.decodeParams(decryptedParams);

      setState(() {
        roomNameFromUrl = decodedParams['room'] ?? '';
        roomRoleFromUrl = decodedParams['role'] ?? '';
        print('Room Name from URL: $roomNameFromUrl');
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



      final identity = _identityCtrl.text;
      final roomName = _roomCtrl.text;
       if (identity.isEmpty) {
      await ctx.showErrorDialog('Please enter your name',title: 'Input Error');
       setState(() {
        _busy = false;
      });
      return; 
       }
      else if (roomName.isEmpty) {
      await ctx.showErrorDialog('Please enter a room name',title: 'Input Error');
       setState(() {
        _busy = false;
      });
      return; 
      }

      await _writePrefs();

 
      final adminWelcomeMessage = _welcomeMessageCtrl.text;
      final _role = _selectedRole == Role.admin ? Role.admin : Role.participant;

      final token = await _apiService.getToken(identity, roomName, _role.toString(), adminWelcomeMessage);
    
      await Navigator.pushAndRemoveUntil<void>(
        ctx,
        MaterialPageRoute(
          builder: (_) => PreJoinPage(
            args: JoinArgs(
              url: AppConfig.apiLiveKitHttpsUrl,//dotenv.env['API_LIVEKIT_HTTPS_URL'] ?? '',
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
        (route) => false,
       
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
            color: Colors.white,
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
                    color: Color.fromARGB(255, 39, 38, 104),
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
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 217, 219, 221),
                                borderRadius: BorderRadius.circular(10), // Rounded corners
                              ),
                              child: ListTile(
                                title: Text(
                                  roomList![index],
                                  style: const TextStyle(color: Colors.black),
                                ),
                                onTap: () {
                                  setState(() {
                                    selectedRoom = roomList![index];
                                    _roomCtrl.text = roomList[index];
                                    Navigator.pop(context); // Close the modal
                                    _isRoomNameInUrl = false;
                                  });
                                },
                              ),
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
      /*appBar: AppBar(
        title: const Text('POC Health Care Monitoring'),
        backgroundColor: Theme.of(context).indicatorColor,
      ),*/
      body: Stack(
        children: [
          buildMainContent(),
          //if (!isMobile) buildSidebar(),
          // if (isMobile) buildFloatingActionButton(),
          Positioned(
            top: 16,
            right: 16,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LiveKitIngressPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 39, 38, 104),
              ),
              child: const Text(
                'Create Stream',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

Widget buildMainContent() {
  final double screenHeight = MediaQuery.of(context).size.height;
  final double screenWidth = MediaQuery.of(context).size.width;
  
  // Define mobile threshold
  bool isMobile = screenWidth < 600;

  return Scaffold(
    backgroundColor: const Color.fromARGB(255, 217, 219, 221),
    body: Center(
      child: isMobile
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Existing vertical box (left panel for mobile)
                Container(
                  width: screenWidth * 0.9, // Make the container take up 90% of the width for mobile
                  height: screenHeight * 0.3, // Adjust height based on screen height
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 39, 38, 104), // Background color of the vertical box
                    borderRadius: BorderRadius.circular(10), // Rounded corners
                  ),
                  padding: EdgeInsets.all(screenHeight * 0.02), // Dynamic padding
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo
                      Image.asset(
                        'images/Rsi_logo.png',
                        semanticLabel: 'Rsilogo',
                        height: screenHeight * 0.06, // Adjust height relative to screen height for mobile
                      ),
                      SizedBox(height: screenHeight * 0.05), // Spacer between logo and text for mobile
                      // Heading
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Welcome to R Systems video conferencing solution',
                          style: TextStyle(
                            fontSize: screenHeight * 0.025, // Smaller font for mobile
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: screenHeight * 0.05), // Space between boxes for mobile
                // New vertical box for login form (right panel for mobile)
                Container(
                  width: screenWidth * 0.9, // Make the form take up 90% of the width for mobile
                  height: // Adjust height for 'admin'
                      screenHeight * 0.60, // Adjust height for other roles
                  decoration: BoxDecoration(
                    color: Colors.white, // White background for the form
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: EdgeInsets.all(screenHeight * 0.02), // Dynamic padding
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!_isRoomNameInUrl) ...[
                        // Row for selecting "Host" or "Participant"
                        buildRoleSelection(),
                      ],
                      if (_isRoomNameInUrl) ...[
                        // Welcome message
                        Text(
                          welcomeMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: screenHeight * 0.035, // Dynamic font size for mobile
                            fontWeight: FontWeight.bold,
                            color: const Color.fromARGB(255, 39, 38, 104), // Blue text color
                          ),
                        ),
                      ],
                      SizedBox(height: screenHeight * 0.03),
                      // Name Field
                      buildNameField(),
                      SizedBox(height: screenHeight * 0.03),
                      // Connect Button
                      buildConnectButton(),
                    ],
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Existing vertical box (left panel for larger screens)
                Container(
                  width: screenWidth * 0.2, // Adjust width for desktop
                  height: screenHeight * 0.7,
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 39, 38, 104),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: EdgeInsets.all(screenHeight * 0.02),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.asset(
                        'images/Rsi_logo.png',
                        semanticLabel: 'Rsilogo',
                        height: screenHeight * 0.07,
                      ),
                      SizedBox(height: screenHeight * 0.15),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Welcome to R Systems video conferencing solution',
                          style: TextStyle(
                            fontSize: screenHeight * 0.02,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // New vertical box for login form (right panel for larger screens)
                Container(
                  width: screenWidth * 0.20,
                  height:screenHeight * 0.65,
                     
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(10),
                      bottomRight: Radius.circular(10),
                    ),
                  ),
                  padding: EdgeInsets.all(screenHeight * 0.03),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!_isRoomNameInUrl) ...[
                        buildRoleSelection(),
                      ],
                      if (_isRoomNameInUrl) ...[
                        Text(
                          welcomeMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: screenHeight * 0.04,
                            fontWeight: FontWeight.bold,
                            color: const Color.fromARGB(255, 39, 38, 104),
                          ),
                        ),
                      ],
                      SizedBox(height: screenHeight * 0.03),
                      buildNameField(),
                      
                      buildConnectButton(),
                    ],
                  ),
                ),
              ],
            ),
    ),
  );
}

  // Widget buildSidebar() {
  //   if (!_isRoomNameInUrl) {
  //     final double screenWidth = MediaQuery.of(context).size.width;
  //     return Positioned(
  //       right: 0,
  //       top: 0,
  //       bottom: 0,
  //       child: Container(
  //         width: screenWidth * 0.15,
  //         color: Colors.white,
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             const Padding(
  //               padding: EdgeInsets.all(16.0),
  //               child: Text(
  //                 'Active Rooms',
  //                 style: TextStyle(
  //                   color: const Color.fromARGB(255, 39, 38, 104),
  //                   fontSize: 16,
  //                   fontWeight: FontWeight.bold,
  //                 ),
  //               ),
  //             ),
  //             //  Expanded(
  //             //   child: StreamBuilder<List<String>>(
  //             //     stream: _apiService.getRoomList(),
  //             //     builder: (context, snapshot) {
  //             //       if (snapshot.hasError) {
  //             //         return const Center(
  //             //           child: Text(
  //             //             'Error loading rooms',
  //             //             style: TextStyle(color: Colors.black),
  //             //           ),
  //             //         );
  //             //       } else if (snapshot.connectionState == ConnectionState.waiting) {
  //             //         return const Center(child: CircularProgressIndicator());
  //             //       } else {
  //             //         final roomList = snapshot.data;                      
  //             //         return ListView.builder(
  //             //           itemCount: roomList?.length,
  //             //           itemBuilder: (context, index) {
  //             //             return GestureDetector(
  //             //               onTap: () {
  //             //                 setState(() {
  //             //                   selectedRoom = roomList[index];
  //             //                   _roomCtrl.text = roomList[index];
  //             //                   _isRoomNameInUrl = false;
  //             //                 });
  //             //               },
  //             //               child: Container(
  //             //                 height: 30,
  //             //                 margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
  //             //                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
  //             //                 decoration: BoxDecoration(
  //             //                   //color: const Color.fromARGB(255, 217, 219, 221),
  //             //                   color: selectedRoom == roomList![index]
  //             //                   ? const Color.fromARGB(255, 39, 38, 104) // Change color to blue for the selected room
  //             //                   : const Color.fromARGB(255, 217, 219, 221), // Default color
  //             //                   borderRadius: BorderRadius.circular(10), // Curved corners
  //             //                 ),
  //             //                 child: Text(
  //             //                   roomList[index],
  //             //                   style: const TextStyle(
  //             //                     color: Colors.black,
  //             //                     fontWeight: FontWeight.bold,
  //             //                   ),
  //             //                 ),
  //             //               ),
  //             //             );
  //             //           },
  //             //         );
  //             //       }
  //             //     },
  //             //   ),
  //             // ),
  //           ],
  //         ),
  //       ),
  //     );
  //   }
  //   return Container();
  // }

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

  Widget buildConnectButton() {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double buttonHeight = _selectedRole == Role.admin 
      ? screenHeight * 0.02 // Height when the role is 'admin'
      : screenHeight * 0.03; // Default height for other roles
    // Login Button
    return Align(
      alignment: Alignment.center,
      child: ElevatedButton(
        onPressed: _busy ? null : () => _connect(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 39, 38, 104),
          padding: EdgeInsets.symmetric(
            vertical: buttonHeight, horizontal: screenHeight * 0.03), // Dynamic padding
          minimumSize: Size(80, screenHeight * 0.05), // Dynamic size
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30.0), // Set corner radius for more rounded corners
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min, // Make the button's width wrap its content
            children: [
              Text(
                'Connect',
                style: TextStyle(
                  fontSize: screenHeight * 0.02, // Dynamic font size
                  color: Colors.white, // Ensure text color is visible
                ),
              ),
              SizedBox(width: screenHeight * 0.01), // Spacing between text and arrow
              Icon(
                Icons.arrow_forward, // Add forward arrow icon
                size: screenHeight * 0.02, // Dynamic icon size
                color: Colors.white, // Set arrow color
              ),
            ],
          ),
        ),
      );
  }

  Widget buildNameField() {
    final double screenHeight = MediaQuery.of(context).size.height;
    return Padding(
                      padding: EdgeInsets.only(bottom: screenHeight * 0.03), // Dynamic padding
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Name',
                            style: TextStyle(
                              fontSize: screenHeight * 0.018, // Dynamic font size
                              fontWeight: FontWeight.bold,
                              color: Colors.black, // Set color to black
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.01), // Dynamic spacing
                          TextField(
                            controller: _identityCtrl,
                            style: TextStyle(color: Colors.black),
                            decoration: InputDecoration(
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.black, // Border color
                                  width: 1.0, // Border width
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: const Color.fromARGB(255, 39, 38, 104), // Focused border color
                                  width: 2.0,
                                ),
                              ),
                              contentPadding: EdgeInsets.symmetric(horizontal: screenHeight * 0.01),
                            ),
                          ),
                        ],
                      ),
                    );

                  }

  /*Widget buildRoomNameField() {
    final double screenHeight = MediaQuery.of(context).size.height;
      return Padding(
                  padding: const EdgeInsets.only(bottom: 25),
                  child: Text(
                    'Room Name: ${_roomCtrl.text}',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
  }*/

  Widget buildRoleSelection() {
    final double screenHeight = MediaQuery.of(context).size.height;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Host Option
            Row(
              children: [
                Radio<Role>(
                  value: Role.admin,
                  groupValue: _selectedRole,
                  onChanged: (Role? value) {
                    setState(() {
                      _selectedRole = value!;
                    });
                  },
                  activeColor: const Color.fromARGB(255, 39, 38, 104),
                ),
                Text(
                  'Host',
                  style: TextStyle(
                    fontSize: screenHeight * 0.02,
                    fontWeight: FontWeight.bold,
                    color: const Color.fromARGB(255, 39, 38, 104),
                  ),
                ),
              ],
            ),
            SizedBox(width: screenHeight * 0.03), // Spacer between options
            // Participant Option
            Row(
              children: [
                Radio<Role>(
                  value: Role.participant,
                  groupValue: _selectedRole,
                  onChanged: (Role? value) {
                    setState(() {
                      _selectedRole = value!;
                    });
                  },
                  activeColor: const Color.fromARGB(255, 39, 38, 104),
                ),
                Text(
                  'Participants',
                  style: TextStyle(
                    fontSize: screenHeight * 0.02,
                    fontWeight: FontWeight.bold,
                    color: const Color.fromARGB(255, 39, 38, 104),
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: screenHeight * 0.02), // Add spacing between role selection and room name field
        
        // Room Name Field
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Room Name',
              style: TextStyle(
                fontSize: screenHeight * 0.018, // Dynamic font size
                fontWeight: FontWeight.bold,
                color: Colors.black, // Set color to black
              ),
            ),
            SizedBox(height: screenHeight * 0.01), // Dynamic spacing
            TextField(
              controller: _roomCtrl,
              style: TextStyle(color: Colors.black),
              decoration: InputDecoration(
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.black, // Border color
                    width: 1.0, // Border width
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: const Color.fromARGB(255, 39, 38, 104), // Focused border color
                    width: 2.0,
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(
                  vertical: screenHeight * 0.01,
                  horizontal: screenHeight * 0.01),
              ),
            ),
          ],
        ),
        if (_selectedRole == Role.admin) ...[
        SizedBox(height: screenHeight * 0.02), // Spacing before Welcome Message field
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome Message',
              style: TextStyle(
                fontSize: screenHeight * 0.018, // Dynamic font size
                fontWeight: FontWeight.bold,
                color: Colors.black, // Set color to black
              ),
            ),
            SizedBox(height: screenHeight * 0.01), // Dynamic spacing
            TextField(
              controller: _welcomeMessageCtrl,
              style: TextStyle(color: Colors.black),
              decoration: InputDecoration(
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.black, // Border color
                    width: 1.0, // Border width
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: const Color.fromARGB(255, 39, 38, 104), // Focused border color
                    width: 2.0,
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: screenHeight * 0.01),
              ),
            ),
          ],
        ),
      ],
      ],
    );
  }

}