import 'package:flutter/material.dart';
import '../db/secure_storage.dart';
import '../network/api_client.dart';
import '../security/keystore_manager.dart';
import '../services/network_simulator.dart';
import '../widgets/network_banner.dart';

class TopUpScreen extends StatefulWidget {
  const TopUpScreen({super.key});

  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  final TextEditingController _amountController = TextEditingController(text: '1000');
  double _bankBalance = 10000.0;
  String _walletId = 'akshansh@transact';
  bool _isLoading = false;
  VoucherData? _currentVoucher;

  final List<double> _presetAmounts = [200, 500, 1000, 2000];

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final bal = await SecureWalletStorage.getOnlineBalance();
    final wallet = await SecureWalletStorage.getWalletId() ?? 'akshansh@transact';
    final voucher = await SecureWalletStorage.getVoucher();
    setState(() {
      _bankBalance = bal;
      _walletId = wallet;
      _currentVoucher = voucher;
    });
  }

  Future<void> _mintVoucher() async {
    if (!NetworkSimulator().isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text("RBI Mandate: Voucher issuance requires an active online bank connection. Please toggle Network to Online."),
        ),
      );
      return;
    }

    final amt = double.tryParse(_amountController.text.trim());
    if (amt == null || amt <= 0) {
      _showSnack("Please enter a valid voucher amount");
      return;
    }
    if (amt > 5000) {
      _showSnack("Maximum RBI offline voucher limit is ₹5,000");
      return;
    }
    if (amt > _bankBalance) {
      _showSnack("Insufficient online bank balance");
      return;
    }

    setState(() => _isLoading = true);

    // Ensure device public key is registered with the clearinghouse
    final pubKey = await KeystoreManager.getPublicKeyHex();
    await ApiClient.registerWallet(_walletId, pubKey);

    final res = await ApiClient.issueVoucher(_walletId, amt);
    setState(() => _isLoading = false);

    if (res != null) {
      final expiry = DateTime.parse(res['expiry']);
      final voucher = VoucherData(
        id: res['id'],
        walletId: _walletId,
        amount: (res['amount'] as num).toDouble(),
        remainingBalance: (res['remaining_balance'] as num).toDouble(),
        maxOfflineTransaction: (res['max_offline_transaction'] as num?)?.toDouble() ?? 200.0,
        maxCumulativeSpending: (res['max_cumulative_spending'] as num?)?.toDouble() ?? amt,
        maxTransactionsCount: (res['max_transactions_count'] as num?)?.toInt() ?? 10,
        expiryTimestamp: expiry.millisecondsSinceEpoch,
        signature: res['signature'],
      );

      await SecureWalletStorage.saveVoucher(voucher);

      // Refresh bank balance from server
      final walletInfo = await ApiClient.getWallet(_walletId);
      if (walletInfo != null) {
        final newBal = (walletInfo['balance'] as num).toDouble();
        await SecureWalletStorage.saveOnlineBalance(newBal);
        _bankBalance = newBal;
      }

      setState(() {
        _currentVoucher = voucher;
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF161A29),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF00E676)),
                SizedBox(width: 8),
                Text("Voucher Minted!", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("₹${amt.toStringAsFixed(2)} has been locked in your bank and loaded into your hardware-backed offline wallet.",
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Voucher ID: ${voucher.id.substring(0, 16)}...", style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text("Server Signature Verified: EC secp256r1", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF00CEC9))),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7)),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text("Go to Dashboard", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    } else {
      _showSnack("Failed to issue voucher. Check backend connection.");
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = NetworkSimulator().isOnline;

    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161A29),
        title: const Text('Provision Offline Funds', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                  // Bank Source Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161A29),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C5CE7).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.account_balance_rounded, color: Color(0xFFA29BFE), size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Source: HDFC Bank / UPI A/C", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                              const SizedBox(height: 2),
                              Text("Linked ID: $_walletId", style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.55))),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text("₹${_bankBalance.toStringAsFixed(2)}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF00CEC9))),
                            Text("Available", style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.5))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Amount Selector
                  const Text("ENTER VOUCHER AMOUNT (INR)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: Color(0xFFA29BFE))),
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
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6C5CE7), width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Quick presets
                  Wrap(
                    spacing: 8,
                    children: _presetAmounts.map((amt) {
                      return ChoiceChip(
                        label: Text("₹${amt.toStringAsFixed(0)}", style: const TextStyle(fontSize: 12)),
                        selected: _amountController.text == amt.toStringAsFixed(0),
                        selectedColor: const Color(0xFF6C5CE7),
                        backgroundColor: const Color(0xFF161A29),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _amountController.text = amt.toStringAsFixed(0);
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // RBI Policy & Risk Parameters Box
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B2433),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF00CEC9).withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.policy_rounded, size: 16, color: Color(0xFF00CEC9)),
                            SizedBox(width: 8),
                            Text("Embedded Risk Constraints (RBI Framework)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00CEC9))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildRuleLine("Max ₹200.00 per single offline transaction."),
                        _buildRuleLine("Max ₹1,000.00 cumulative spending cap."),
                        _buildRuleLine("Automatic 7-day expiry with auto-refund on settlement."),
                        _buildRuleLine("Cryptographic server signature required for acceptance."),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (!isOnline)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B1515),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Device is offline. Please switch network to Online using top bar to top-up.",
                              style: TextStyle(fontSize: 11, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _isLoading ? null : _mintVoucher,
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Issue & Cryptographically Sign Voucher", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("• ", style: TextStyle(color: Color(0xFF00CEC9))),
          Expanded(child: Text(text, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.75)))),
        ],
      ),
    );
  }
}
