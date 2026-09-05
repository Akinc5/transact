import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'architecture_screen.dart';
import 'security_screen.dart';
import '../widgets/network_banner.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161A29),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF6C5CE7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bolt, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Transact Protocol',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.shield_outlined, color: Color(0xFF00CEC9)),
            tooltip: "Security Architecture",
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SecurityScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_tree_outlined, color: Color(0xFFA29BFE)),
            tooltip: "System Design & Flow",
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ArchitectureScreen()));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const NetworkStatusBanner(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero Badge
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C5CE7).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF6C5CE7).withOpacity(0.5)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_clock, size: 14, color: Color(0xFFA29BFE)),
                          SizedBox(width: 6),
                          Text(
                            "Next-Gen Offline UPI Protocol",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFA29BFE),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Hero Title & Subtitle
                  const Text(
                    "Digital Payments That Survive When The Network Doesn't.",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Instant peer-to-peer settlement in subterranean metros, remote highways, disaster zones, or crowded festivals — backed by hardware TEE cryptography and RBI UPI Lite risk bounds.",
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.white.withOpacity(0.75),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Primary Action Buttons
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 4,
                    ),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Launch Interactive Demo",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // 3 Core Pillar Cards for Hackathon Judges
                  const Text(
                    "CORE ARCHITECTURAL PILLARS",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Color(0xFF00CEC9),
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildFeatureCard(
                    icon: Icons.vpn_key_rounded,
                    iconColor: const Color(0xFF00CEC9),
                    title: "1. Hardware TEE Keystore Signatures",
                    description: "Every offline transaction payload is signed by non-exportable private keys isolated in Android StrongBox / TEE (secp256r1 ECDSA).",
                  ),
                  const SizedBox(height: 12),

                  _buildFeatureCard(
                    icon: Icons.receipt_long_rounded,
                    iconColor: const Color(0xFFFFA801),
                    title: "2. Cryptographically Bound Vouchers",
                    description: "Vouchers are pre-minted online with bank ledger fund locking. Offline transactions deduct against verifiable remaining bounds.",
                  ),
                  const SizedBox(height: 12),

                  _buildFeatureCard(
                    icon: Icons.security_update_warning_rounded,
                    iconColor: const Color(0xFFFF5252),
                    title: "3. Monotonic Sequence Anti-Replay",
                    description: "Double-spending, sequence rollback, and limit breaches are caught instantaneously by the reconciliation engine during sync.",
                  ),
                  const SizedBox(height: 24),

                  // Quick Links Row
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.white.withOpacity(0.2)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF00CEC9)),
                          label: const Text("Threat Model", style: TextStyle(color: Colors.white, fontSize: 13)),
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const SecurityScreen()));
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.white.withOpacity(0.2)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.account_tree_outlined, size: 16, color: Color(0xFFA29BFE)),
                          label: const Text("Razorpay Flow", style: TextStyle(color: Colors.white, fontSize: 13)),
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const ArchitectureScreen()));
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161A29),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Colors.white.withOpacity(0.65),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
