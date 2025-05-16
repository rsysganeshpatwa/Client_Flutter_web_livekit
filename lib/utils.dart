// ignore_for_file: avoid_print

import 'dart:async';
import 'package:encrypt/encrypt.dart' as  erc;
import 'package:flutter/services.dart';
import 'package:video_meeting_room/models/room_models.dart';


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
      if (parts.length != 2) throw const FormatException('Invalid encrypted data format');

      final iv = erc.IV.fromBase64(parts[0]);
      final encrypted = erc.Encrypted.fromBase64(parts[1]);
      final encrypter = erc.Encrypter(erc.AES(_key, mode: erc.AESMode.cbc));

      final decrypted = encrypter.decrypt(encrypted, iv: iv);

      // Extract the timestamp and data
      final splitData = decrypted.split('|');
      if (splitData.length != 2) throw const FormatException('Invalid data format');

      final timestamp = splitData[0];
      final data = splitData[1];

      // Check if the data is expired
      if (_isExpired(timestamp)) {
        throw const FormatException('Data has expired');
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
    const expirationDuration =  Duration(hours: 24); // Example: 24 hours expiration
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




class ValidateTextField {
  static List<TextInputFormatter> globalInputFormatters({int? maxLength}) {
    return [
      if (maxLength != null) LengthLimitingTextInputFormatter(maxLength), // Set max length if provided
      // Deny leading/trailing spaces but allow spaces in between words
      TextInputFormatter.withFunction((oldValue, newValue) {
        String trimmedValue = newValue.text.trimLeft(); // Remove leading spaces
        return TextEditingValue(
          text: trimmedValue,
          selection: TextSelection.collapsed(offset: trimmedValue.length),
        );
      }),
    ];
  }
}


List<ParticipantStatus> updateSpotlightStatus({
  required List<ParticipantStatus> participantList,
  required ParticipantStatus updatedStatus,
  int maxPinned = 3,
}) {
  final updatedList = <ParticipantStatus>[];

  // Step 1: Spotlight logic — only one can be spotlighted
  if (updatedStatus.isSpotlight) {
    // for (final status in participantList) {
    //   if (status.identity == updatedStatus.identity) continue;
    //   updatedList.add(status.copyWith(isSpotlight: false));
    // }

    // Auto-enable audio/video/talk-to-host if spotlighted
    updatedStatus = updatedStatus.copyWith(
      isTalkToHostEnable: true,
      isAudioEnable: true,
      isVideoEnable: true,
    );
  } else {
    // Preserve other spotlight states if not changing spotlight
    for (final status in participantList) {
      if (status.identity != updatedStatus.identity) {
        updatedList.add(status);
      }
    }
  }


  // Step 3: Add or update the current participant status
  updatedList.removeWhere((s) => s.identity == updatedStatus.identity);
  updatedList.add(updatedStatus);

  return updatedList;
}



class ParticipantUtils {
 static String formatName(String name) {
      if (name.isEmpty) return name;
      return name
          .split(' ')
          .map((word) => word.isNotEmpty
              ? word[0].toUpperCase() + word.substring(1).toLowerCase()
              : '')
          .join(' ');
}
}