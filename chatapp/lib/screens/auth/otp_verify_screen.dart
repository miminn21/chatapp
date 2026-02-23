import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'profile_setup_screen.dart';

class OtpVerifyScreen extends StatefulWidget {
  final String phone;
  final String displayPhone;
  final String verificationId;
  final int? resendToken;

  const OtpVerifyScreen({
    super.key,
    required this.phone,
    required this.displayPhone,
    required this.verificationId,
    this.resendToken,
  });

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen>
    with SingleTickerProviderStateMixin {
  final _ctrls = List.generate(6, (_) => TextEditingController());
  final _nodes = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  int _countdown = 60;
  Timer? _timer;
  String _currentVerificationId = '';
  int? _currentResendToken;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _currentVerificationId = widget.verificationId;
    _currentResendToken = widget.resendToken;
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
    _startTimer();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _nodes[0].requestFocus());
  }

  void _startTimer() {
    _countdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown == 0) {
        t.cancel();
      } else {
        if (mounted) setState(() => _countdown--);
      }
    });
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    _timer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  String get _code => _ctrls.map((c) => c.text).join();

  void _onDigitChanged(int index, String val) {
    if (val.isEmpty) {
      if (index > 0) _nodes[index - 1].requestFocus();
    } else {
      if (index < 5) {
        _nodes[index + 1].requestFocus();
      } else {
        _nodes[index].unfocus();
        if (_code.length == 6) _verify();
      }
    }
    setState(() {});
  }

  Future<void> _verify() async {
    if (_code.length < 6) {
      _showError('Masukkan 6 digit kode OTP');
      return;
    }
    setState(() => _loading = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _currentVerificationId,
        smsCode: _code,
      );
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final idToken = await userCredential.user?.getIdToken();

      if (!mounted) return;
      if (idToken != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileSetupScreen(
              phone: widget.phone,
              idToken: idToken,
            ),
          ),
        );
      } else {
        _showError('Gagal mendapatkan token Firebase');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        _showError(e.message ?? 'Kode OTP salah atau sudah kadaluarsa');
        _clearCode();
      }
    } catch (e) {
      if (mounted) _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    _clearCode();
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: widget.phone,
        forceResendingToken: _currentResendToken,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (_) {},
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) _showError(e.message ?? 'Gagal kirim ulang');
        },
        codeSent: (String verificationId, int? resendToken) {
          _currentVerificationId = verificationId;
          _currentResendToken = resendToken;
          _startTimer();
          if (mounted) {
            setState(() => _loading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ OTP baru telah dikirim via SMS'),
                backgroundColor: Color(0xFF25D366),
              ),
            );
          }
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showError('Gagal mengirim ulang: $e');
      }
    }
  }

  void _clearCode() {
    for (final c in _ctrls) {
      c.clear();
    }
    _nodes[0].requestFocus();
    setState(() {});
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white70, size: 20),
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF25D366).withValues(alpha: 0.4),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.message_rounded,
                      color: Colors.white, size: 36),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Verifikasi Nomor',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 14,
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(
                          text:
                              'Masukkan kode 6 digit yang dikirim via SMS ke\n'),
                      TextSpan(
                        text: widget.displayPhone,
                        style: const TextStyle(
                            color: Color(0xFF25D366),
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // OTP boxes
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (i) => _buildBox(i)),
                ),

                const SizedBox(height: 32),

                // Verify button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: (_loading || _code.length < 6) ? null : _verify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      disabledBackgroundColor:
                          const Color(0xFF25D366).withValues(alpha: 0.25),
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
                            'Verifikasi',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                // Resend
                _countdown > 0
                    ? Text(
                        'Kirim ulang dalam $_countdown detik',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 13,
                        ),
                      )
                    : GestureDetector(
                        onTap: _loading ? null : _resend,
                        child: Text(
                          'Kirim Ulang OTP',
                          style: TextStyle(
                            color: _loading
                                ? Colors.white24
                                : const Color(0xFF25D366),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBox(int i) {
    final filled = _ctrls[i].text.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 46,
      height: 56,
      decoration: BoxDecoration(
        color: filled
            ? const Color(0xFF25D366).withValues(alpha: 0.15)
            : const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: filled
              ? const Color(0xFF25D366)
              : _nodes[i].hasFocus
                  ? const Color(0xFF25D366).withValues(alpha: 0.6)
                  : Colors.white12,
          width: filled ? 2 : 1,
        ),
      ),
      child: TextField(
        controller: _ctrls[i],
        focusNode: _nodes[i],
        textAlign: TextAlign.center,
        maxLength: 1,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          counterText: '',
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (v) => _onDigitChanged(i, v),
      ),
    );
  }
}
