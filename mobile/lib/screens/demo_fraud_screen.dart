import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/secure_storage.dart';
import '../network/api_client.dart';
import '../security/keystore_manager.dart';
import '../services/network_simulator.dart';
import '../widgets/network_banner.dart';

class DemoFraudScreen extends StatefulWidget {
  const DemoFraudScreen({super.key});

  @override
  State<DemoFraudScreen> createState() => _DemoFraudScreenState();
}

class _DemoFraudScreenState extends State<DemoFraudScreen> {
  int _selectedAttackIndex = 0;
  bool _isAttacking = false;
  Map<String, dynamic>? _attackResult;
  Map<String, dynamic>? _fraudStats;

  final List<Map<String, String>> _attacks = [
    {
      'title': '1. Replay Double-Spend (Same Seq to 2 Merchants)',
      'description': 'The attacker pays Merchant A ₹100 with Seq #1, then re-broadcasts the exact same signed payload to Merchant B to get free goods.',
      'expected': 'Backend detects duplicate transaction signature & sequence, flags as DUPLICATE and refuses settlement to Merchant B.',
    },
    {
      'title': '2. Sequence Rollback / Forking (Reused Monotonic Seq)',
      'description': 'The attacker resets their local database back to Seq #1 and signs a different ₹150 transaction after already settling Seq #2.',
      'expected': 'Backend detects sequence rollback (Seq 1 <= last_settled_seq 2), flags as CONFLICT / FRAUD, locks the voucher.',
    },
    {
      'title': '3. Single Offline Transaction Cap Breach (> ₹200)',
      'description': 'The attacker bypasses client UI validation and signs an offline transaction of ₹800 (exceeding RBI ₹200 cap).',
      'expected': 'Backend reconciliation engine enforces max_offline_transaction policy, immediately REJECTS settlement and flags wallet.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadFraudStats();
  }

  Future<void> _loadFraudStats() async {
    if (NetworkSimulator().isOnline) {
      final stats = await ApiClient.getFraudDashboard();
      if (stats != null) {
        setState(() {
          _fraudStats = stats;
        });
      }
    }
  }

  Future<void> _executeFraudSimulation() async {
    if (!NetworkSimulator().isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text("Simulation reconciliation requires online connection to backend. Switch to Online using top bar."),
        ),
      );
      return;
    }

