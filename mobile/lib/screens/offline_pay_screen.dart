import 'package:flutter/material.dart';
import '../db/secure_storage.dart';
import '../security/keystore_manager.dart';
import '../services/offline_transport.dart';
import '../widgets/network_banner.dart';

class OfflinePayScreen extends StatefulWidget {
  const OfflinePayScreen({super.key});

  @override
  State<OfflinePayScreen> createState() => _OfflinePayScreenState();
}

class _OfflinePayScreenState extends State<OfflinePayScreen> {
  final TextEditingController _recipientController = TextEditingController(text: 'merchant@transact');
  final TextEditingController _amountController = TextEditingController(text: '100');
  
  String _walletId = 'akshansh@transact';
  VoucherData? _voucher;
  int _currentSeq = 0;
  bool _isSigning = false;

  final List<String> _demoRecipients = [
    'merchant@transact',
    'chai_point@transact',
    'metro_gate_07@transact',
    'supermarket@transact'
  ];

  @override
  void initState() {
    super.initState();
    _loadWalletState();
  }

  Future<void> _loadWalletState() async {
    final wallet = await SecureWalletStorage.getWalletId() ?? 'akshansh@transact';
    final voucher = await SecureWalletStorage.getVoucher();
    final seq = await SecureWalletStorage.getCurrentSequenceNumber();
    setState(() {
      _walletId = wallet;
      _voucher = voucher;
      _currentSeq = seq;
    });
  }

  Future<void> _executeOfflinePayment() async {
    final v = _voucher;
    if (v == null || v.remainingBalance <= 0) {
      _showSnack("No active voucher with balance available. Please top up online.");
      return;
    }

    final recipient = _recipientController.text.trim();
    if (recipient.isEmpty) {
      _showSnack("Please enter recipient UPI ID");
      return;
    }

    final amt = double.tryParse(_amountController.text.trim());
    if (amt == null || amt <= 0) {
      _showSnack("Please enter a valid amount");
      return;
    }

    if (amt > v.remainingBalance) {
      _showSnack("Amount exceeds remaining offline voucher balance (₹${v.remainingBalance.toStringAsFixed(2)})");
      return;
    }

    if (amt > v.maxOfflineTransaction) {
      _showSnack("Risk Limit Breach: Amount ₹$amt exceeds single offline tx cap of ₹${v.maxOfflineTransaction.toStringAsFixed(0)}");
      return;
    }

    setState(() => _isSigning = true);

    // 1. Monotonic Sequence Advance
    final nextSeq = await SecureWalletStorage.getNextSequenceNumber();
    final timestampIso = DateTime.now().toIso8601String();

    // 2. Canonical Payload: voucher_id:sender_id:receiver_id:amount:seq_no:timestamp_iso
    final formattedAmt = amt.toStringAsFixed(2);
    final payload = "${v.id}:$_walletId:$recipient:$formattedAmt:$nextSeq:$timestampIso";

    // 3. Hardware TEE Signing
    final signature = await KeystoreManager.signPayload(payload);

    final localTx = LocalTransaction(
      voucherId: v.id,
      senderWalletId: _walletId,
      receiverWalletId: recipient,
      amount: amt,
      sequenceNumber: nextSeq,
      timestampIso: timestampIso,
      signature: signature,
      status: "PENDING",
    );

    // 4. Update local remaining balance
    final newRemaining = v.remainingBalance - amt;
    await SecureWalletStorage.updateVoucherBalance(newRemaining);
    await SecureWalletStorage.queueOutboxTransaction(localTx);

    // 5. Transmit over Demo Transport / BLE
    await DemoTransport().transmit(localTx);

    setState(() {
      _isSigning = false;
      _currentSeq = nextSeq;
      _voucher = VoucherData(
        id: v.id,
        walletId: v.walletId,
        amount: v.amount,
        remainingBalance: newRemaining,
        maxOfflineTransaction: v.maxOfflineTransaction,
        maxCumulativeSpending: v.maxCumulativeSpending,
        maxTransactionsCount: v.maxTransactionsCount,
        expiryTimestamp: v.expiryTimestamp,
        lastSettledSeq: v.lastSettledSeq,
        signature: v.signature,
      );
    });

    if (mounted) {
      _showSuccessDialog(localTx);
    }
  }

  void _showSuccessDialog(LocalTransaction tx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161A29),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.offline_bolt_rounded, color: Color(0xFF00CEC9)),
            SizedBox(width: 8),
            Text("Offline Payment Signed!", style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Transmitted ₹${tx.amount.toStringAsFixed(2)} to ${tx.receiverWalletId} over Near-Field (BLE).",
                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF00CEC9).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Sequence Counter: #${tx.sequenceNumber} (Anti-Replay)", style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text("Keystore Signature:", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
                  Text(
                    tx.signature.length > 32 ? "${tx.signature.substring(0, 32)}..." : tx.signature,
                    style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: Color(0xFFFFA801)),
                  ),
                  const SizedBox(height: 4),
                  Text("Remaining Voucher Balance: ₹${_voucher?.remainingBalance.toStringAsFixed(2)}",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00CEC9)),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text("Done", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final v = _voucher;

    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161A29),
        title: const Text('Offline BLE Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: Column(
        children: [
          const NetworkStatusBanner(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Offline Wallet Status Pill
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161A29),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("OFFLINE BALANCE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.5))),
                            const SizedBox(height: 2),
                            Text(
                              v != null ? "₹${v.remainingBalance.toStringAsFixed(2)}" : "₹0.00",
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF00CEC9)),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text("SEQUENCE #", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.5))),
                            const SizedBox(height: 2),
                            Text(
                              "#$_currentSeq",
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFA29BFE), fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Recipient Input
                  const Text("RECIPIENT MERCHANT ID", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: Color(0xFFA29BFE))),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _recipientController,
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.storefront_rounded, color: Color(0xFFA29BFE)),
                      filled: true,
                      fillColor: const Color(0xFF161A29),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Quick Demo Recipient Chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _demoRecipients.map((rec) {
                      return ActionChip(
                        label: Text(rec, style: const TextStyle(fontSize: 10, color: Colors.white70)),
                        backgroundColor: const Color(0xFF161A29),
                        onPressed: () {
                          setState(() {
                            _recipientController.text = rec;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  // Amount Input
                  const Text("PAYMENT AMOUNT (INR)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: Color(0xFFA29BFE))),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    decoration: InputDecoration(
                      prefixText: "₹ ",
                      prefixStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF00CEC9)),
                      filled: true,
                      fillColor: const Color(0xFF161A29),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Max per offline tx: ₹200.00", style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5))),
                      Text("Zero internet required", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF00E676))),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Action Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00CEC9),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _isSigning ? null : _executeOfflinePayment,
                    child: _isSigning
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.offline_bolt_rounded, size: 20),
                              SizedBox(width: 8),
                              Text("Sign with Keystore & Beam BLE", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
