import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class VoucherData {
  final String id;
  final String walletId;
  final double amount;
  final double remainingBalance;
  final double maxOfflineTransaction;
  final double maxCumulativeSpending;
  final int maxTransactionsCount;
  final int expiryTimestamp;
  final int lastSettledSeq;
  final String signature;

  VoucherData({
    required this.id,
    required this.walletId,
    required this.amount,
    required this.remainingBalance,
    this.maxOfflineTransaction = 200.0,
    this.maxCumulativeSpending = 1000.0,
    this.maxTransactionsCount = 10,
    required this.expiryTimestamp,
    this.lastSettledSeq = 0,
    required this.signature,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'walletId': walletId,
      'amount': amount,
      'remainingBalance': remainingBalance,
      'maxOfflineTransaction': maxOfflineTransaction,
      'maxCumulativeSpending': maxCumulativeSpending,
      'maxTransactionsCount': maxTransactionsCount,
      'expiryTimestamp': expiryTimestamp,
      'lastSettledSeq': lastSettledSeq,
      'signature': signature,
    };
  }

  factory VoucherData.fromMap(Map<String, dynamic> map) {
    return VoucherData(
      id: map['id'] ?? '',
      walletId: map['walletId'] ?? map['wallet_id'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      remainingBalance: (map['remainingBalance'] ?? map['remaining_balance'] as num?)?.toDouble() ?? 0.0,
      maxOfflineTransaction: (map['maxOfflineTransaction'] ?? map['max_offline_transaction'] as num?)?.toDouble() ?? 200.0,
      maxCumulativeSpending: (map['maxCumulativeSpending'] ?? map['max_cumulative_spending'] as num?)?.toDouble() ?? 1000.0,
      maxTransactionsCount: (map['maxTransactionsCount'] ?? map['max_transactions_count'] as num?)?.toInt() ?? 10,
      expiryTimestamp: map['expiryTimestamp'] ?? (map['expiry'] != null ? DateTime.parse(map['expiry']).millisecondsSinceEpoch : 0),
      lastSettledSeq: (map['lastSettledSeq'] ?? map['last_settled_seq'] as num?)?.toInt() ?? 0,
      signature: map['signature'] ?? '',
    );
  }
}

class LocalTransaction {
  final String voucherId;
  final String senderWalletId;
  final String receiverWalletId;
  final double amount;
  final int sequenceNumber;
  final String timestampIso;
  final String signature;
  final String status; // PENDING, SETTLED, CONFLICT, DUPLICATE, REJECTED
  final String? errorMessage;

  LocalTransaction({
    required this.voucherId,
    required this.senderWalletId,
    required this.receiverWalletId,
    required this.amount,
    required this.sequenceNumber,
    required this.timestampIso,
    required this.signature,
    this.status = "PENDING",
    this.errorMessage,
  });

  Map<String, dynamic> toMap() {
    return {
      'voucherId': voucherId,
      'senderWalletId': senderWalletId,
      'receiverWalletId': receiverWalletId,
      'amount': amount,
      'sequenceNumber': sequenceNumber,
      'timestampIso': timestampIso,
      'signature': signature,
      'status': status,
      'errorMessage': errorMessage,
    };
  }

  factory LocalTransaction.fromMap(Map<String, dynamic> map) {
    return LocalTransaction(
      voucherId: map['voucherId'] ?? map['voucher_id'] ?? '',
      senderWalletId: map['senderWalletId'] ?? map['sender_wallet_id'] ?? '',
      receiverWalletId: map['receiverWalletId'] ?? map['receiver_wallet_id'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      sequenceNumber: (map['sequenceNumber'] ?? map['sequence_number'] as num?)?.toInt() ?? 0,
      timestampIso: map['timestampIso'] ?? map['timestamp'] ?? DateTime.now().toIso8601String(),
      signature: map['signature'] ?? '',
      status: map['status'] ?? "PENDING",
      errorMessage: map['errorMessage'] ?? map['error_message'],
    );
  }
}

class SecureWalletStorage {
  static const String _keyWalletId = "wallet_id";
  static const String _keyOnlineBalance = "online_balance";
  static const String _keySeqNum = "sequence_number";
  static const String _keyVoucher = "active_voucher";
  static const String _keyVoucherBal = "voucher_remaining_balance";
  static const String _keyOutbox = "outbox_queue";
  static const String _keyInbox = "inbox_queue";
  static const String _keyAuditHistory = "audit_history";
  static const String _keyMerchantBalance = "merchant_balance";

  // --- Wallet ID ---
  static Future<void> saveWalletId(String walletId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyWalletId, walletId);
  }

  static Future<String?> getWalletId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyWalletId);
  }

  // --- Online Ledger Balance ---
  static Future<void> saveOnlineBalance(double balance) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyOnlineBalance, balance);
  }

  static Future<double> getOnlineBalance() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyOnlineBalance) ?? 10000.0;
  }

  // --- Merchant Balance ---
  static Future<void> saveMerchantBalance(double balance) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyMerchantBalance, balance);
  }

  static Future<double> getMerchantBalance() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyMerchantBalance) ?? 0.0;
  }

  // --- Sequence Number ---
  static Future<int> getNextSequenceNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_keySeqNum) ?? 0;
    final next = current + 1;
    await prefs.setInt(_keySeqNum, next);
    return next;
  }

  static Future<int> getCurrentSequenceNumber() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keySeqNum) ?? 0;
  }

  static Future<void> setSequenceNumber(int seq) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySeqNum, seq);
  }

  static Future<void> resetSequenceNumber() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySeqNum, 0);
  }

  // --- Voucher ---
  static Future<void> saveVoucher(VoucherData voucher) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(voucher.toMap());
    await prefs.setString(_keyVoucher, jsonStr);
    await prefs.setDouble(_keyVoucherBal, voucher.remainingBalance);
  }

  static Future<VoucherData?> getVoucher() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyVoucher);
    if (jsonStr == null) return null;
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    final remaining = prefs.getDouble(_keyVoucherBal) ?? 0.0;
    final voucher = VoucherData.fromMap(map);
    return VoucherData(
      id: voucher.id,
      walletId: voucher.walletId,
      amount: voucher.amount,
      remainingBalance: remaining,
      maxOfflineTransaction: voucher.maxOfflineTransaction,
      maxCumulativeSpending: voucher.maxCumulativeSpending,
      maxTransactionsCount: voucher.maxTransactionsCount,
      expiryTimestamp: voucher.expiryTimestamp,
      lastSettledSeq: voucher.lastSettledSeq,
      signature: voucher.signature,
    );
  }

  static Future<void> updateVoucherBalance(double newBalance) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyVoucherBal, newBalance);
  }

  static Future<void> clearVoucher() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyVoucher);
    await prefs.remove(_keyVoucherBal);
  }

  // --- Outbox Queue (Payer) ---
  static Future<List<LocalTransaction>> getOutbox() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyOutbox);
    if (jsonStr == null) return [];
    final list = jsonDecode(jsonStr) as List;
    return list.map((item) => LocalTransaction.fromMap(item)).toList();
  }

  static Future<void> queueOutboxTransaction(LocalTransaction tx) async {
    final outbox = await getOutbox();
    outbox.add(tx);
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(outbox.map((e) => e.toMap()).toList());
    await prefs.setString(_keyOutbox, jsonStr);
    await addAuditHistory(tx);
  }

  static Future<void> clearOutbox() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyOutbox);
  }

  // --- Inbox Queue (Merchant) ---
  static Future<List<LocalTransaction>> getInbox() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyInbox);
    if (jsonStr == null) return [];
    final list = jsonDecode(jsonStr) as List;
    return list.map((item) => LocalTransaction.fromMap(item)).toList();
  }

  static Future<void> queueInboxTransaction(LocalTransaction tx) async {
    final inbox = await getInbox();
    inbox.add(tx);
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(inbox.map((e) => e.toMap()).toList());
    await prefs.setString(_keyInbox, jsonStr);
    await addAuditHistory(tx);
  }

  static Future<void> clearInbox() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyInbox);
  }

  // --- Audit History Log ---
  static Future<List<LocalTransaction>> getAuditHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyAuditHistory);
    if (jsonStr == null) return [];
    final list = jsonDecode(jsonStr) as List;
    return list.map((item) => LocalTransaction.fromMap(item)).toList();
  }

  static Future<void> addAuditHistory(LocalTransaction tx) async {
    final history = await getAuditHistory();
    history.insert(0, tx); // Latest first
    if (history.length > 50) history.removeLast();
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(history.map((e) => e.toMap()).toList());
    await prefs.setString(_keyAuditHistory, jsonStr);
  }

  static Future<void> updateAuditStatus(int sequenceNumber, String status, {String? error}) async {
    final history = await getAuditHistory();
    final updated = history.map((tx) {
      if (tx.sequenceNumber == sequenceNumber) {
        return LocalTransaction(
          voucherId: tx.voucherId,
          senderWalletId: tx.senderWalletId,
          receiverWalletId: tx.receiverWalletId,
          amount: tx.amount,
          sequenceNumber: tx.sequenceNumber,
          timestampIso: tx.timestampIso,
          signature: tx.signature,
          status: status,
          errorMessage: error,
        );
      }
      return tx;
    }).toList();
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(updated.map((e) => e.toMap()).toList());
    await prefs.setString(_keyAuditHistory, jsonStr);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
