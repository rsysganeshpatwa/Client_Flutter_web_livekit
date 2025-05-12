
// ignore_for_file: file_names

import 'package:flutter/foundation.dart';

class PinnedParticipantProvider extends ChangeNotifier {
  final int maxPins;
  final List<String> _pinnedIdentities = [];

  PinnedParticipantProvider({this.maxPins = 3});

  List<String> get pinnedIdentities => List.unmodifiable(_pinnedIdentities);

  bool isPinned(String identity) => _pinnedIdentities.contains(identity);

  void togglePin(String identity) {
    if (_pinnedIdentities.contains(identity)) {
      _pinnedIdentities.remove(identity); // unpin
    } else {
      if (_pinnedIdentities.length >= maxPins) {
        _pinnedIdentities.removeAt(0); // remove oldest
      }
      _pinnedIdentities.add(identity); // pin new
    }
    notifyListeners(); // <== THIS is now available
  }

  void clearAllPins() {
    _pinnedIdentities.clear();
    notifyListeners();
  }
}
