import 'package:flutter/material.dart';

class LinkExpiredScreen extends StatelessWidget {
  const LinkExpiredScreen({super.key});



  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // RSI Logo at the top
                Image.asset(
                  'images/Rsi_logo.png',
                  semanticLabel: 'RSI Logo',
                  height: screenHeight * 0.06,
                  fit: BoxFit.contain,
                ),

                const SizedBox(height: 32),

                // Icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.link_off_rounded,
                    size: 64,
                    color: Colors.redAccent,
                  ),
                ),

                const SizedBox(height: 30),

                // Title
                const Text(
                  "Meeting Link Expired",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                // Message
                const Text(
                  "The meeting link you tried to access is no longer valid. "
                  "It may have expired or been disabled by the host.",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

             
              ],
            ),
          ),
        ),
      ),
    );
  }
}
