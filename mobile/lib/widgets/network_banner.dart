import 'dart:async';
import 'package:flutter/material.dart';
import '../services/network_simulator.dart';
import '../network/api_client.dart';

class NetworkStatusBanner extends StatefulWidget {
  const NetworkStatusBanner({super.key});

  @override
  State<NetworkStatusBanner> createState() => _NetworkStatusBannerState();
}

class _NetworkStatusBannerState extends State<NetworkStatusBanner> {
  bool _backendAlive = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _checkBackend();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _checkBackend());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkBackend() async {
    if (!mounted) return;
    if (!NetworkSimulator().isOnline) {
      if (_backendAlive) setState(() => _backendAlive = false);
      return;
    }
    final alive = await ApiClient.isBackendReachable();
    if (mounted && alive != _backendAlive) {
      setState(() => _backendAlive = alive);
    }
  }

  @override
  Widget build(BuildContext context) {
    final simulator = NetworkSimulator();

    return AnimatedBuilder(
      animation: simulator,
      builder: (context, _) {
        final isOnline = simulator.isOnline;

        Color bannerColor;
        Color borderColor;
        Color accentColor;
        String title;
        String subtitle;

        if (!isOnline) {
          bannerColor = const Color(0xFF381F1F);
          borderColor = const Color(0xFFFF5252);
          accentColor = const Color(0xFFFF5252);
          title = "NETWORK: ZERO CONNECTIVITY (Offline BLE Mode)";
          subtitle = "Operating fully offline via local Keystore cryptography";
        } else if (_backendAlive) {
          bannerColor = const Color(0xFF1B382B);
          borderColor = const Color(0xFF00E676);
          accentColor = const Color(0xFF00E676);
          title = "NETWORK: ONLINE • BACKEND CONNECTED (${ApiClient.baseUrl})";
          subtitle = "Cloud sync & online 2FA top-up active";
        } else {
          bannerColor = const Color(0xFF382A1B);
          borderColor = const Color(0xFFFFB300);
          accentColor = const Color(0xFFFFB300);
          title = "NETWORK: ONLINE • WAITING FOR BACKEND";
          subtitle = "Backend not reachable at ${ApiClient.baseUrl}. Run uvicorn server.";
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: bannerColor,
            border: Border(
              bottom: BorderSide(
                color: borderColor,
                width: 1.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                !isOnline
                    ? Icons.wifi_off_rounded
                    : _backendAlive
                        ? Icons.cloud_done_rounded
                        : Icons.cloud_off_rounded,
                size: 18,
                color: accentColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: accentColor,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () {
                  simulator.toggle();
                  _checkBackend();
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      duration: const Duration(seconds: 2),
                      backgroundColor: simulator.isOnline ? const Color(0xFF00C853) : const Color(0xFFD50000),
                      content: Text(
                        simulator.isOnline
                            ? "Switched to ONLINE mode. Cloud APIs enabled."
                            : "Simulating OFFLINE environment. Cloud APIs blocked.",
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: accentColor,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isOnline ? "Go Offline" : "Go Online",
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.swap_horiz_rounded,
                        size: 14,
                        color: accentColor,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
