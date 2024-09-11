import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ThankYouWidget extends StatelessWidget {
  const ThankYouWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 217, 219, 221),
      body: Center(
        child: Container(
          width: 450,
          height: 250,
          padding: const EdgeInsets.all(20), // Padding inside the box
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10), // Border radius for rectangle shape
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                spreadRadius: 3,
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // Custom green background icon with a white checkmark
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.green, // Green background
                  shape: BoxShape.circle, // Circle shape for the icon
                ),
                child: const Icon(
                  Icons.check, // White checkmark
                  size: 30.0,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Thank you for participating!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 39, 38, 104),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // Handle button press, e.g., navigate back to the home screen
                  SystemNavigator.pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, // Button color to red
                  foregroundColor: Colors.white, // Text color to white
                  minimumSize: const Size(150, 5), // Set the button size (width, height)
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20), // Rounded border for the button
                    //side: const BorderSide(color: Colors.black, width: 2), // Black border with width
                  ),
                ),
                child: const Text('Close Window'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
