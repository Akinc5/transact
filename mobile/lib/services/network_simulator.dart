import 'package:flutter/foundation.dart';

/// NetworkSimulator provides a global toggle for simulating Online/Offline states.
/// When in Offline mode, network requests are intercepted locally to demonstrate
/// true zero-connectivity cryptographic operation.
class NetworkSimulator extends ChangeNotifier {
  static final NetworkSimulator _instance = NetworkSimulator._internal();
  factory NetworkSimulator() => _instance;
  NetworkSimulator._internal();

  bool _isOnline = true;
  int _latencyMs = 350;

  bool get isOnline => _isOnline;
  int get latencyMs => _latencyMs;

  void toggle() {
    _isOnline = !_isOnline;
    notifyListeners();
  }

  void setOnline(bool online) {
    if (_isOnline != online) {
      _isOnline = online;
      notifyListeners();
    }
  }

  void setLatency(int ms) {
    _latencyMs = ms;
    notifyListeners();
  }

  Future<void> simulateNetworkLatency() async {
    if (_latencyMs > 0) {
      await Future.delayed(Duration(milliseconds: _latencyMs));
    }
  }
}
