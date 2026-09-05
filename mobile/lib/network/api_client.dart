import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../db/secure_storage.dart';
import '../services/network_simulator.dart';

class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? errorMessage;

  ApiResponse({required this.success, this.data, this.errorMessage});
}

class ApiClient {
  // Configurable base URL: 10.0.2.2 for Android Emulator, localhost for Desktop/Web
  static String get baseUrl {
    if (!kIsWeb) {
      try {
        if (Platform.isAndroid) {
          return "http://10.0.2.2:8000";
        }
      } catch (_) {}
    }
    return "http://127.0.0.1:8000";
  }

  static bool get isOnline => NetworkSimulator().isOnline;

  /// Checks if the backend server is reachable and responsive
  static Future<bool> isBackendReachable() async {
    if (!isOnline) return false;
    try {
      final response = await http
          .get(Uri.parse("$baseUrl/api/public-key"))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Registers the device's public key with the backend
  static Future<Map<String, dynamic>?> registerWallet(String walletId, String publicKeyHex) async {
    if (!isOnline) {
      return null;
    }
    try {
      await NetworkSimulator().simulateNetworkLatency();
      final response = await http.post(
        Uri.parse("$baseUrl/api/wallets/register"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "id": walletId,
          "public_key": publicKeyHex,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Fetches the wallet details from the server
  static Future<Map<String, dynamic>?> getWallet(String walletId) async {
    if (!isOnline) {
      return null;
    }
    try {
      await NetworkSimulator().simulateNetworkLatency();
      final response = await http.get(
        Uri.parse("$baseUrl/api/wallets/$walletId"),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Requests a signed voucher (Online Top-up)
  static Future<Map<String, dynamic>?> issueVoucher(String walletId, double amount) async {
    if (!isOnline) {
      return null;
    }
    try {
      await NetworkSimulator().simulateNetworkLatency();
      final response = await http.post(
        Uri.parse("$baseUrl/api/vouchers/issue"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "wallet_id": walletId,
          "amount": amount,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Sends a batch of offline transaction records to the backend for reconciliation
  static Future<Map<String, dynamic>?> syncTransactions(List<LocalTransaction> transactions) async {
    if (!isOnline) {
      return null;
    }
    try {
      await NetworkSimulator().simulateNetworkLatency();
      final payload = {
        "transactions": transactions.map((tx) => {
          "voucher_id": tx.voucherId,
          "sender_wallet_id": tx.senderWalletId,
          "receiver_wallet_id": tx.receiverWalletId,
          "amount": tx.amount,
          "sequence_number": tx.sequenceNumber,
          "timestamp": tx.timestampIso,
          "signature": tx.signature,
        }).toList(),
      };

      final response = await http.post(
        Uri.parse("$baseUrl/api/sync"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Fetch fraud dashboard analytics
  static Future<Map<String, dynamic>?> getFraudDashboard() async {
    if (!isOnline) return null;
    try {
      final response = await http.get(Uri.parse("$baseUrl/api/fraud-dashboard"));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Fetch reconciled ledger history
  static Future<List<dynamic>?> getLedgerHistory(String walletId) async {
    if (!isOnline) return null;
    try {
      final response = await http.get(Uri.parse("$baseUrl/api/transactions/wallet/$walletId"));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Reset server demo state
  static Future<bool> resetServerDemo() async {
    if (!isOnline) return false;
    try {
      final response = await http.post(Uri.parse("$baseUrl/api/reset-demo"));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
