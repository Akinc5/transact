import 'dart:async';
import '../db/secure_storage.dart';

abstract class OfflineTransport {
  Future<bool> transmit(LocalTransaction tx);
  Stream<LocalTransaction> get onTransactionReceived;
}

/// DemoTransport simulates near-field communication (BLE GATT / NFC / Ultrasonic)
/// on a single device or across simulated profiles.
class DemoTransport implements OfflineTransport {
  static final DemoTransport _instance = DemoTransport._internal();
  factory DemoTransport() => _instance;
  DemoTransport._internal();

  final _streamController = StreamController<LocalTransaction>.broadcast();
  final List<LocalTransaction> _inTransit = [];

  List<LocalTransaction> get inTransit => List.unmodifiable(_inTransit);

  @override
  Stream<LocalTransaction> get onTransactionReceived => _streamController.stream;

  @override
  Future<bool> transmit(LocalTransaction tx) async {
    // Simulate BLE transmission delay
    await Future.delayed(const Duration(milliseconds: 400));
    _inTransit.add(tx);
    _streamController.add(tx);
    return true;
  }

  /// Manually deliver a specific transaction to the Merchant's local inbox
  Future<bool> acceptAndProcess(LocalTransaction tx) async {
    await SecureWalletStorage.queueInboxTransaction(tx);
    _inTransit.remove(tx);
    return true;
  }

  void clearInTransit() {
    _inTransit.clear();
  }
}
