import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/landing_screen.dart';
import 'security/keystore_manager.dart';

/// Migration version: bump this string to force re-generation of the keypair.
/// This is necessary because the old fallback stored fake (non-ECDSA) keys.
const String _kCryptoVersion = 'v2_real_ecdsa';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _migrateCryptoKeysIfNeeded();
  runApp(const TransactApp());
}

/// Wipes stale fake keys and pre-generates a real secp256r1 keypair so the
/// first registration to the server uses a cryptographically valid public key.
Future<void> _migrateCryptoKeysIfNeeded() async {
  final prefs = await SharedPreferences.getInstance();
  final version = prefs.getString('crypto_version');
  if (version != _kCryptoVersion) {
    await prefs.remove('secp256r1_pubkey_hex');
    await prefs.remove('secp256r1_privkey_hex');
    // Also clear old naming used before the rewrite
    await prefs.remove('secp256r1_simulated_pubkey');
    await prefs.remove('secp256r1_simulated_privkey');
    await KeystoreManager.generateKeyPair(); // generates real keys
    await prefs.setString('crypto_version', _kCryptoVersion);
  }
}

class TransactApp extends StatelessWidget {
  const TransactApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Transact Offline UPI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F111A),
        primaryColor: const Color(0xFF6C5CE7),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6C5CE7),
          secondary: Color(0xFF00CEC9),
          surface: Color(0xFF161A29),
          background: Color(0xFF0F111A),
          error: Color(0xFFFF5252),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF161A29),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF161A29),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        fontFamily: 'Roboto',
      ),
      home: const LandingScreen(),
    );
  }
}
