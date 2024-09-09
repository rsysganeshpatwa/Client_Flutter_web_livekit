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
    // Get the height of the screen
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 217, 219, 221), // Set background color
      body: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Existing vertical box
            Container(
              width: screenWidth * 0.15, // Make width a percentage of screen width
              height: screenHeight * 0.7, // Set height as a percentage of screen height
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 39, 38, 104), // Background color of the vertical box
                borderRadius: BorderRadius.circular(10), // Set the radius for rounded corners
              ),
              padding: EdgeInsets.all(screenHeight * 0.02), // Dynamic padding based on screen height
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo
                  Image.asset(
                    'images/Rsi_logo.png',
                    semanticLabel: 'Rsilogo',
                    height: screenHeight * 0.07, // Adjust height relative to screen height
                  ),
                  SizedBox(height: screenHeight * 0.15), // Spacer between logo and text
                  // Welcome Text
                  Align(
                    alignment: Alignment.center, // Center text horizontally
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Hello, Welcome',
                            style: TextStyle(
                              color: Colors.white, // Set text color to white
                              fontSize: screenHeight * 0.03, // Dynamic font size
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.06), // Spacer between welcome text and heading
                  // Heading
                  Align(
                    alignment: Alignment.center, // Center text horizontally
                    child: Text(
                      'POC Health Care\nMonitoring',
                      style: TextStyle(
                        fontSize: screenHeight * 0.03, // Dynamic font size
                        fontWeight: FontWeight.bold,
                        color: Colors.white, // Set heading color to white
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // New vertical box for login form
            Container(
              width: screenWidth * 0.3, // Adjust width relative to screen width
              decoration: BoxDecoration(
                color: Colors.white, // Background color of the vertical box
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(10), // Adjust the radius as needed
                  bottomRight: Radius.circular(10), // Adjust the radius as needed
                ),
              ),
              padding: EdgeInsets.all(screenHeight * 0.02), // Dynamic padding
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch, // Align children to stretch
                children: [
                  // Login Heading
                  GestureDetector(
                    onTap: () {
                      // Handle link click
                    },
                    child: Text(
                      'Login',
                      textAlign: TextAlign.center, // Center align text
                      style: TextStyle(
                        fontSize: screenHeight * 0.025, // Dynamic font size
                        fontWeight: FontWeight.bold,
                        color: const Color.fromARGB(255, 39, 38, 104), // Set color to blue
                      ),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.03), // Dynamic spacing

                  // Username Field
                  Padding(
                    padding: EdgeInsets.only(bottom: screenHeight * 0.02), // Dynamic padding
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'User Name',
                          style: TextStyle(
                            fontSize: screenHeight * 0.018, // Dynamic font size
                            fontWeight: FontWeight.bold,
                            color: Colors.black, // Set color to black
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.01), // Dynamic spacing
                        TextField(
                          controller: _usernameController,
                          style: TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            hintText: 'Admin',
                            hintStyle: TextStyle(
                              color: Colors.black, // Set hint text color to black
                            ),
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
                  ),
                  
                  // Password Field
                  Padding(
                    padding: EdgeInsets.only(bottom: screenHeight * 0.03), // Dynamic padding
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Password',
                          style: TextStyle(
                            fontSize: screenHeight * 0.018, // Dynamic font size
                            fontWeight: FontWeight.bold,
                            color: Colors.black, // Set color to black
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.01), // Dynamic spacing
                        TextField(
                          controller: _passwordController,
                          style: TextStyle(color: Colors.black),
                          obscureText: true, // Hide password text
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
                  ),
                  
                  // Login Button
                  Align(
                    alignment: Alignment.bottomRight,
                    child: ElevatedButton(
                      onPressed: () {
                        // Handle login logic
                        _login(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 39, 38, 104),
                        padding: EdgeInsets.symmetric(
                            vertical: screenHeight * 0.015, horizontal: screenHeight * 0.03), // Dynamic padding
                        minimumSize: Size(80, screenHeight * 0.05), // Dynamic size
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min, // Make the button's width wrap its content
                        children: [
                          Text(
                            'Login',
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
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}