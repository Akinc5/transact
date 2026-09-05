import 'package:flutter/material.dart';
import '../widgets/network_banner.dart';

class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161A29),
        title: const Text('Security & Threat Model', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                  // Header Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161A29),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF00CEC9).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00CEC9).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.shield_rounded, color: Color(0xFF00CEC9), size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Zero-Trust Security Architecture", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                              const SizedBox(height: 4),
                              Text(
                                "Hardware-bound cryptography guarantees offline safety even if client memory or local files are inspected.",
                                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // THREAT MATRIX
                  const Text("THREAT MATRIX & MITIGATIONS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: Color(0xFFA29BFE))),
                  const SizedBox(height: 10),

                  _buildThreatCard(
                    threat: "Double-Spending (Sender)",
                    severity: "HIGH",
                    severityColor: Colors.redAccent,
                    description: "Sender attempts to spend the same offline voucher balance with multiple merchants simultaneously.",
                    mitigation: "Monotonic signed sequence counter + backend conflict detection locks the voucher immediately upon reconciliation.",
                  ),
                  const SizedBox(height: 10),

                  _buildThreatCard(
                    threat: "Transaction Replay (Receiver)",
                    severity: "HIGH",
                    severityColor: Colors.redAccent,
                    description: "Merchant submits the same signed transaction payload multiple times to get settled twice.",
                    mitigation: "Unique composite database key on (voucher_id, sequence_number) drops duplicates as DUPLICATE without double-crediting.",
                  ),
                  const SizedBox(height: 10),

                  _buildThreatCard(
                    threat: "Local State Rollback / OS Tamper",
                    severity: "CRITICAL",
                    severityColor: Colors.purpleAccent,
                    description: "Attacker roots phone, takes snapshot of SQLite database, spends offline, and restores snapshot.",
                    mitigation: "Sequence gap or sequence rollback (tx.seq <= last_settled_seq) triggers CONFLICT flag and permanently blacklists wallet.",
                  ),
                  const SizedBox(height: 10),

                  _buildThreatCard(
                    threat: "Private Key Extraction / Key Cloning",
                    severity: "CRITICAL",
                    severityColor: Colors.purpleAccent,
                    description: "Malicious app or malware attempts to export the device's signing key.",
                    mitigation: "Private keys generated inside Android Keystore (TEE/StrongBox) are non-exportable by design.",
                  ),
                  const SizedBox(height: 20),

                  // CRYPTO PRIMITIVES
                  const Text("CRYPTOGRAPHIC PRIMITIVES", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: Color(0xFFA29BFE))),
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161A29),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCryptoRow("Algorithm", "ECDSA (Elliptic Curve Digital Signature)"),
                        _buildCryptoRow("Curve", "NIST P-256 / secp256r1 (FIPS 186-4)"),
                        _buildCryptoRow("Hash Function", "SHA-256 Digest"),
                        _buildCryptoRow("Key Isolation", "Android StrongBox Keymaster / Apple Secure Enclave"),
                        _buildCryptoRow("Payload Format", "Canonical Colon-Delimited String"),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // RBI COMPLIANCE
                  const Text("RESERVE BANK OF INDIA (RBI) ALIGNMENT", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: Color(0xFF00CEC9))),
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161A29),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Column(
                      children: [
                        _buildCheckRow("Offline Transaction Cap: Enforced at ₹200.00 (under ₹500 limit).", true),
                        _buildCheckRow("Cumulative Offline Wallet Balance: Enforced at ₹1,000.00 (under ₹2,000 limit).", true),
                        _buildCheckRow("Strict Online Two-Factor Top-Up: Vouchers mint only via authenticated bank clearing.", true),
                        _buildCheckRow("Audit & Dispute Settlement: Cryptographic signatures logged for dispute resolution.", true),
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

  Widget _buildThreatCard({
    required String threat,
    required String severity,
    required Color severityColor,
    required String description,
    required String mitigation,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161A29),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(threat, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: severityColor.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                child: Text(severity, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: severityColor)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(description, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.65))),
          const SizedBox(height: 6),
          Text("🛡️ Mitigation: $mitigation", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF00CEC9))),
        ],
      ),
    );
  }

  Widget _buildCryptoRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6))),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildCheckRow(String text, bool checked) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF00E676), size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.8)))),
        ],
      ),
    );
  }
}
