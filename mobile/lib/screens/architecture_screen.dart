import 'package:flutter/material.dart';
import '../widgets/network_banner.dart';

class ArchitectureScreen extends StatelessWidget {
  const ArchitectureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161A29),
        title: const Text('Protocol Architecture', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                  // Hero Concept Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161A29),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFA29BFE).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFA29BFE).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.account_tree_rounded, color: Color(0xFFA29BFE), size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("3-Phase Asynchronous Settlement", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                              const SizedBox(height: 4),
                              Text(
                                "Separates fund locking, offline cryptographic handover, and asynchronous clearing.",
                                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // PHASE 1: VOUCHER ISSUANCE
                  _buildPhaseSection(
                    phaseNumber: "1",
                    phaseTitle: "Online Voucher Minting",
                    networkTag: "ONLINE",
                    networkColor: const Color(0xFF00E676),
                    steps: [
                      "Sender's app requests a signed offline voucher from the Transact Clearinghouse.",
                      "Bank ledger balance is deducted and locked in escrow.",
                      "Clearinghouse generates a signed Voucher token (EC secp256r1) with strict risk bounds (₹200/tx, 7-day expiry, 10-tx cap).",
                      "Voucher token is stored in the device's secure storage.",
                    ],
                  ),
                  const SizedBox(height: 16),

                  // PHASE 2: OFFLINE P2P PAYMENT
                  _buildPhaseSection(
                    phaseNumber: "2",
                    phaseTitle: "Offline P2P Near-Field Transfer",
                    networkTag: "ZERO CONNECTIVITY",
                    networkColor: const Color(0xFFFF5252),
                    steps: [
                      "Sender enters amount and merchant ID in subway or remote zone.",
                      "Local app increments monotonic sequence counter (#1, #2, #3...).",
                      "Android StrongBox/TEE signs canonical payload with device private key.",
                      "Payload transmitted via BLE GATT advertisement / NFC packet.",
                      "Merchant POS validates Server Signature on Voucher and Sender's ECDSA signature locally.",
                      "Merchant displays green confirmation & stores receipt in local Inbox queue.",
                    ],
                  ),
                  const SizedBox(height: 16),

                  // PHASE 3: RECONCILIATION
                  _buildPhaseSection(
                    phaseNumber: "3",
                    phaseTitle: "Central Clearing & Settlement",
                    networkTag: "ONLINE",
                    networkColor: const Color(0xFF00E676),
                    steps: [
                      "When either Merchant or Sender reconnects to Wi-Fi/4G, logs auto-sync.",
                      "Reconciliation engine verifies cryptographic signatures and monotonic sequences.",
                      "Funds are transferred from escrow to Merchant's live bank account.",
                      "If replay or sequence rollback is detected, transaction is flagged as CONFLICT/DUPLICATE and wallet is locked.",
                    ],
                  ),
                  const SizedBox(height: 24),

                  // RAZORPAY INTEGRATION ROADMAP
                  const Text("RAZORPAY OFFLINE SDK CONCEPT", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: Color(0xFF00CEC9))),
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF162536), Color(0xFF131A2E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF00CEC9).withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.integration_instructions_rounded, color: Color(0xFF00CEC9), size: 20),
                            SizedBox(width: 8),
                            Text("Drop-In SDK for Razorpay Merchants", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Merchants using Razorpay POS or Flutter SDK can enable offline fallback with a single line of code:\n`razorpay.enableOfflineUPIFallback(bounds: UPILiteBounds())`",
                          style: TextStyle(fontSize: 11, height: 1.4, color: Colors.white.withOpacity(0.8)),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
                          child: const Text(
                            "// Razorpay Seamless Handshake\nRazorpayOffline.startListener(\n  onPaymentVerified: (receipt) => print('Settled: ₹\${receipt.amount}')\n);",
                            style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF00E676)),
                          ),
                        ),
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

  Widget _buildPhaseSection({
    required String phaseNumber,
    required String phaseTitle,
    required String networkTag,
    required Color networkColor,
    required List<String> steps,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161A29),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(phaseNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                  ),
                  const SizedBox(width: 10),
                  Text(phaseTitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: networkColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(networkTag, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: networkColor)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...steps.map((step) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("→ ", style: TextStyle(color: Color(0xFFA29BFE), fontWeight: FontWeight.bold)),
                    Expanded(child: Text(step, style: TextStyle(fontSize: 11, height: 1.35, color: Colors.white.withOpacity(0.7)))),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
