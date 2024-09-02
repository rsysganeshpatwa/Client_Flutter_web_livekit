import 'dart:async';
import 'package:encrypt/encrypt.dart' as  erc;


FutureOr<void> Function()? onWindowShouldClose;



class UrlEncryptionHelper {
  static final _key = erc.Key.fromUtf8('my32lengthsupersecretnooneknows1'); // Replace with your key
  static const _ivLength = 16;
  // Encrypts a string and encodes it as a base64 string with IV prepended
static String encrypt(String text) {
    try {
      final iv = erc.IV.fromLength(_ivLength);
      final encrypter = erc.Encrypter(erc.AES(_key, mode: erc.AESMode.cbc));

      // Get the current time and format it
      final timestamp = DateTime.now().toIso8601String();
      final dataWithTimestamp = '$timestamp|$text';

      final encrypted = encrypter.encrypt(dataWithTimestamp, iv: iv);
      return '${iv.base64}:${encrypted.base64}';
    } catch (e) {
      print("Encryption error: $e");
      return '';
    }
  }

  static String decrypt(String encryptedText) {
    try {
      final parts = encryptedText.split(':');
      if (parts.length != 2) throw FormatException('Invalid encrypted data format');

      final iv = erc.IV.fromBase64(parts[0]);
      final encrypted = erc.Encrypted.fromBase64(parts[1]);
      final encrypter = erc.Encrypter(erc.AES(_key, mode: erc.AESMode.cbc));

      final decrypted = encrypter.decrypt(encrypted, iv: iv);

      // Extract the timestamp and data
      final splitData = decrypted.split('|');
      if (splitData.length != 2) throw FormatException('Invalid data format');

      final timestamp = splitData[0];
      final data = splitData[1];

      // Check if the data is expired
      if (_isExpired(timestamp)) {
        throw FormatException('Data has expired');
      }

      return data;
    } catch (e) {
      print("Decryption error: $e");
      return '';
    }
  }

  static bool _isExpired(String timestamp) {
    final dateTime = DateTime.parse(timestamp);
    final now = DateTime.now();
    final expirationDuration = Duration(hours: 24); // Example: 24 hours expiration
    return now.difference(dateTime) > expirationDuration;
  }
  // Encode a map of parameters to a query string
  static String encodeParams(Map<String, String> params) {
    return params.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');
  }

  // Decode a query string to a map of parameters
  static Map<String, String> decodeParams(String query) {
    return Uri.splitQueryString(query);
  }
}
