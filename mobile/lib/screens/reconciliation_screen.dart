import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/secure_storage.dart';
import '../network/api_client.dart';
import '../services/network_simulator.dart';
import '../widgets/network_banner.dart';

class ReconciliationScreen extends StatefulWidget {
  const ReconciliationScreen({super.key});

  @override
  State<ReconciliationScreen> createState() => _ReconciliationScreenState();
}

class _ReconciliationScreenState extends State<ReconciliationScreen> {
  List<LocalTransaction> _outbox = [];
  List<LocalTransaction> _inbox = [];
  List<dynamic> _serverHistory = [];
  bool _isSyncing = false;
  Map<String, dynamic>? _lastSyncResult;

  @override
  void initState() {
    super.initState();
    _loadSyncQueues();
  }

  Future<void> _loadSyncQueues() async {
    final outbox = await SecureWalletStorage.getOutbox();
    final inbox = await SecureWalletStorage.getInbox();
    final walletId = await SecureWalletStorage.getWalletId() ?? 'akshansh@transact';

    List<dynamic> history = [];
    if (NetworkSimulator().isOnline) {
      final remoteHistory = await ApiClient.getLedgerHistory(walletId);
      if (remoteHistory != null) {
        history = remoteHistory;
      }
    }

    setState(() {
      _outbox = outbox;
      _inbox = inbox;
      _serverHistory = history;
    });
  }

  Future<void> _performSync() async {
    if (!NetworkSimulator().isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text("Reconciliation requires internet. Please switch network to Online using top bar."),
        ),
      );
      return;
    }

    final combined = [..._outbox, ..._inbox];
    if (combined.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No offline transactions in queue to reconcile.")),
      );
      return;
    }

    setState(() => _isSyncing = true);

    final res = await ApiClient.syncTransactions(combined);
    setState(() => _isSyncing = false);

    if (res != null) {
      _lastSyncResult = res;

      // Update local storage audit statuses
      if (res['details'] != null) {
        for (var d in res['details']) {
          final seq = d['sequence_number'] as int;
          final status = d['status'] as String;
          final err = d['error_message'] as String?;
          await SecureWalletStorage.updateAuditStatus(seq, status, error: err);
        }
      }

      // Clear the synced outbox & inbox
      await SecureWalletStorage.clearOutbox();
      await SecureWalletStorage.clearInbox();

      // Refresh online bank balances
      final walletId = await SecureWalletStorage.getWalletId() ?? 'akshansh@transact';
      final walletRes = await ApiClient.getWallet(walletId);
      if (walletRes != null) {
        final bal = (walletRes['balance'] as num).toDouble();
        await SecureWalletStorage.saveOnlineBalance(bal);
      }

      await _loadSyncQueues();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: res['status'] == "SUCCESS" ? const Color(0xFF00E676) : Colors.orangeAccent,
            content: Text(
              "Reconciliation ${res['status']}! Reconciled: ${res['reconciled_count']}, Flagged/Failed: ${res['failed_count']}",
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
            ),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.redAccent, content: Text("Sync failed. Check backend connection.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _outbox.length + _inbox.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161A29),
        title: const Text('Reconciliation & Audit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadSyncQueues,
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
                  // Pending Sync Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161A29),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("QUEUED OFFLINE TRANSACTIONS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Colors.white.withOpacity(0.5))),
                                const SizedBox(height: 4),
                                Text(
                                  "$pendingCount Records",
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: pendingCount > 0 ? const Color(0xFFFFA801).withOpacity(0.2) : const Color(0xFF00E676).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                pendingCount > 0 ? "Pending Cloud Sync" : "Ledger In Sync",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: pendingCount > 0 ? const Color(0xFFFFA801) : const Color(0xFF00E676),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00E676),
                            foregroundColor: Colors.black,
                            minimumSize: const Size.fromHeight(46),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _isSyncing ? null : _performSync,
                          child: _isSyncing
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.cloud_upload_rounded, size: 20),
                                    SizedBox(width: 8),
                                    Text("Reconcile & Upload to Clearinghouse", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // LAST SYNC RESULTS (IF ANY)
                  if (_lastSyncResult != null) ...[
                    _buildLastSyncResultBox(),
                    const SizedBox(height: 24),
                  ],

                  // SERVER SETTLED AUDIT TRAIL
                  const Text(
                    "CENTRAL CLEARINGHOUSE AUDIT TRAIL",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: Color(0xFFA29BFE)),
                  ),
                  const SizedBox(height: 10),

                  if (_serverHistory.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161A29),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "No reconciled transactions yet. Queue offline payments and click 'Reconcile' above.",
                        style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ..._serverHistory.map((item) => _buildLedgerCard(item)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastSyncResultBox() {
    final res = _lastSyncResult!;
    final details = (res['details'] as List?) ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2433),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF00CEC9).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("LATEST SYNC BATCH REPORT", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF00CEC9))),
              Text(
                "Status: ${res['status']}",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: res['status'] == "SUCCESS" ? const Color(0xFF00E676) : Colors.orangeAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text("Settled: ${res['reconciled_count']}  |  Flagged/Rejected: ${res['failed_count']}",
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 10),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 10),
          ...details.map((d) {
            final st = d['status'] as String;
            final isGood = st == "SETTLED";
            final isConflict = st == "CONFLICT" || st == "DUPLICATE";
            final color = isGood ? const Color(0xFF00E676) : isConflict ? Colors.redAccent : Colors.orangeAccent;

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(isGood ? Icons.check_circle : Icons.warning_rounded, size: 14, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Seq #${d['sequence_number']} (₹${d['amount']}): $st ${d['error_message'] != null ? '- ' + d['error_message'] : ''}",
                      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLedgerCard(dynamic item) {
    final status = item['status'] ?? 'SETTLED';
    final isFraud = item['fraud_flag'] == true || status == "CONFLICT" || status == "DUPLICATE";
    final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
    final seq = item['sequence_number'] ?? 0;
    final sender = item['sender_wallet_id'] ?? '';
    final receiver = item['receiver_wallet_id'] ?? '';
    final timestampStr = item['reconciled_at'] ?? item['timestamp'] ?? '';
    
    DateTime? dt;
    try {
      dt = DateTime.parse(timestampStr);
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161A29),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFraud ? Colors.redAccent.withOpacity(0.5) : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isFraud ? Colors.redAccent.withOpacity(0.15) : const Color(0xFF00E676).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isFraud ? Icons.gavel_rounded : Icons.check_rounded,
                  color: isFraud ? Colors.redAccent : const Color(0xFF00E676),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text("₹${amount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(width: 6),
                      Text("Seq #$seq", style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFFA29BFE))),
                    ],
                  ),
                  Text("$sender -> $receiver", style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.55))),
                  if (dt != null)
                    Text(DateFormat('MMM dd, HH:mm:ss').format(dt), style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.4))),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isFraud ? Colors.redAccent.withOpacity(0.2) : const Color(0xFF00E676).withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isFraud ? Colors.redAccent : const Color(0xFF00E676),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
