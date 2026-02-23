import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'otp_verify_screen.dart';

// ─── Country model ───────────────────────────────────────────────────────────
class _Country {
  final String flag;
  final String name;
  final String code; // e.g. +62

  const _Country(this.flag, this.name, this.code);
}

// ─── Country list ────────────────────────────────────────────────────────────
const List<_Country> _countries = [
  _Country('🇮🇩', 'Indonesia', '+62'),
  _Country('🇲🇾', 'Malaysia', '+60'),
  _Country('🇸🇬', 'Singapura', '+65'),
  _Country('🇵🇭', 'Filipina', '+63'),
  _Country('🇹🇭', 'Thailand', '+66'),
  _Country('🇻🇳', 'Vietnam', '+84'),
  _Country('🇮🇳', 'India', '+91'),
  _Country('🇨🇳', 'Tiongkok', '+86'),
  _Country('🇯🇵', 'Jepang', '+81'),
  _Country('🇰🇷', 'Korea Selatan', '+82'),
  _Country('🇦🇺', 'Australia', '+61'),
  _Country('🇬🇧', 'Inggris', '+44'),
  _Country('🇺🇸', 'Amerika Serikat', '+1'),
  _Country('🇩🇪', 'Jerman', '+49'),
  _Country('🇫🇷', 'Perancis', '+33'),
  _Country('🇸🇦', 'Arab Saudi', '+966'),
  _Country('🇦🇪', 'Uni Emirat Arab', '+971'),
  _Country('🇧🇩', 'Bangladesh', '+880'),
  _Country('🇵🇰', 'Pakistan', '+92'),
  _Country('🇧🇷', 'Brasil', '+55'),
];

// ─── PhoneEntryScreen ────────────────────────────────────────────────────────
class PhoneEntryScreen extends StatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  State<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends State<PhoneEntryScreen>
    with SingleTickerProviderStateMixin {
  _Country _selected = _countries.first; // Indonesia default
  final _phoneCtrl = TextEditingController();
  bool _loading = false;
  late AnimationController _animCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _slideAnim = Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutQuart));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    String local = _phoneCtrl.text.trim();
    if (local.isEmpty) {
      _showError('Masukkan nomor telepon');
      return;
    }
    // Strip leading zeros
    if (local.startsWith('0')) local = local.substring(1);
    final fullPhone = '${_selected.code}$local'; // e.g. +628123456789

    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: fullPhone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-retrieval on some Android devices
          debugPrint('Auto-verification completed');
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            setState(() => _loading = false);
            _showError(e.message ?? 'Verifikasi gagal');
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() => _loading = false);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtpVerifyScreen(
                phone: fullPhone,
                displayPhone: '${_selected.flag} ${_selected.code} $local',
                verificationId: verificationId,
                resendToken: resendToken,
              ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('Auto-retrieval timeout: $verificationId');
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showError('Error: $e');
      }
    }
  }

  Future<void> _pickCountry() async {
    final result = await showModalBottomSheet<_Country>(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (_) => const _CountryPickerSheet(countries: _countries),
    );
    if (result != null) setState(() => _selected = result);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white70, size: 20),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 32),
                  // Logo
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF25D366).withValues(alpha: 0.4),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.phone_android_rounded,
                          color: Colors.white, size: 36),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Center(
                    child: Text(
                      'Masukkan Nomor HP',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Kode OTP akan dikirim via SMS ke nomor Anda',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Phone input row
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1F2E),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        // Country picker button
                        GestureDetector(
                          onTap: _pickCountry,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 16),
                            decoration: const BoxDecoration(
                              border: Border(
                                  right: BorderSide(color: Colors.white12)),
                            ),
                            child: Row(
                              children: [
                                Text(_selected.flag,
                                    style: const TextStyle(fontSize: 20)),
                                const SizedBox(width: 6),
                                Text(
                                  _selected.code,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_drop_down,
                                    color: Colors.white54, size: 18),
                              ],
                            ),
                          ),
                        ),
                        // Phone number field
                        Expanded(
                          child: TextField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: '8123456789',
                              hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.3)),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Send OTP button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _sendOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        disabledBackgroundColor:
                            const Color(0xFF25D366).withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text(
                              'Kirim Kode OTP',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Country Picker Bottom Sheet ─────────────────────────────────────────────
class _CountryPickerSheet extends StatefulWidget {
  final List<_Country> countries;
  const _CountryPickerSheet({required this.countries});

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.countries
        .where((c) =>
            c.name.toLowerCase().contains(_query.toLowerCase()) ||
            c.code.contains(_query))
        .toList();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Pilih Negara',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Cari negara...',
                hintStyle:
                    TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF1A1F2E),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final c = filtered[i];
                return ListTile(
                  leading: Text(c.flag, style: const TextStyle(fontSize: 24)),
                  title:
                      Text(c.name, style: const TextStyle(color: Colors.white)),
                  trailing: Text(c.code,
                      style: const TextStyle(
                          color: Color(0xFF25D366),
                          fontWeight: FontWeight.bold)),
                  onTap: () => Navigator.pop(context, c),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