    final voucher = await SecureWalletStorage.getVoucher();
    if (voucher == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orangeAccent,
          content: Text("Please top-up an offline voucher first from Dashboard before testing the fraud engine."),
        ),
      );
      return;
    }

    final walletId = await SecureWalletStorage.getWalletId() ?? 'akshansh@transact';
    setState(() => _isAttacking = true);

    List<LocalTransaction> attackBatch = [];

    if (_selectedAttackIndex == 0) {
      // Scenario 1: Replay Attack (Send exact same tx twice)
      final seq = await SecureWalletStorage.getNextSequenceNumber();
      final time = DateTime.now().toIso8601String();
      final payload = "${voucher.id}:$walletId:merchant_a@transact:100.00:$seq:$time";
      final sig = await KeystoreManager.signPayload(payload);

      final tx1 = LocalTransaction(
        voucherId: voucher.id,
        senderWalletId: walletId,
        receiverWalletId: "merchant_a@transact",
        amount: 100.0,
        sequenceNumber: seq,
        timestampIso: time,
        signature: sig,
      );

      final tx2Replay = LocalTransaction(
        voucherId: voucher.id,
        senderWalletId: walletId,
        receiverWalletId: "merchant_b@transact",
        amount: 100.0,
        sequenceNumber: seq, // Duplicate sequence!
        timestampIso: time,
        signature: sig,      // Replay signature!
      );

      attackBatch = [tx1, tx2Replay];
    } else if (_selectedAttackIndex == 1) {
      // Scenario 2: Rollback / Fork Attack (Reused Seq with different payload)
      // First settle seq #5, then try to submit seq #2
      final time1 = DateTime.now().toIso8601String();
      final p1 = "${voucher.id}:$walletId:legit_merchant@transact:50.00:5:$time1";
      final sig1 = await KeystoreManager.signPayload(p1);
      final txLegit = LocalTransaction(
        voucherId: voucher.id,
        senderWalletId: walletId,
        receiverWalletId: "legit_merchant@transact",
        amount: 50.0,
        sequenceNumber: 5,
        timestampIso: time1,
        signature: sig1,
      );

      final time2 = DateTime.now().toIso8601String();
      final p2 = "${voucher.id}:$walletId:victim_merchant@transact:80.00:2:$time2";
      final sig2 = await KeystoreManager.signPayload(p2);
      final txRollback = LocalTransaction(
        voucherId: voucher.id,
        senderWalletId: walletId,
        receiverWalletId: "victim_merchant@transact",
        amount: 80.0,
        sequenceNumber: 2, // Rollback! 2 < 5
        timestampIso: time2,
        signature: sig2,
      );

      attackBatch = [txLegit, txRollback];
    } else {
      // Scenario 3: Limit Breach (> ₹200)
      final seq = await SecureWalletStorage.getNextSequenceNumber();
      final time = DateTime.now().toIso8601String();
      final p = "${voucher.id}:$walletId:expensive_merchant@transact:800.00:$seq:$time";
      final sig = await KeystoreManager.signPayload(p);
      final txBreach = LocalTransaction(
        voucherId: voucher.id,
        senderWalletId: walletId,
        receiverWalletId: "expensive_merchant@transact",
        amount: 800.0, // Exceeds 200 limit
        sequenceNumber: seq,
        timestampIso: time,
        signature: sig,
      );

      attackBatch = [txBreach];
    }

    final res = await ApiClient.syncTransactions(attackBatch);
    setState(() {
      _isAttacking = false;
      _attackResult = res;
    });

    await _loadFraudStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161A29),
        title: const Row(
          children: [
            Icon(Icons.gavel_rounded, color: Color(0xFFFF5252), size: 20),
            SizedBox(width: 8),
            Text('Double-Spend & Fraud Engine', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
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
                  // Header Alert
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B1528),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFF5252).withOpacity(0.4)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.security_update_warning_rounded, color: Color(0xFFFF5252), size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Live Attack Simulation Suite", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                              const SizedBox(height: 4),
                              Text(
                                "Demonstrates how Transact guarantees double-spend immunity and cryptographic integrity without real-time internet connectivity.",
                                style: TextStyle(fontSize: 11, height: 1.35, color: Colors.white.withOpacity(0.8)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ATTACK SELECTION
                  const Text("SELECT ATTACK VECTOR TO SIMULATE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: Color(0xFFA29BFE))),
                  const SizedBox(height: 10),

                  ..._attacks.asMap().entries.map((entry) {
                    final index = entry.key;
                    final attack = entry.value;
                    final isSelected = _selectedAttackIndex == index;

                    return InkWell(
                      onTap: () => setState(() => _selectedAttackIndex = index),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF261D36) : const Color(0xFF161A29),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF6C5CE7) : Colors.white.withOpacity(0.06),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                  size: 18,
                                  color: isSelected ? const Color(0xFF6C5CE7) : Colors.grey,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    attack['title']!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.white : Colors.white70,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.only(left: 28),
                              child: Text(
                                attack['description']!,
                                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.65)),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.only(left: 28),
                              child: Text(
                                "🛡️ Expected Defense: ${attack['expected']!}",
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF00CEC9)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 14),

                  // Execute Attack Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5252),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _isAttacking ? null : _executeFraudSimulation,
                    child: _isAttacking
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.bolt, size: 20),
                              SizedBox(width: 8),
                              Text("Execute Fraud Attack & Inspect Backend Flag", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                  ),
                  const SizedBox(height: 24),

                  // ATTACK RESULT
                  if (_attackResult != null) ...[
                    _buildAttackResultCard(),
                    const SizedBox(height: 24),
                  ],

                  // LIVE FRAUD STATS DASHBOARD
                  if (_fraudStats != null) ...[
                    _buildFraudStatsDashboard(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttackResultCard() {
    final res = _attackResult!;
    final details = (res['details'] as List?) ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2E1520),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFF5252)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.gavel, color: Color(0xFFFF5252), size: 18),
              SizedBox(width: 8),
              Text("BACKEND RECONCILIATION RESULT", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF5252), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Overall Status: ${res['status']} | Flagged/Failed: ${res['failed_count']}",
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 10),
          ...details.map((d) {
            final st = d['status'] as String;
            final isFail = st != "SETTLED";

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Seq #${d['sequence_number']} -> ${d['receiver']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isFail ? Colors.redAccent.withOpacity(0.25) : Colors.green.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          st,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isFail ? Colors.redAccent : Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (d['error_message'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      "Alert: ${d['error_message']}",
                      style: const TextStyle(fontSize: 10, color: Color(0xFFFFA801), fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFraudStatsDashboard() {
    final s = _fraudStats!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161A29),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("SERVER CLEARINGHOUSE FRAUD ANALYTICS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: Color(0xFF00CEC9))),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatMetric("Total Tx", "${s['total_transactions']}", Colors.white),
              _buildStatMetric("Settled", "${s['settled_count']}", const Color(0xFF00E676)),
              _buildStatMetric("Fraud Flags", "${s['fraud_count']}", const Color(0xFFFF5252)),
              _buildStatMetric("Duplicates", "${s['duplicate_count']}", const Color(0xFFFFA801)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatMetric(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.5))),
        ],
      ),
    );
  }
}
