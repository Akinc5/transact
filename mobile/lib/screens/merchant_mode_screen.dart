import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/secure_storage.dart';
import '../services/offline_transport.dart';
import '../widgets/network_banner.dart';
import 'reconciliation_screen.dart';

class MerchantModeScreen extends StatefulWidget {
  const MerchantModeScreen({super.key});

  @override
  State<MerchantModeScreen> createState() => _MerchantModeScreenState();
}

class _MerchantModeScreenState extends State<MerchantModeScreen> {
  final String _merchantId = "merchant@transact";
  double _offlineSalesTotal = 0.0;
  List<LocalTransaction> _inbox = [];
  List<LocalTransaction> _inTransit = [];

  @override
  void initState() {
    super.initState();
    _loadMerchantState();
  }

  Future<void> _loadMerchantState() async {
    final inbox = await SecureWalletStorage.getInbox();
    final inTransit = DemoTransport().inTransit;
    double total = 0.0;
    for (var tx in inbox) {
      total += tx.amount;
    }

    setState(() {
      _inbox = inbox;
      _inTransit = List.from(inTransit);
      _offlineSalesTotal = total;
    });
  }

  Future<void> _acceptTransaction(LocalTransaction tx) async {
    await DemoTransport().acceptAndProcess(tx);
    await _loadMerchantState();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF00E676),
          content: Row(
            children: [
              const Icon(Icons.verified, color: Colors.black, size: 18),
              const SizedBox(width: 8),
              Text(
                "Verified ₹${tx.amount.toStringAsFixed(2)} from ${tx.senderWalletId}! Added to Offline Inbox.",
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161A29),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Merchant Terminal (POS)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(_merchantId, style: const TextStyle(fontSize: 11, color: Color(0xFFFFA801), fontFamily: 'monospace')),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadMerchantState,
          ),
        ],
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
                  // Merchant Sales Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2C2214), Color(0xFF1B181E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFFA801).withOpacity(0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("OFFLINE SALES COLLECTED", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Colors.white.withOpacity(0.6))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFA801).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.bluetooth_searching, size: 14, color: Color(0xFFFFA801)),
                                  SizedBox(width: 4),
                                  Text("BLE Active", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFFFA801))),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "₹${_offlineSalesTotal.toStringAsFixed(2)}",
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFFFFA801)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${_inbox.length} offline receipts queued for cloud settlement",
                          style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // IN-TRANSIT NEAR-FIELD DETECTOR
                  if (_inTransit.isNotEmpty) ...[
                    const Row(
                      children: [
                        Icon(Icons.sensors_rounded, color: Color(0xFF00CEC9), size: 18),
                        SizedBox(width: 8),
                        Text(
                          "INCOMING BLE BROADCAST DETECTED",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: Color(0xFF00CEC9)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._inTransit.map((tx) => _buildInTransitCard(tx)),
                    const SizedBox(height: 20),
                  ],

                  // MERCHANT INBOX QUEUE
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "VERIFIED OFFLINE INBOX",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: Color(0xFFA29BFE)),
                      ),
                      if (_inbox.isNotEmpty)
                        TextButton.icon(
                          icon: const Icon(Icons.sync_rounded, size: 16, color: Color(0xFF00E676)),
                          label: const Text("Sync to Bank", style: TextStyle(fontSize: 12, color: Color(0xFF00E676), fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const ReconciliationScreen()));
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_inbox.isEmpty && _inTransit.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161A29),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.radar_rounded, size: 36, color: Colors.grey),
                          const SizedBox(height: 10),
                          const Text("Listening for BLE Transmissions...", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70)),
                          const SizedBox(height: 4),
                          Text(
                            "Go to 'Pay Offline' in another screen, send a payment, and it will appear here for local ECDSA verification.",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4)),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._inbox.map((tx) => _buildInboxCard(tx)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInTransitCard(LocalTransaction tx) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2A38),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00CEC9), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.signal_cellular_alt_rounded, color: Color(0xFF00CEC9), size: 18),
                  const SizedBox(width: 6),
                  Text("Incoming: ₹${tx.amount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00CEC9),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                ),
                onPressed: () => _acceptTransaction(tx),
                child: const Text("Verify & Accept", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text("From: ${tx.senderWalletId} | Seq #${tx.sequenceNumber}", style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7))),
          const SizedBox(height: 4),
          Text(
            "Signature: ${tx.signature.length > 28 ? '${tx.signature.substring(0, 28)}...' : tx.signature}",
            style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: Color(0xFFFFA801)),
          ),
        ],
      ),
    );
  }

  Widget _buildInboxCard(LocalTransaction tx) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161A29),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.check_circle_outline, color: Color(0xFF00E676), size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("₹${tx.amount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text("From: ${tx.senderWalletId} (Seq #${tx.sequenceNumber})", style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.5))),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text("Queued", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF00CEC9))),
          ),
        ],
      ),
    );
  }
}
