import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ThankYouWidget extends StatelessWidget {
  const ThankYouWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thank You'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(
              Icons.check_circle_outline,
              size: 100.0,
              color: Colors.green,
            ),
            const SizedBox(height: 20),
            const Text(
              'Thank you for participating!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Handle button press, e.g., navigate back to the home screen
                //close window
                 SystemNavigator.pop();
              },
              child: const Text('Close Window'),
            ),
          ],
        ),
      ),
    );
  }
}
