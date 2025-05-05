import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_meeting_room/pages/connect.dart';
import 'package:video_meeting_room/utils.dart';
import 'package:video_meeting_room/widgets/link_expried.dart';


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final String headLine = 'Welcome to R Systems video conferencing solution';

  final String _validUsername = 'admin';
  final String _validPassword = 'admin@password';
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
      final decodedEncryptedParams = Uri.decodeComponent(encryptedParams);
      final decryptedParams = UrlEncryptionHelper.decrypt(decodedEncryptedParams);
      final decodedParams = UrlEncryptionHelper.decodeParams(decryptedParams);

      final role = decodedParams['role'];
      final room = decodedParams['room'];
      print('Decoded Params: $decodedParams');
      print('Role: $role');
      print('Room: $room');
      print('Encrypted Params: $encryptedParams');
      print('Decoded Encrypted Params: $decodedEncryptedParams');
      print('Decrypted Params: $decryptedParams');

      if (role != null && room != null) {
        _navigateToConnect();
      } else {
        Navigator.pushReplacement(
  context,
  MaterialPageRoute(builder: (context) => const LinkExpiredScreen()),
);

      }
    } else {
      _checkLoginStatus();
    }
  }

  Future<void> _checkLoginStatus() async {
    bool? isLoggedIn = prefs.getBool('isLoggedIn');
    int? loginTimestamp = prefs.getInt('loginTimestamp');

    if (isLoggedIn != null && isLoggedIn && loginTimestamp != null) {
      final int currentTime = DateTime.now().millisecondsSinceEpoch;
      if (currentTime - loginTimestamp < 86400000) {
        _navigateToConnect();
      } else {
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
      backgroundColor: const Color.fromARGB(255, 217, 219, 221),
      body: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isWideScreen = constraints.maxWidth > 600;
            final double screenHeight = MediaQuery.of(context).size.height;
            final double screenWidth = MediaQuery.of(context).size.width;

            return Padding(
              padding: EdgeInsets.all(screenWidth * 0.05),
              child: isWideScreen
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: screenWidth * 0.20,
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
                             SizedBox(height: screenHeight * 0.16),
                              Align(
                                alignment: Alignment.center,
                                child: RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Hello, Welcome',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: screenHeight * 0.03,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                             SizedBox(height: screenHeight * 0.10),
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: Text(
                                  headLine,
                                  style: TextStyle(
                                    fontSize: screenHeight * 0.03,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                       // SizedBox(width: screenWidth * 0.05),
                        Container(
                          width: screenWidth * 0.3,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(10),
                              bottomRight: Radius.circular(10),
                            ),
                          ),
                          padding: EdgeInsets.all(screenHeight * 0.10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              GestureDetector(
                                onTap: () {},
                                child: Text(
                                  'Login',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: screenHeight * 0.025,
                                    fontWeight: FontWeight.bold,
                                    color: const Color.fromARGB(255, 39, 38, 104),
                                  ),
                                ),
                              ),
                              SizedBox(height: screenHeight * 0.03),
                              Padding(
                                padding: EdgeInsets.only(bottom: screenHeight * 0.02),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'User Name',
                                      style: TextStyle(
                                        fontSize: screenHeight * 0.018,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    SizedBox(height: screenHeight * 0.01),
                                    TextField(
                                      controller: _usernameController,
                                      style: TextStyle(color: Colors.black),
                                      decoration: InputDecoration(
                                        hintStyle: TextStyle(color: Colors.black),
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.black,
                                            width: 1.0,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: const Color.fromARGB(255, 39, 38, 104),
                                            width: 2.0,
                                          ),
                                        ),
                                        contentPadding: EdgeInsets.symmetric(horizontal: screenHeight * 0.01),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.only(bottom: screenHeight * 0.03),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Password',
                                      style: TextStyle(
                                        fontSize: screenHeight * 0.018,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    SizedBox(height: screenHeight * 0.01),
                                    TextField(
                                      controller: _passwordController,
                                      style: TextStyle(color: Colors.black),
                                      obscureText: true,
                                      decoration: InputDecoration(
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.black,
                                            width: 1.0,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: const Color.fromARGB(255, 39, 38, 104),
                                            width: 2.0,
                                          ),
                                        ),
                                        contentPadding: EdgeInsets.symmetric(horizontal: screenHeight * 0.01),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: ElevatedButton(
                                  onPressed: () {
                                    _login(context);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color.fromARGB(255, 39, 38, 104),
                                    padding: EdgeInsets.symmetric(
                                        vertical: screenHeight * 0.015,
                                        horizontal: screenHeight * 0.03),
                                    minimumSize: Size(80, screenHeight * 0.05),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Login',
                                        style: TextStyle(
                                          fontSize: screenHeight * 0.02,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(width: screenHeight * 0.01),
                                      Icon(
                                        Icons.arrow_forward,
                                        size: screenHeight * 0.02,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: screenWidth * 0.9,
                          height: screenHeight * 0.3,
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
                              Spacer(),
                              Align(
                                alignment: Alignment.center,
                                child: RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Hello, Welcome',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: screenHeight * 0.03,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Spacer(),
                              Align(
                                alignment: Alignment.center,
                                child: Text(
                                 headLine,
                                  style: TextStyle(
                                    fontSize: screenHeight * 0.03,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.05),
                        Container(
                          width: screenWidth * 0.9,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.all(screenHeight * 0.02),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              GestureDetector(
                                onTap: () {},
                                child: Text(
                                  'Login',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: screenHeight * 0.025,
                                    fontWeight: FontWeight.bold,
                                    color: const Color.fromARGB(255, 39, 38, 104),
                                  ),
                                ),
                              ),
                              SizedBox(height: screenHeight * 0.03),
                              Padding(
                                padding: EdgeInsets.only(bottom: screenHeight * 0.02),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'User Name',
                                      style: TextStyle(
                                        fontSize: screenHeight * 0.018,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    SizedBox(height: screenHeight * 0.01),
                                    TextField(
                                      controller: _usernameController,
                                      style: TextStyle(color: Colors.black),
                                      decoration: InputDecoration(
                                        hintStyle: TextStyle(color: Colors.black),
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.black,
                                            width: 1.0,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: const Color.fromARGB(255, 39, 38, 104),
                                            width: 2.0,
                                          ),
                                        ),
                                        contentPadding: EdgeInsets.symmetric(horizontal: screenHeight * 0.01),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.only(bottom: screenHeight * 0.03),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Password',
                                      style: TextStyle(
                                        fontSize: screenHeight * 0.018,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    SizedBox(height: screenHeight * 0.01),
                                    TextField(
                                      controller: _passwordController,
                                      style: TextStyle(color: Colors.black),
                                      obscureText: true,
                                      decoration: InputDecoration(
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.black,
                                            width: 1.0,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: const Color.fromARGB(255, 39, 38, 104),
                                            width: 2.0,
                                          ),
                                        ),
                                        contentPadding: EdgeInsets.symmetric(horizontal: screenHeight * 0.01),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: ElevatedButton(
                                  onPressed: () {
                                    _login(context);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color.fromARGB(255, 39, 38, 104),
                                    padding: EdgeInsets.symmetric(
                                        vertical: screenHeight * 0.015,
                                        horizontal: screenHeight * 0.03),
                                    minimumSize: Size(80, screenHeight * 0.05),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Login',
                                        style: TextStyle(
                                          fontSize: screenHeight * 0.02,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(width: screenHeight * 0.01),
                                      Icon(
                                        Icons.arrow_forward,
                                        size: screenHeight * 0.02,
                                        color: Colors.white,
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
            );
          },
        ),
      ),
    );
  }
}
