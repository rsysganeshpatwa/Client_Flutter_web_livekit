import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ThankYouWidget extends StatelessWidget {
  const ThankYouWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Thank You'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.check_circle_outline,
              size: 100.0,
              color: Colors.green,
            ),
            SizedBox(height: 20),
            Text(
              'Thank you for participating!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Handle button press, e.g., navigate back to the home screen
                //close window
                 SystemNavigator.pop();
              },
              child: Text('Close Window'),
            ),
          ],
        ),
      ),
    );
  }
}
