import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/secure_storage.dart';
import '../network/api_client.dart';
import '../security/keystore_manager.dart';
import '../services/network_simulator.dart';
import '../widgets/network_banner.dart';
import 'top_up_screen.dart';
import 'offline_pay_screen.dart';
import 'merchant_mode_screen.dart';
import 'reconciliation_screen.dart';
import 'demo_fraud_screen.dart';
import 'security_screen.dart';
import 'architecture_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _walletId = 'akshansh@transact';
  String _pubKey = '';
  double _onlineBalance = 10000.0;
  VoucherData? _voucher;
  int _outboxCount = 0;
  int _inboxCount = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshState();
  }

  Future<void> _refreshState() async {
    setState(() => _isLoading = true);
    await KeystoreManager.generateKeyPair();
    final pubKey = await KeystoreManager.getPublicKeyHex();
    final savedWalletId = await SecureWalletStorage.getWalletId() ?? 'akshansh@transact';
    await SecureWalletStorage.saveWalletId(savedWalletId);
    final voucher = await SecureWalletStorage.getVoucher();
    final outbox = await SecureWalletStorage.getOutbox();
    final inbox = await SecureWalletStorage.getInbox();
    final localOnlineBal = await SecureWalletStorage.getOnlineBalance();

    // If online, also sync wallet balance from server
    double onlineBal = localOnlineBal;
    if (NetworkSimulator().isOnline) {
      final remoteWallet = await ApiClient.getWallet(savedWalletId);
      if (remoteWallet != null) {
        onlineBal = (remoteWallet['balance'] as num).toDouble();
        await SecureWalletStorage.saveOnlineBalance(onlineBal);
      } else {
        // Auto register on server if not present
        await ApiClient.registerWallet(savedWalletId, pubKey);
      }
    }

    setState(() {
      _walletId = savedWalletId;
      _pubKey = pubKey;
      _voucher = voucher;
      _onlineBalance = onlineBal;
      _outboxCount = outbox.length;
      _inboxCount = inbox.length;
      _isLoading = false;
    });
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
            const Text('Transact Dashboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            Text(
              _walletId,
              style: const TextStyle(fontSize: 11, color: Color(0xFF00CEC9), fontFamily: 'monospace'),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshState,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) async {
              if (val == 'security') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SecurityScreen()));
              } else if (val == 'architecture') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ArchitectureScreen()));
              } else if (val == 'reset') {
                await SecureWalletStorage.clearAll();
                await ApiClient.resetServerDemo();
                await _refreshState();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Demo storage and backend reset successfully")),
                  );
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'security', child: Text('Security & Keystore Details')),
              const PopupMenuItem(value: 'architecture', child: Text('Architecture & Flow')),
              const PopupMenuItem(value: 'reset', child: Text('Reset Complete Demo State', style: TextStyle(color: Colors.redAccent))),
            ],
          )
        ],
      ),
      body: Column(
        children: [
          const NetworkStatusBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshState,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. DUAL BALANCE CARD (Bank Ledger vs Offline Voucher)
                    _buildDualBalanceCard(),
                    const SizedBox(height: 16),

                    // 2. QUICK ACTION TILES
                    const Text(
                      "TRANSACTION & DEMO ACTIONS",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Color(0xFFA29BFE)),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: _buildActionTile(
                            title: "Top-Up Offline",
                            subtitle: "Online Bank -> Voucher",
                            icon: Icons.add_card_rounded,
                            color: const Color(0xFF6C5CE7),
                            onTap: () async {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => const TopUpScreen()));
                              _refreshState();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildActionTile(
                            title: "Pay Offline",
                            subtitle: "BLE P2P Transfer",
                            icon: Icons.send_rounded,
                            color: const Color(0xFF00CEC9),
                            onTap: () async {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => const OfflinePayScreen()));
                              _refreshState();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: _buildActionTile(
                            title: "Merchant Mode",
                            subtitle: "Accept & Verify BLE",
                            icon: Icons.storefront_rounded,
                            color: const Color(0xFFFFA801),
                            badgeCount: _inboxCount,
                            onTap: () async {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => const MerchantModeScreen()));
                              _refreshState();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildActionTile(
                            title: "Sync & Reconcile",
                            subtitle: "Upload Offline Logs",
                            icon: Icons.sync_rounded,
                            color: const Color(0xFF00E676),
                            badgeCount: _outboxCount,
                            onTap: () async {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => const ReconciliationScreen()));
                              _refreshState();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 3. SPECIAL HACKATHON FRAUD DEMO CARD
                    _buildFraudDemoBanner(),
                    const SizedBox(height: 16),

                    // 4. ACTIVE VOUCHER RISK POLICY & STATUS
                    _buildVoucherDetailsCard(),
                    const SizedBox(height: 16),

                    // 5. HARDWARE KEYSTORE INFO
                    _buildKeystoreInfoCard(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDualBalanceCard() {
    final hasVoucher = _voucher != null && _voucher!.remainingBalance > 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B38), Color(0xFF131A2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF6C5CE7).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C5CE7).withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("ACTIVE OFFLINE BALANCE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: Colors.white.withOpacity(0.6))),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        hasVoucher ? "₹${_voucher!.remainingBalance.toStringAsFixed(2)}" : "₹0.00",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: hasVoucher ? const Color(0xFF00CEC9) : Colors.white.withOpacity(0.4),
                        ),
                      ),
                      if (hasVoucher) ...[
                        const SizedBox(width: 6),
                        Text(
                          "/ ₹${_voucher!.amount.toStringAsFixed(0)} loaded",
                          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: hasVoucher ? const Color(0xFF00CEC9).withOpacity(0.15) : Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: hasVoucher ? const Color(0xFF00CEC9).withOpacity(0.4) : Colors.transparent),
                ),
                child: Row(
                  children: [
                    Icon(
                      hasVoucher ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                      size: 14,
                      color: hasVoucher ? const Color(0xFF00CEC9) : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasVoucher ? "Voucher Active" : "No Voucher",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: hasVoucher ? const Color(0xFF00CEC9) : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded, size: 16, color: Color(0xFFA29BFE)),
                  const SizedBox(width: 6),
                  Text("Online Bank Ledger Balance:", style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
                ],
              ),
              Text(
                "₹${_onlineBalance.toStringAsFixed(2)}",
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF161A29),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                if (badgeCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "$badgeCount Pending",
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.55))),
          ],
        ),
      ),
    );
  }

  Widget _buildFraudDemoBanner() {
    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const DemoFraudScreen()));
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3B1528), Color(0xFF26122C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFF5252).withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5252).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.gavel_rounded, color: Color(0xFFFF5252), size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text(
                        "Double-Spend & Fraud Engine",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      SizedBox(width: 6),
                      Text("⭐ WOW DEMO", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFFFA801))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Simulate replay attacks, sequence tampering & offline limit violations to see the backend flag fraud in real-time.",
                    style: TextStyle(fontSize: 11, height: 1.3, color: Colors.white.withOpacity(0.7)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white54),
          ],
        ),
      ),
    );
  }

  Widget _buildVoucherDetailsCard() {
    if (_voucher == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF161A29),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.grey, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "No offline voucher loaded. Tap 'Top-Up Offline' while online to mint a signed voucher.",
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6)),
              ),
            ),
          ],
        ),
      );
    }

    final v = _voucher!;
    final expiryDate = DateTime.fromMillisecondsSinceEpoch(v.expiryTimestamp);

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
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "ACTIVE VOUCHER RISK PARAMETERS",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: Color(0xFF00CEC9)),
              ),
              Icon(Icons.verified_rounded, size: 16, color: Color(0xFF00CEC9)),
            ],
          ),
          const SizedBox(height: 12),
          _buildParamRow("Voucher UUID", "${v.id.substring(0, 18)}...", isMono: true),
          _buildParamRow("Per-Transaction Cap", "₹${v.maxOfflineTransaction.toStringAsFixed(2)} (RBI Bound)"),
          _buildParamRow("Cumulative Offline Cap", "₹${v.maxCumulativeSpending.toStringAsFixed(2)}"),
          _buildParamRow("Max Offline Transactions", "${v.maxTransactionsCount} tx limit"),
          _buildParamRow("Valid Until", DateFormat('MMM dd, yyyy HH:mm').format(expiryDate)),
          const SizedBox(height: 6),
          const Text("Server ECDSA Signature:", style: TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.all(6),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              v.signature,
              style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: Color(0xFFFFA801)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParamRow(String label, String value, {bool isMono = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.65))),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: isMono ? 'monospace' : null,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeystoreInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161A29),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined, size: 16, color: Color(0xFFA29BFE)),
              SizedBox(width: 6),
              Text("Hardware Keystore State", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Curve: secp256r1 ECDSA | Isolated in Android StrongBox / TEE",
            style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6)),
          ),
          const SizedBox(height: 4),
          Text(
            "Public Key: ${_pubKey.isNotEmpty ? (_pubKey.length > 32 ? '${_pubKey.substring(0, 32)}...' : _pubKey) : 'Initializing...'}",
            style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFFA29BFE)),
          ),
        ],
      ),
    );
  }
}
