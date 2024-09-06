import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_meeting_room/pages/connect.dart';
import 'package:video_meeting_room/utils.dart';
import 'package:video_meeting_room/widgets/text_field.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Local variables for username and password validation
  final String _validUsername = 'admin';
  final String _validPassword = 'admin';
  late SharedPreferences prefs;

  @override
  void initState() {
    super.initState();
    _initializePreferences();
  }

  Future<void> _initializePreferences() async {
    prefs = await SharedPreferences.getInstance();
     var uri = Uri.base;
     final encryptedParams = uri.queryParameters['data'];
    if (encryptedParams != null) {
      print('Encrypted Params: $encryptedParams');
   
        final decodedEncryptedParams = Uri.decodeComponent(encryptedParams);
        print('Decoded Encrypted Params: $decodedEncryptedParams');
      final decryptedParams = UrlEncryptionHelper.decrypt(decodedEncryptedParams);
      final decodedParams = UrlEncryptionHelper.decodeParams(decryptedParams);
   print('Decrypted Params: $decryptedParams');
     
      final role = decodedParams['role'];
      final room = decodedParams['room'];
      if (role != null && room != null) {
         _navigateToConnect();
      }
      else
      {
        _checkLoginStatus();
      }
    }
    else {
      _checkLoginStatus();
    }
  }

  Future<void> _checkLoginStatus() async {
    bool? isLoggedIn = prefs.getBool('isLoggedIn');
    int? loginTimestamp = prefs.getInt('loginTimestamp');

    if (isLoggedIn != null && isLoggedIn && loginTimestamp != null) {
      final int currentTime = DateTime.now().millisecondsSinceEpoch;
      if (currentTime - loginTimestamp < 86400000) {
        // 24 hours in milliseconds
        _navigateToConnect();
      } else {
        // Expire the login after 24 hours
        await prefs.remove('isLoggedIn');
        await prefs.remove('loginTimestamp');
      }
    }
  }

  Future<void> _login(BuildContext context) async {
    final String enteredUsername = _usernameController.text;
    final String enteredPassword = _passwordController.text;

    if (enteredUsername == _validUsername &&
        enteredPassword == _validPassword) {
      // Save login status
      await prefs.setBool('isLoggedIn', true);
      await prefs.setInt(
          'loginTimestamp', DateTime.now().millisecondsSinceEpoch);
      _usernameController.clear();
      _passwordController.clear();

      _navigateToConnect();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid username or password'),
        ),
      );
    }
  }

  _navigateToConnect() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => const ConnectPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login To R Systems Connect',
            style: TextStyle(color: Colors.white)),
            automaticallyImplyLeading: false,
      ),
      body: Container(
        alignment: Alignment.center,
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 25),
                  child: LKTextField(
                    ctrl: _usernameController,
                    label: 'Username',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 25),
                  child: LKTextField(
                    ctrl: _passwordController,
                    label: 'Password',
                    isPasswordField: true,
                  
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Check if username and password fields are filled
                    if (_usernameController.text.isEmpty ||
                        _passwordController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Please enter both username and password'),
                        ),
                      );
                    } else {
                      _login(context);
                    }
                  },
                  child: const Text('Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
