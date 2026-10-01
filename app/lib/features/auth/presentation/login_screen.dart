// ignore_for_file: public_member_api_docs
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/auth_service.dart';

// ---------------------------------------------------------------------------
// Login screen — supports Sign In, Sign Up, and OTP verification step.
// ---------------------------------------------------------------------------

enum _AuthMode { signIn, signUp }

enum _Step { form, otp }

class LoginScreen extends StatefulWidget {
  final AuthService authService;
  final VoidCallback onLoginSuccess;

  const LoginScreen({
    super.key,
    required this.authService,
    required this.onLoginSuccess,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  // ── tab / step ────────────────────────────────────────────────────────────
  _AuthMode _mode = _AuthMode.signIn;
  _Step _step = _Step.form;

  // ── controllers ───────────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  // ── state ─────────────────────────────────────────────────────────────────
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _pendingEmail; // email awaiting OTP confirmation
  Timer? _cooldownTimer;
  int _resendSeconds = 0;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _otpCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  bool _isValidEmail(String v) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v);

  Future<void> _run(Future<void> Function() action) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage =
          e is AuthFailure ? e.message : 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        t.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds -= 1);
      }
    });
  }

  void _backToForm() {
    _cooldownTimer?.cancel();
    setState(() {
      _step = _Step.form;
      _pendingEmail = null;
      _otpCtrl.clear();
      _resendSeconds = 0;
      _errorMessage = null;
    });
  }

  // ── action handlers ───────────────────────────────────────────────────────

  Future<void> _handleGoogle() async {
    await _run(() => widget.authService.signInWithGoogle());
  }

  Future<void> _handleSignIn() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (!_isValidEmail(email)) {
      setState(() => _errorMessage = 'Enter a valid email address.');
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Enter your password.');
      return;
    }
    await _run(() async {
      await widget.authService.signInWithPassword(
        email: email,
        password: password,
      );
      if (mounted) widget.onLoginSuccess();
    });
  }

  Future<void> _handleSignUp() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Enter your full name.');
      return;
    }
    if (!_isValidEmail(email)) {
      setState(() => _errorMessage = 'Enter a valid email address.');
      return;
    }
    if (password.length < 8) {
      setState(
          () => _errorMessage = 'Password must be at least 8 characters.');
      return;
    }
    await _run(() async {
      await widget.authService.signUpWithPassword(
        email: email,
        password: password,
        displayName: name,
      );
      if (!mounted) return;
      setState(() {
        _pendingEmail = email;
        _step = _Step.otp;
      });
      _startCooldown();
    });
  }

  Future<void> _handleVerifyOtp() async {
    final email = _pendingEmail ?? _emailCtrl.text.trim();
    final token = _otpCtrl.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(token)) {
      setState(() => _errorMessage = 'Enter the 6-digit verification code.');
      return;
    }
    await _run(() async {
      await widget.authService.verifySignUpOtp(email: email, token: token);
      if (mounted) widget.onLoginSuccess();
    });
  }

  Future<void> _handleResend() async {
    if (_resendSeconds > 0 || _isLoading) return;
    final email = _pendingEmail ?? _emailCtrl.text.trim();
    await _run(() async {
      await widget.authService.signUpWithPassword(
        email: email,
        password: _passwordCtrl.text,
        displayName: _nameCtrl.text.trim(),
      );
      _startCooldown();
    });
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildBrand(),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: _step == _Step.otp
                      ? _buildOtpStep()
                      : _buildFormStep(),
                ),
                const SizedBox(height: 24),
                if (widget.authService.isDevBypassEnabled) _buildDevBypass(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── brand ─────────────────────────────────────────────────────────────────

  Widget _buildBrand() => Column(
        children: [
          Image.asset(
            'assets/branding/kratos_logo.png',
            width: 76,
            height: 76,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 20),
          const Text(
            'KRATOS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'LEVEL UP YOUR LIFE',
            style: TextStyle(
              color: Color(0xFFC6F135),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.5,
            ),
          ),
        ],
      );

  // ── tab switcher ──────────────────────────────────────────────────────────

  Widget _buildTabSwitcher() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _buildTab('Sign In', _AuthMode.signIn),
          _buildTab('Create Account', _AuthMode.signUp),
        ],
      ),
    );
  }

  Widget _buildTab(String label, _AuthMode mode) {
    final active = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_mode == mode || _isLoading) return;
          setState(() {
            _mode = mode;
            _errorMessage = null;
            _nameCtrl.clear();
            _emailCtrl.clear();
            _passwordCtrl.clear();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFFC6F135).withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: active
                ? Border.all(
                    color: const Color(0xFFC6F135).withValues(alpha: 0.4))
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? const Color(0xFFC6F135) : Colors.white38,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  // ── form step ─────────────────────────────────────────────────────────────

  Widget _buildFormStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTabSwitcher(),
          const SizedBox(height: 24),

          // Google button
          _primaryButton(
            label: 'Continue with Google',
            icon: Icons.g_mobiledata,
            onTap: _handleGoogle,
          ),
          const SizedBox(height: 20),

          // Divider
          const Row(children: [
            Expanded(child: Divider(color: Colors.white12)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('OR',
                  style: TextStyle(color: Colors.white24, fontSize: 11)),
            ),
            Expanded(child: Divider(color: Colors.white12)),
          ]),
          const SizedBox(height: 20),

          // Name field (Sign Up only)
          if (_mode == _AuthMode.signUp) ...[
            _fieldLabel('Full Name'),
            const SizedBox(height: 8),
            _textField(
              controller: _nameCtrl,
              hint: 'Your name',
              icon: Icons.person_outline,
              onSubmitted: (_) => _emailFocus.requestFocus(),
            ),
            const SizedBox(height: 16),
          ],

          // Email
          _fieldLabel('Email'),
          const SizedBox(height: 8),
          _textField(
            controller: _emailCtrl,
            hint: 'you@example.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            focusNode: _emailFocus,
            onSubmitted: (_) => _passwordFocus.requestFocus(),
          ),
          const SizedBox(height: 16),

          // Password
          _fieldLabel('Password'),
          const SizedBox(height: 8),
          _passwordField(),
          if (_mode == _AuthMode.signUp)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'At least 8 characters',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3), fontSize: 11),
              ),
            ),
          const SizedBox(height: 24),

          // CTA button
          _accentButton(
            _mode == _AuthMode.signIn ? 'Sign In' : 'Create Account & Send Code',
            _mode == _AuthMode.signIn ? _handleSignIn : _handleSignUp,
          ),

          _errorWidget(),
        ],
      );

  // ── otp step ──────────────────────────────────────────────────────────────

  Widget _buildOtpStep() => Column(
        children: [
          const Icon(Icons.mark_email_read_outlined,
              color: Color(0xFFC6F135), size: 40),
          const SizedBox(height: 16),
          const Text(
            'Check your email',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We sent a 6-digit code to\n${_pendingEmail ?? _emailCtrl.text}',
            textAlign: TextAlign.center,
            style:
                const TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 28),

          // 6-digit OTP input
          TextField(
            controller: _otpCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            enabled: !_isLoading,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              letterSpacing: 14,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '000000',
              hintStyle: const TextStyle(
                  color: Colors.white12, letterSpacing: 14, fontSize: 30),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (_) => _handleVerifyOtp(),
          ),
          const SizedBox(height: 20),

          _accentButton('Verify & Enter', _handleVerifyOtp),
          const SizedBox(height: 12),

          // Resend
          TextButton(
            onPressed:
                _resendSeconds == 0 && !_isLoading ? _handleResend : null,
            child: Text(
              _resendSeconds == 0
                  ? 'Resend code'
                  : 'Resend in ${_resendSeconds}s',
              style: TextStyle(
                color: _resendSeconds == 0
                    ? const Color(0xFFC6F135)
                    : Colors.white38,
              ),
            ),
          ),

          TextButton(
            onPressed: _isLoading ? null : _backToForm,
            child: const Text('← Back',
                style: TextStyle(color: Colors.white54)),
          ),

          _errorWidget(),
        ],
      );

  // ── shared widgets ────────────────────────────────────────────────────────

  Widget _fieldLabel(String text) => Text(
        text,
        style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
      );

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    FocusNode? focusNode,
    void Function(String)? onSubmitted,
  }) =>
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        autocorrect: false,
        enabled: !_isLoading,
        focusNode: focusNode,
        onSubmitted: onSubmitted,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.white38),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      );

  Widget _passwordField() => TextField(
        controller: _passwordCtrl,
        obscureText: _obscurePassword,
        enabled: !_isLoading,
        focusNode: _passwordFocus,
        onSubmitted: (_) =>
            _mode == _AuthMode.signIn ? _handleSignIn() : _handleSignUp(),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: _mode == _AuthMode.signIn ? 'Password' : 'Create password',
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
          prefixIcon:
              const Icon(Icons.lock_outline, color: Colors.white38),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.white38,
              size: 20,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      );

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: _isLoading ? null : onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.black, size: 28),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  )),
            ],
          ),
        ),
      );

  Widget _accentButton(String label, VoidCallback onTap) => GestureDetector(
        onTap: _isLoading ? null : onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFC6F135).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: const Color(0xFFC6F135).withValues(alpha: 0.4)),
          ),
          alignment: Alignment.center,
          child: _isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFC6F135),
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFC6F135),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
        ),
      );

  Widget _errorWidget() => _errorMessage == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 12),
            textAlign: TextAlign.center,
          ),
        );

  Widget _buildDevBypass() => GestureDetector(
        onTap: _isLoading
            ? null
            : () => _run(widget.authService.signInWithDevBypass),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: const Text(
            'CONTINUE AS DEV (SEED USER)',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
      );
}
